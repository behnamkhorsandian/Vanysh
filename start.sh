#!/bin/bash
#===============================================================================
# DNSCloak - Unified VPN Protocol Setup
# https://github.com/behnamkhorsandian/DNSCloak
#
# Usage:
#   curl -sSL start.dnscloak.net | sudo bash
#   curl -sSL start.dnscloak.net | sudo bash -s -- --protocol=reality
#   curl -sSL reality.dnscloak.net | sudo bash
#
# All-in-one: install, manage, and remove VPN protocols on your VM.
#===============================================================================

# Note: Not using 'set -e' to allow interactive reads to work when piped

#-------------------------------------------------------------------------------
# Argument Parsing
#-------------------------------------------------------------------------------

REQUESTED_PROTOCOL="${DNSCLOAK_PROTOCOL:-}"

for arg in "$@"; do
    case "$arg" in
        --protocol=*)
            REQUESTED_PROTOCOL="${arg#*=}"
            ;;
        --update)
            DO_UPDATE=1
            ;;
    esac
done

#-------------------------------------------------------------------------------
# Download Libraries
#-------------------------------------------------------------------------------

LIB_DIR="/tmp/dnscloak-lib"
GITHUB_RAW="https://raw.githubusercontent.com/behnamkhorsandian/DNSCloak/main"

download_libs() {
    mkdir -p "$LIB_DIR"
    
    local libs="common.sh cloud.sh bootstrap.sh xray.sh selector.sh"
    for lib in $libs; do
        if ! curl -sfL "$GITHUB_RAW/lib/$lib" -o "$LIB_DIR/$lib" 2>/dev/null; then
            echo "ERROR: Failed to download $lib"
            exit 1
        fi
    done
    
    # Source libraries
    for lib in $libs; do
        # shellcheck source=/dev/null
        . "$LIB_DIR/$lib"
    done
}

# Download a service function library
download_service_functions() {
    local service="$1"
    local dest="$LIB_DIR/svc-${service}.sh"
    
    if [[ ! -f "$dest" ]]; then
        if ! curl -sfL "$GITHUB_RAW/services/${service}/functions.sh" -o "$dest" 2>/dev/null; then
            echo "ERROR: Failed to download ${service} functions"
            return 1
        fi
    fi
    
    # shellcheck source=/dev/null
    . "$dest"
}

#-------------------------------------------------------------------------------
# Protocol Definitions
#-------------------------------------------------------------------------------

PROTOCOLS=(reality ws wg vray dnstt mtp conduit)
declare -A PROTO_NAMES=(
    [reality]="VLESS + REALITY"
    [ws]="VLESS + WS + CDN"
    [wg]="WireGuard"
    [vray]="VLESS + TLS"
    [dnstt]="DNS Tunnel"
    [mtp]="MTProto"
    [conduit]="Conduit (Psiphon)"
)

#-------------------------------------------------------------------------------
# Build Menu Items
#-------------------------------------------------------------------------------

build_menu_items() {
    MENU_ITEMS=()
    for proto in "${PROTOCOLS[@]}"; do
        local name="${PROTO_NAMES[$proto]}"
        local status
        status=$(protocol_status "$proto")
        MENU_ITEMS+=("${name}|${proto}|${status}")
    done
}

#-------------------------------------------------------------------------------
# Protocol Actions
#-------------------------------------------------------------------------------

# Run install flow for a protocol
run_install() {
    local proto="$1"
    
    download_service_functions "$proto" || {
        print_error "Failed to load $proto installer"
        return 1
    }
    
    case "$proto" in
        reality)  install_reality ;;
        ws)       install_ws ;;
        wg)       install_wg ;;
        vray)     install_vray ;;
        dnstt)    install_dnstt ;;
        mtp)      install_mtp ;;
        conduit)  install_conduit ;;
        *)        print_error "Unknown protocol: $proto"; return 1 ;;
    esac
}

# Show management menu for an installed protocol
run_manage() {
    local proto="$1"
    
    download_service_functions "$proto" || {
        print_error "Failed to load $proto manager"
        return 1
    }
    
    case "$proto" in
        reality)  manage_reality ;;
        ws)       manage_ws ;;
        wg)       manage_wg ;;
        vray)     manage_vray ;;
        dnstt)    manage_dnstt ;;
        mtp)      manage_mtp ;;
        conduit)  manage_conduit ;;
        *)        print_error "Unknown protocol: $proto"; return 1 ;;
    esac
}

# Handle protocol selection
handle_protocol() {
    local proto="$1"
    
    if service_installed "$proto"; then
        run_manage "$proto"
    else
        run_install "$proto"
    fi
}

#-------------------------------------------------------------------------------
# Status View
#-------------------------------------------------------------------------------

show_all_status() {
    clear
    echo -e "${CYAN}"
    load_banner "logo" 2>/dev/null || echo "  DNSCloak v${DNSCLOAK_VERSION}"
    echo -e "${RESET}"
    echo ""
    echo -e "  ${BOLD}${WHITE}Service Status${RESET}"
    print_line
    echo ""
    
    for proto in "${PROTOCOLS[@]}"; do
        local name="${PROTO_NAMES[$proto]}"
        if service_installed "$proto"; then
            if service_running "$proto"; then
                echo -e "  ${GREEN}[+]${RESET} ${name}: ${GREEN}running${RESET}"
            else
                echo -e "  ${YELLOW}[-]${RESET} ${name}: ${YELLOW}stopped${RESET}"
            fi
        else
            echo -e "  ${GRAY}[ ]${RESET} ${name}: ${GRAY}not installed${RESET}"
        fi
    done
    
    echo ""
    print_line
    
    # Show server info if available
    if [[ -f "$DNSCLOAK_USERS" ]]; then
        local ip
        ip=$(server_get "ip" 2>/dev/null)
        if [[ -n "$ip" && "$ip" != "null" ]]; then
            echo -e "  ${GRAY}Server: $ip${RESET}"
        fi
    fi
    
    echo ""
    press_enter
}

#-------------------------------------------------------------------------------
# Update
#-------------------------------------------------------------------------------

do_update() {
    print_step "Updating DNSCloak..."
    
    # Re-download libs to /opt/dnscloak/lib/
    local permanent_lib="$DNSCLOAK_DIR/lib"
    mkdir -p "$permanent_lib"
    
    for lib in common.sh cloud.sh bootstrap.sh xray.sh selector.sh; do
        print_info "Updating $lib"
        curl -sfL "$GITHUB_RAW/lib/$lib" -o "$permanent_lib/$lib" 2>/dev/null || \
            print_warning "Failed to update $lib"
    done
    
    # Update CLI
    print_info "Updating CLI"
    curl -sfL "$GITHUB_RAW/cli/dnscloak.sh" -o /usr/local/bin/dnscloak 2>/dev/null && \
        chmod +x /usr/local/bin/dnscloak || print_warning "Failed to update CLI"
    
    # Update banners
    mkdir -p "$DNSCLOAK_DIR/banners"
    for banner in logo menu setup reality ws wireguard dnstt mtp conduit; do
        curl -sfL "$GITHUB_RAW/banners/${banner}.txt" -o "$DNSCLOAK_DIR/banners/${banner}.txt" 2>/dev/null || true
    done
    
    print_success "DNSCloak updated to latest version"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Menu (Interactive TUI)
#-------------------------------------------------------------------------------

main_menu() {
    while true; do
        build_menu_items
        
        local choice
        tui_menu "DNSCloak Protocol Setup" choice "${MENU_ITEMS[@]}"
        
        if [[ "$choice" == "-1" ]]; then
            # Quit
            clear
            echo ""
            echo -e "  ${CYAN}Manage your services anytime:${RESET}"
            echo -e "  ${WHITE}  dnscloak${RESET}            - Interactive menu"
            echo -e "  ${WHITE}  dnscloak status${RESET}     - Service status"
            echo -e "  ${WHITE}  dnscloak add${RESET} ...    - Add users"
            echo ""
            exit 0
        fi
        
        if [[ "$choice" -ge 0 && "$choice" -lt ${#PROTOCOLS[@]} ]]; then
            local selected_proto="${PROTOCOLS[$choice]}"
            handle_protocol "$selected_proto"
        fi
    done
}

#-------------------------------------------------------------------------------
# Fallback Menu (No TUI support)
#-------------------------------------------------------------------------------

fallback_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        load_banner "logo" 2>/dev/null || echo "  DNSCloak v${DNSCLOAK_VERSION}"
        echo -e "${RESET}"
        echo ""
        echo -e "  ${BOLD}${WHITE}DNSCloak Protocol Setup${RESET}"
        print_line
        echo ""
        
        local i=1
        for proto in "${PROTOCOLS[@]}"; do
            local name="${PROTO_NAMES[$proto]}"
            local badge=""
            
            if service_installed "$proto"; then
                if service_running "$proto"; then
                    badge=" ${GREEN}[running]${RESET}"
                else
                    badge=" ${YELLOW}[stopped]${RESET}"
                fi
            else
                case "$proto" in
                    reality)  badge=" ${CYAN}(recommended)${RESET}" ;;
                    ws|vray)  badge=" ${YELLOW}(needs domain)${RESET}" ;;
                    dnstt)    badge=" ${RED}(emergency)${RESET}" ;;
                    conduit)  badge=" ${MAGENTA}(relay)${RESET}" ;;
                esac
            fi
            
            echo -e "  ${WHITE}$i)${RESET} ${name}${badge}"
            ((i++))
        done
        
        echo ""
        echo -e "  ${WHITE}s)${RESET} Status"
        echo -e "  ${WHITE}u)${RESET} Update DNSCloak"
        echo -e "  ${WHITE}q)${RESET} Quit"
        echo ""
        
        get_input "Select [1-${#PROTOCOLS[@]}, s, u, q]" "1" menu_choice
        
        case "$menu_choice" in
            [1-7])
                local idx=$((menu_choice - 1))
                if [[ $idx -lt ${#PROTOCOLS[@]} ]]; then
                    handle_protocol "${PROTOCOLS[$idx]}"
                fi
                ;;
            s|S)
                show_all_status
                ;;
            u|U)
                do_update
                press_enter
                ;;
            q|Q|0)
                clear
                echo ""
                echo -e "  ${CYAN}Run 'dnscloak' anytime to manage services${RESET}"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    # Check root
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root or with sudo"
        echo "Usage: curl -sSL start.dnscloak.net | sudo bash"
        exit 1
    fi
    
    # Download libraries
    download_libs
    
    # Check OS
    check_os
    
    # Handle --update flag
    if [[ "${DO_UPDATE:-0}" -eq 1 ]]; then
        do_update
        exit 0
    fi
    
    # If a specific protocol was requested (via --protocol= or DNSCLOAK_PROTOCOL env)
    if [[ -n "$REQUESTED_PROTOCOL" ]]; then
        # Validate protocol
        local valid=0
        for proto in "${PROTOCOLS[@]}"; do
            if [[ "$proto" == "$REQUESTED_PROTOCOL" ]]; then
                valid=1
                break
            fi
        done
        
        if [[ $valid -eq 0 ]]; then
            print_error "Unknown protocol: $REQUESTED_PROTOCOL"
            echo ""
            echo "  Available protocols: ${PROTOCOLS[*]}"
            exit 1
        fi
        
        handle_protocol "$REQUESTED_PROTOCOL"
        exit 0
    fi
    
    # Interactive menu
    # Try TUI first, fall back to number-based
    if [[ -t 0 ]] || [[ -e /dev/tty ]]; then
        main_menu
    else
        fallback_menu
    fi
}

main "$@"
