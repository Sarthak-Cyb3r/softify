#!/usr/bin/env bash
# ==============================================================================
#  SOFTIFY — Linux Terminal Installer
#  Ad-Free, Studio-Fidelity Music Streaming Player
#  https://github.com/Sarthak-Cyb3r/softify
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# UI / Color Theme (Matching Softify Linux Design System: Emerald #22C55E)
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    COLOR_RESET="\033[0m"
    COLOR_BOLD="\033[1m"
    COLOR_DIM="\033[2m"
    COLOR_EMERALD="\033[38;2;34;197;94m"   # #22C55E
    COLOR_CYAN="\033[38;2;56;189;248m"     # #38BDF8
    COLOR_PURPLE="\033[38;2;129;140;248m"  # #818CF8
    COLOR_MUTED="\033[38;2;148;163;184m"   # #94A3B8
    COLOR_YELLOW="\033[38;2;250;204;21m"   # #FACC15
    COLOR_RED="\033[38;2;248;113;113m"     # #F87171
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_DIM=""
    COLOR_EMERALD=""
    COLOR_CYAN=""
    COLOR_PURPLE=""
    COLOR_MUTED=""
    COLOR_YELLOW=""
    COLOR_RED=""
fi

log_info() {
    printf "${COLOR_CYAN}[➜]${COLOR_RESET} %b\n" "$*"
}

log_success() {
    printf "${COLOR_EMERALD}[✓]${COLOR_RESET} ${COLOR_BOLD}%b${COLOR_RESET}\n" "$*"
}

log_warn() {
    printf "${COLOR_YELLOW}[!]${COLOR_RESET} %b\n" "$*"
}

log_error() {
    printf "${COLOR_RED}[✗]${COLOR_RESET} ${COLOR_BOLD}%b${COLOR_RESET}\n" "$*"
}

print_banner() {
    cat << "EOF"

  ███████╗ ██████╗ ███████╗████████╗██╗███████╗██╗   ██╗
  ██╔════╝██╔═══██╗██╔════╝╚══██╔══╝██║██╔════╝╚██╗ ██╔╝
  ███████╗██║   ██║█████╗     ██║   ██║█████╗   ╚████╔╝ 
  ╚════██║██║   ██║██╔══╝     ██║   ██║██╔══╝    ╚██╔╝  
  ███████║╚██████╔╝██║        ██║   ██║██║        ██║   
  ╚══════╝ ╚═════╝ ╚═╝        ╚═╝   ╚═╝╚═╝        ╚═╝   
EOF
    printf "  ${COLOR_EMERALD}${COLOR_BOLD}Linux Desktop Terminal Installer${COLOR_RESET} ${COLOR_MUTED}• v2.0.0${COLOR_RESET}\n"
    printf "  ${COLOR_DIM}Ad-Free • Studio Master Audio • Fast Local-First UI${COLOR_RESET}\n\n"
}

# ------------------------------------------------------------------------------
# Configuration Defaults
# ------------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
INSTALL_PREFIX="${HOME}/.local"
APP_DIR="${INSTALL_PREFIX}/share/softify"
BIN_DIR="${INSTALL_PREFIX}/bin"
DESKTOP_DIR="${INSTALL_PREFIX}/share/applications"
ICON_DIR_SVG="${INSTALL_PREFIX}/share/icons/hicolor/scalable/apps"
ICON_DIR_PNG="${INSTALL_PREFIX}/share/icons/hicolor/512x512/apps"

MODE="install"
AUTO_CONFIRM=false
BUILD_FROM_SOURCE=false
SYSTEM_WIDE=false

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
show_help() {
    print_banner
    printf "Usage: %s [OPTIONS]\n\n" "$0"
    printf "Options:\n"
    printf "  -y, --yes               Auto-confirm all prompts (non-interactive mode)\n"
    printf "  -b, --build             Build native Linux binary from local source code\n"
    printf "  -u, --uninstall         Uninstall Softify and clean up desktop integrations\n"
    printf "  -s, --system            Install system-wide into /usr/local (requires sudo)\n"
    printf "  -h, --help              Show this help menu and exit\n\n"
    printf "Examples:\n"
    printf "  %s                      # Standard user-level installation\n" "$0"
    printf "  %s --build              # Compile and install from source\n" "$0"
    printf "  %s --uninstall          # Cleanly remove Softify\n" "$0"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -b|--build|--build-from-source)
            BUILD_FROM_SOURCE=true
            shift
            ;;
        -u|--uninstall)
            MODE="uninstall"
            shift
            ;;
        -s|--system)
            SYSTEM_WIDE=true
            INSTALL_PREFIX="/usr/local"
            APP_DIR="/opt/softify"
            BIN_DIR="/usr/local/bin"
            DESKTOP_DIR="/usr/share/applications"
            ICON_DIR_SVG="/usr/share/icons/hicolor/scalable/apps"
            ICON_DIR_PNG="/usr/share/icons/hicolor/512x512/apps"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            printf "Use '%s --help' to see available options.\n" "$0"
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Uninstallation Handler
# ------------------------------------------------------------------------------
do_uninstall() {
    print_banner
    log_info "Initiating uninstallation of Softify..."

    if [[ "$AUTO_CONFIRM" != true ]]; then
        printf "\nAre you sure you want to uninstall Softify? [y/N]: "
        read -r answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            log_warn "Uninstallation cancelled by user."
            exit 0
        fi
    fi

    # Remove binary
    if [[ -f "${BIN_DIR}/softify" || -L "${BIN_DIR}/softify" ]]; then
        rm -f "${BIN_DIR}/softify"
        log_info "Removed executable symlink: ${BIN_DIR}/softify"
    fi

    # Remove desktop entry
    if [[ -f "${DESKTOP_DIR}/softify.desktop" ]]; then
        rm -f "${DESKTOP_DIR}/softify.desktop"
        log_info "Removed desktop entry: ${DESKTOP_DIR}/softify.desktop"
    fi

    # Remove icons
    rm -f "${ICON_DIR_SVG}/softify.svg" 2>/dev/null || true
    rm -f "${ICON_DIR_PNG}/softify.png" 2>/dev/null || true
    log_info "Removed application icons"

    # Remove app directory
    if [[ -d "${APP_DIR}" ]]; then
        rm -rf "${APP_DIR}"
        log_info "Removed application files: ${APP_DIR}"
    fi

    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$(dirname "$(dirname "$ICON_DIR_PNG")")" 2>/dev/null || true
    fi

    log_success "Softify has been successfully uninstalled from your Linux system."
    exit 0
}

if [[ "$MODE" == "uninstall" ]]; then
    do_uninstall
fi

# ------------------------------------------------------------------------------
# System & Resource Inspection (Low RAM Guardrail)
# ------------------------------------------------------------------------------
print_banner

# Detect RAM to safeguard against OOM crashes on systems with <= 4.8GB RAM
TOTAL_MEM_MB=0
AVAILABLE_MEM_MB=0
if [[ -f /proc/meminfo ]]; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    AVAIL_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_MB=$(( TOTAL_MEM_KB / 1024 ))
    AVAILABLE_MEM_MB=$(( AVAIL_MEM_KB / 1024 ))
fi

log_info "System Memory Check: ${COLOR_BOLD}${TOTAL_MEM_MB} MB${COLOR_RESET} total (${AVAILABLE_MEM_MB} MB available)"

MAX_CONCURRENT_JOBS=2
if (( TOTAL_MEM_MB <= 5120 )); then
    log_warn "Detected memory-constrained system (<= 5 GB RAM)."
    log_warn "Enforcing strict concurrency limit (max 1-2 build jobs) to prevent OS freezes."
    MAX_CONCURRENT_JOBS=1
fi

# Detect Linux Distribution
DISTRO_ID="linux"
DISTRO_NAME="Linux"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID:-linux}"
    DISTRO_NAME="${NAME:-Linux}"
fi
log_info "Target Platform: ${COLOR_BOLD}${DISTRO_NAME}${COLOR_RESET} (${DISTRO_ID})"

# ------------------------------------------------------------------------------
# Dependency Verification & Automatic Installation
# ------------------------------------------------------------------------------
check_and_install_deps() {
    local missing_tools=()

    # Runtime and build tools
    for cmd in pkg-config; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_tools+=("$cmd")
        fi
    done

    # If building from source, check clang, cmake, ninja
    if [[ "$BUILD_FROM_SOURCE" == true ]]; then
        for cmd in clang cmake ninja; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                missing_tools+=("$cmd")
            fi
        done
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warn "Missing required packages: ${missing_tools[*]}"
        
        local install_cmd=""
        case "$DISTRO_ID" in
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                install_cmd="sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libasound2-dev libpulse-dev"
                ;;
            arch|manjaro|endeavouros)
                install_cmd="sudo pacman -S --needed --noconfirm clang cmake ninja pkgconf gtk3 xz alsa-lib libpulse"
                ;;
            fedora|rhel|centos)
                install_cmd="sudo dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel alsa-lib-devel pulseaudio-libs-devel"
                ;;
            opensuse*|suse)
                install_cmd="sudo zypper in -y clang cmake ninja pkg-config gtk3-devel liblzma-devel alsa-devel libpulse-devel"
                ;;
            *)
                log_warn "Please install the missing tools manually using your package manager."
                return 0
                ;;
        esac

        if [[ "$AUTO_CONFIRM" == true ]]; then
            log_info "Automatically installing dependencies with: ${install_cmd}"
            eval "$install_cmd"
        else
            printf "\nInstall system dependencies now? [Y/n]: "
            read -r ans
            if [[ "$ans" =~ ^[Nn]$ ]]; then
                log_warn "Skipping dependency installation. Build might fail if dependencies are missing."
            else
                log_info "Running: ${install_cmd}"
                eval "$install_cmd"
            fi
        fi
    else
        log_success "System build and runtime dependencies verified."
    fi
}

check_and_install_deps

# ------------------------------------------------------------------------------
# Build or Bundle Staging
# ------------------------------------------------------------------------------
BUNDLE_DIR=""

if [[ "$BUILD_FROM_SOURCE" == true ]] || [[ -f "${REPO_DIR}/pubspec.yaml" && ! -d "${REPO_DIR}/build/linux/x64/release/bundle" ]]; then
    if ! command -v flutter >/dev/null 2>&1; then
        log_error "Flutter SDK was not found in PATH."
        log_info "Install Flutter (https://docs.flutter.dev/get-started/install/linux) or run from project root."
        exit 1
    fi

    log_info "Building Softify Linux native binary..."
    log_info "Memory-safe concurrency: MAKEFLAGS=\"-j${MAX_CONCURRENT_JOBS}\""
    
    cd "${REPO_DIR}"
    export MAKEFLAGS="-j${MAX_CONCURRENT_JOBS}"
    export CMAKE_BUILD_PARALLEL_LEVEL="${MAX_CONCURRENT_JOBS}"

    # Build with release optimizations
    flutter pub get
    flutter build linux --release

    BUNDLE_DIR="${REPO_DIR}/build/linux/x64/release/bundle"
elif [[ -d "${REPO_DIR}/build/linux/x64/release/bundle" ]]; then
    BUNDLE_DIR="${REPO_DIR}/build/linux/x64/release/bundle"
    log_info "Using pre-built bundle from: ${BUNDLE_DIR}"
else
    # Build from source using available Flutter installation
    if command -v flutter >/dev/null 2>&1; then
        log_info "Building release bundle from current workspace..."
        cd "${REPO_DIR}"
        export MAKEFLAGS="-j${MAX_CONCURRENT_JOBS}"
        flutter pub get
        flutter build linux --release
        BUNDLE_DIR="${REPO_DIR}/build/linux/x64/release/bundle"
    else
        log_error "No pre-built bundle found and Flutter SDK is not installed."
        log_info "Please install Flutter SDK or download the pre-built Linux release from GitHub."
        exit 1
    fi
fi

if [[ ! -d "${BUNDLE_DIR}" || ! -f "${BUNDLE_DIR}/softify" ]]; then
    log_error "Build output verification failed: ${BUNDLE_DIR}/softify not found."
    exit 1
fi

log_success "Linux native binary verified at: ${BUNDLE_DIR}/softify"

# ------------------------------------------------------------------------------
# Installation & Desktop Integration
# ------------------------------------------------------------------------------
log_info "Installing Softify to ${APP_DIR}..."

# Create target directories
mkdir -p "${APP_DIR}"
mkdir -p "${BIN_DIR}"
mkdir -p "${DESKTOP_DIR}"
mkdir -p "${ICON_DIR_SVG}"
mkdir -p "${ICON_DIR_PNG}"

# Copy bundle files
cp -r "${BUNDLE_DIR}/." "${APP_DIR}/"
chmod +x "${APP_DIR}/softify"

# Create CLI launcher script
LAUNCHER_SCRIPT="${BIN_DIR}/softify"
cat > "${LAUNCHER_SCRIPT}" << EOF
#!/usr/bin/env bash
exec "${APP_DIR}/softify" "\$@"
EOF
chmod +x "${LAUNCHER_SCRIPT}"
log_success "Installed executable wrapper: ${LAUNCHER_SCRIPT}"

# Install Desktop Icons
if [[ -f "${REPO_DIR}/assets/logo/logo.svg" ]]; then
    cp "${REPO_DIR}/assets/logo/logo.svg" "${ICON_DIR_SVG}/softify.svg"
    log_success "Installed scalable icon: ${ICON_DIR_SVG}/softify.svg"
fi

if [[ -f "${REPO_DIR}/assets/logo/logo.png" ]]; then
    cp "${REPO_DIR}/assets/logo/logo.png" "${ICON_DIR_PNG}/softify.png"
    log_success "Installed 512x512 icon: ${ICON_DIR_PNG}/softify.png"
fi

# Install .desktop Application Entry
DESKTOP_FILE="${DESKTOP_DIR}/softify.desktop"
cat > "${DESKTOP_FILE}" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Softify
GenericName=Music Player
Comment=Ad-free, studio-fidelity music streaming application
Exec=${LAUNCHER_SCRIPT} %u
Icon=softify
Terminal=false
StartupWMClass=softify
Categories=AudioVideo;Audio;Player;Music;
Keywords=music;audio;stream;player;lyrics;spotify;saavn;
MimeType=x-scheme-handler/softify;
StartupNotify=true
EOF
chmod 644 "${DESKTOP_FILE}"
log_success "Installed desktop entry: ${DESKTOP_FILE}"

# Update Desktop & Icon Caches
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "${INSTALL_PREFIX}/share/icons/hicolor" 2>/dev/null || true
fi

# Check PATH variable for user-local install
PATH_WARNING=""
if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
    PATH_WARNING="${COLOR_YELLOW}[!] Note: '${BIN_DIR}' is not in your current PATH.${COLOR_RESET}\n    Add this line to your ~/.bashrc or ~/.zshrc:\n    ${COLOR_BOLD}export PATH=\"\$PATH:${BIN_DIR}\"${COLOR_RESET}\n"
fi

# ------------------------------------------------------------------------------
# Installation Summary
# ------------------------------------------------------------------------------
printf "\n"
printf "${COLOR_EMERALD}==============================================================================${COLOR_RESET}\n"
printf "${COLOR_EMERALD}${COLOR_BOLD}  🎉 Softify Linux Desktop Installation Complete!${COLOR_RESET}\n"
printf "${COLOR_EMERALD}==============================================================================${COLOR_RESET}\n\n"

printf "  • ${COLOR_BOLD}Binary:${COLOR_RESET}           ${LAUNCHER_SCRIPT}\n"
printf "  • ${COLOR_BOLD}Application:${COLOR_RESET}      ${APP_DIR}\n"
printf "  • ${COLOR_BOLD}Desktop Entry:${COLOR_RESET}    ${DESKTOP_FILE}\n\n"

if [[ -n "${PATH_WARNING}" ]]; then
    printf "%b\n" "${PATH_WARNING}"
fi

printf "  ${COLOR_BOLD}To launch Softify:${COLOR_RESET}\n"
printf "    1. Terminal:  ${COLOR_EMERALD}${COLOR_BOLD}softify${COLOR_RESET}\n"
printf "    2. GUI Menu:  Search for ${COLOR_EMERALD}${COLOR_BOLD}Softify${COLOR_RESET} in your Application Launcher\n\n"
printf "  ${COLOR_MUTED}To uninstall:${COLOR_RESET}\n"
printf "    Run: ${COLOR_MUTED}%s --uninstall${COLOR_RESET}\n\n" "$0"
