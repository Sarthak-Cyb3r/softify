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
    printf "  ${COLOR_EMERALD}${COLOR_BOLD}Linux Desktop Terminal Installer${COLOR_RESET} ${COLOR_MUTED}• v2.0.6-beta-0.3${COLOR_RESET}\n"
    printf "  ${COLOR_DIM}Ad-Free • Studio Master Audio • Fast Local-First UI${COLOR_RESET}\n\n"
}

# ------------------------------------------------------------------------------
# Safe Location & Repository Discovery (Handles curl | bash pipe cleanly)
# ------------------------------------------------------------------------------
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
fi

# Detect local Softify git repository if present
LOCAL_REPO=""
if [[ -n "$SCRIPT_DIR" && -f "${SCRIPT_DIR}/pubspec.yaml" ]]; then
    LOCAL_REPO="$SCRIPT_DIR"
elif [[ -f "$(pwd)/pubspec.yaml" && $(grep -c "name: softify" "$(pwd)/pubspec.yaml" 2>/dev/null || true) -gt 0 ]]; then
    LOCAL_REPO="$(pwd)"
fi

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
    printf "Usage: %s [OPTIONS]\n\n" "${0:-install.sh}"
    printf "Options:\n"
    printf "  -y, --yes               Auto-confirm all prompts (non-interactive mode)\n"
    printf "  -b, --build             Build native Linux binary from local source code\n"
    printf "  -u, --uninstall         Uninstall Softify and clean up desktop integrations\n"
    printf "  -s, --system            Install system-wide into /usr/local (requires sudo)\n"
    printf "  -h, --help              Show this help menu and exit\n\n"
    printf "Examples:\n"
    printf "  curl -fsSL https://raw.githubusercontent.com/Sarthak-Cyb3r/softify/main/install.sh | bash\n"
    printf "  ./install.sh                      # Standard fast pre-built installation\n"
    printf "  ./install.sh --build              # Compile and install from source\n"
    printf "  ./install.sh --uninstall          # Cleanly remove Softify\n"
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
            printf "Use '%s --help' to see available options.\n" "${0:-install.sh}"
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
        read -r answer </dev/tty || answer="n"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            log_warn "Uninstallation cancelled by user."
            exit 0
        fi
    fi

    # Remove binary executable wrapper
    if [[ -f "${BIN_DIR}/softify" || -L "${BIN_DIR}/softify" ]]; then
        rm -f "${BIN_DIR}/softify"
        log_info "Removed executable: ${BIN_DIR}/softify"
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
        log_info "Removed application directory: ${APP_DIR}"
    fi

    # Update desktop database & icon caches
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
    log_warn "Enforcing strict concurrency limit (max 1 build job) to prevent OS freezes."
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
# Runtime Dependencies Check
# ------------------------------------------------------------------------------
check_runtime_deps() {
    local missing_tools=()
    for cmd in curl tar; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_tools+=("$cmd")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing fundamental utilities: ${missing_tools[*]}"
        log_info "Please install them using your package manager (e.g. sudo apt install ${missing_tools[*]})."
        exit 1
    fi

    # Verify libmpv audio decoder library
    local has_mpv=false
    if ldconfig -p 2>/dev/null | grep -qE "libmpv\.so\.[12]"; then
        has_mpv=true
    elif [[ -f /usr/lib/x86_64-linux-gnu/libmpv.so.2 || -f /usr/lib/libmpv.so.2 || -f /usr/local/lib/libmpv.so.2 || -f /lib/x86_64-linux-gnu/libmpv.so.2 ]]; then
        has_mpv=true
    fi

    if [[ "$has_mpv" != true ]]; then
        log_warn "Missing audio decoder library (libmpv2 / mpv required for playback)."
        local mpv_install=""
        case "$DISTRO_ID" in
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                mpv_install="sudo apt-get update && sudo apt-get install -y libmpv2 mpv"
                ;;
            arch|manjaro|endeavouros)
                mpv_install="sudo pacman -S --needed --noconfirm mpv"
                ;;
            fedora|rhel|centos)
                mpv_install="sudo dnf install -y mpv mpv-libs"
                ;;
            opensuse*|suse)
                mpv_install="sudo zypper in -y mpv libmpv2"
                ;;
        esac
        if [[ -n "$mpv_install" ]]; then
            log_info "Installing libmpv audio playback engine..."
            eval "$mpv_install" || log_warn "Could not automatically install libmpv. Please install libmpv2 manually if audio fails."
        fi
    fi
}

check_runtime_deps

# ------------------------------------------------------------------------------
# Source Build Dependencies & Installation
# ------------------------------------------------------------------------------
install_source_build_deps() {
    local missing_pkgs=()
    for cmd in pkg-config clang cmake ninja; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_pkgs+=("$cmd")
        fi
    done

    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        log_warn "Missing compiler tools required for building from source: ${missing_pkgs[*]}"
        local install_cmd=""
        case "$DISTRO_ID" in
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                install_cmd="sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libasound2-dev libpulse-dev libmpv-dev mpv"
                ;;
            arch|manjaro|endeavouros)
                install_cmd="sudo pacman -S --needed --noconfirm clang cmake ninja pkgconf gtk3 xz alsa-lib libpulse mpv"
                ;;
            fedora|rhel|centos)
                install_cmd="sudo dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel alsa-lib-devel pulseaudio-libs-devel mpv-devel mpv"
                ;;
            opensuse*|suse)
                install_cmd="sudo zypper in -y clang cmake ninja pkg-config gtk3-devel liblzma-devel alsa-devel libpulse-devel mpv-devel mpv"
                ;;
            *)
                log_warn "Please install the missing tools manually using your package manager."
                return 0
                ;;
        esac

        if [[ "$AUTO_CONFIRM" == true ]]; then
            log_info "Installing build packages..."
            eval "$install_cmd"
        else
            printf "\nInstall system build dependencies now? [Y/n]: "
            read -r ans </dev/tty || ans="n"
            if [[ ! "$ans" =~ ^[Nn]$ ]]; then
                log_info "Running: ${install_cmd}"
                eval "$install_cmd"
            else
                log_warn "Skipped package installation. Build might fail."
            fi
        fi
    fi
}

# ------------------------------------------------------------------------------
# Resolution Strategy: Pre-built Binary vs Local Build
# ------------------------------------------------------------------------------
TMP_WORK_DIR=""
cleanup_temp() {
    if [[ -n "$TMP_WORK_DIR" && -d "$TMP_WORK_DIR" ]]; then
        rm -rf "$TMP_WORK_DIR"
    fi
}
trap cleanup_temp EXIT

BUNDLE_DIR=""
GITHUB_REPO="Sarthak-Cyb3r/softify"
RELEASE_TAG="${SOFTIFY_VERSION:-latest}"
TARBALL_NAME="Softify-Linux-x64.tar.gz"

if [[ "$RELEASE_TAG" == "latest" ]]; then
    RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${TARBALL_NAME}"
    FALLBACK_URL=""
else
    RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${TARBALL_NAME}"
    FALLBACK_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${TARBALL_NAME}"
fi

try_download_prebuilt() {
    log_info "Searching for pre-built Linux release package (${RELEASE_TAG})..."
    
    local download_url="$RELEASE_URL"
    local http_code
    http_code=$(curl -sIL -o /dev/null -w "%{http_code}" "$download_url" 2>/dev/null || echo "000")

    if [[ "$http_code" != "200" && "$http_code" != "302" ]] && [[ -n "$FALLBACK_URL" ]]; then
        # Try latest release fallback
        download_url="$FALLBACK_URL"
        http_code=$(curl -sIL -o /dev/null -w "%{http_code}" "$download_url" 2>/dev/null || echo "000")
    fi

    if [[ "$http_code" == "200" || "$http_code" == "302" ]]; then
        log_info "Downloading pre-compiled release package from GitHub..."
        TMP_WORK_DIR=$(mktemp -d /tmp/softify-install-XXXXXX)
        local dest_archive="${TMP_WORK_DIR}/${TARBALL_NAME}"

        if curl -fL --progress-bar "$download_url" -o "$dest_archive"; then
            log_success "Downloaded release package successfully."
            log_info "Extracting bundle..."
            mkdir -p "${TMP_WORK_DIR}/extracted"
            tar -xzf "$dest_archive" -C "${TMP_WORK_DIR}/extracted"

            if [[ -d "${TMP_WORK_DIR}/extracted/bundle" && -f "${TMP_WORK_DIR}/extracted/bundle/softify" ]]; then
                BUNDLE_DIR="${TMP_WORK_DIR}/extracted/bundle"
                return 0
            elif [[ -f "${TMP_WORK_DIR}/extracted/softify" ]]; then
                BUNDLE_DIR="${TMP_WORK_DIR}/extracted"
                return 0
            fi
        fi
    fi

    return 1
}

# If user did NOT request --build, try pre-built package first
if [[ "$BUILD_FROM_SOURCE" != true ]]; then
    # First: Check if local repo already has a pre-built bundle
    if [[ -n "$LOCAL_REPO" && -d "${LOCAL_REPO}/build/linux/x64/release/bundle" && -f "${LOCAL_REPO}/build/linux/x64/release/bundle/softify" ]]; then
        BUNDLE_DIR="${LOCAL_REPO}/build/linux/x64/release/bundle"
        log_success "Found local pre-built bundle at: ${BUNDLE_DIR}"
    else
        # Second: Try downloading prebuilt binary from GitHub Releases
        if try_download_prebuilt; then
            log_success "Pre-built Linux bundle verified and ready for installation."
        fi
    fi
fi

# If bundle is still empty, decide next step
if [[ -z "$BUNDLE_DIR" ]]; then
    if [[ "$BUILD_FROM_SOURCE" == true ]] || [[ -n "$LOCAL_REPO" ]]; then
        TARGET_REPO="${LOCAL_REPO:-}"
        if [[ -z "$TARGET_REPO" ]]; then
            log_error "--build was requested, but no Softify Flutter repository was found."
            log_info "Please clone the repository first:"
            log_info "  git clone https://github.com/${GITHUB_REPO}.git && cd softify && ./install.sh --build"
            exit 1
        fi

        log_warn "Pre-built binary package not found or --build requested."
        log_info "Detected local Softify repository at: ${COLOR_BOLD}${TARGET_REPO}${COLOR_RESET}"

        if (( TOTAL_MEM_MB <= 5120 )); then
            log_warn "RAM Caution: Your system has ${AVAILABLE_MEM_MB} MB free RAM out of ${TOTAL_MEM_MB} MB."
            log_warn "Building locally requires compilation that may take several minutes."
            if [[ "$AUTO_CONFIRM" != true ]]; then
                printf "\nProceed with memory-safe local compilation? [y/N]: "
                read -r confirm_build </dev/tty || confirm_build="n"
                if [[ ! "$confirm_build" =~ ^[Yy]$ ]]; then
                    log_warn "Installation cancelled by user."
                    exit 0
                fi
            fi
        fi

        install_source_build_deps

        if ! command -v flutter >/dev/null 2>&1; then
            log_error "Flutter SDK was not found in PATH."
            log_info "Please install Flutter (https://docs.flutter.dev/get-started/install/linux) to build from source."
            exit 1
        fi

        log_info "Building Softify native Linux bundle with low-memory safety..."
        log_info "Concurrency limits: MAKEFLAGS=\"-j${MAX_CONCURRENT_JOBS}\""

        cd "${TARGET_REPO}"
        export MAKEFLAGS="-j${MAX_CONCURRENT_JOBS}"
        export CMAKE_BUILD_PARALLEL_LEVEL="${MAX_CONCURRENT_JOBS}"

        flutter config --enable-linux-desktop >/dev/null 2>&1 || true
        flutter pub get
        flutter build linux --release

        BUNDLE_DIR="${TARGET_REPO}/build/linux/x64/release/bundle"
    else
        log_error "No pre-built Linux release package found on GitHub Releases yet."
        log_info "GitHub Actions is currently building and publishing the official v2.0.0 Linux assets."
        log_info "To compile from source manually:"
        log_info "  git clone https://github.com/${GITHUB_REPO}.git"
        log_info "  cd softify && ./install.sh --build"
        exit 1
    fi
fi

if [[ ! -d "${BUNDLE_DIR}" || ! -f "${BUNDLE_DIR}/softify" ]]; then
    log_error "Bundle validation failed: ${BUNDLE_DIR}/softify not found."
    exit 1
fi

log_success "Linux binary verified at: ${BUNDLE_DIR}/softify"

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

# Copy bundle files safely (unlink existing binary if running)
rm -f "${APP_DIR}/softify"
cp -rf "${BUNDLE_DIR}/." "${APP_DIR}/"
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
ICON_INSTALLED=false

# 1. Check inside bundle flutter assets
if [[ -f "${APP_DIR}/data/flutter_assets/assets/logo/logo.png" ]]; then
    cp "${APP_DIR}/data/flutter_assets/assets/logo/logo.png" "${ICON_DIR_PNG}/softify.png"
    ICON_INSTALLED=true
fi
if [[ -f "${APP_DIR}/data/flutter_assets/assets/logo/logo.svg" ]]; then
    cp "${APP_DIR}/data/flutter_assets/assets/logo/logo.svg" "${ICON_DIR_SVG}/softify.svg"
    ICON_INSTALLED=true
fi

# 2. Check inside local repository
if [[ "$ICON_INSTALLED" != true && -n "$LOCAL_REPO" ]]; then
    if [[ -f "${LOCAL_REPO}/assets/logo/logo.png" ]]; then
        cp "${LOCAL_REPO}/assets/logo/logo.png" "${ICON_DIR_PNG}/softify.png"
        ICON_INSTALLED=true
    fi
    if [[ -f "${LOCAL_REPO}/assets/logo/logo.svg" ]]; then
        cp "${LOCAL_REPO}/assets/logo/logo.svg" "${ICON_DIR_SVG}/softify.svg"
        ICON_INSTALLED=true
    fi
fi

# 3. Fallback: Download icon directly from GitHub repository
if [[ "$ICON_INSTALLED" != true ]]; then
    curl -fsSL "https://raw.githubusercontent.com/${GITHUB_REPO}/main/assets/logo/logo.png" -o "${ICON_DIR_PNG}/softify.png" 2>/dev/null || true
    if [[ -f "${ICON_DIR_PNG}/softify.png" ]]; then
        ICON_INSTALLED=true
    fi
fi

if [[ "$ICON_INSTALLED" == true ]]; then
    log_success "Installed application desktop icons."
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
printf "    Run: ${COLOR_MUTED}%s --uninstall${COLOR_RESET}\n\n" "${0:-install.sh}"
