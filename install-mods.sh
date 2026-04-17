#!/usr/bin/env bash
# FF7 Rebirth — Mod Installer / Uninstaller for Linux
# Manages: FFVIIHook, Ultimate Engine Tweaks, OptiScaler (DLSS4/FSR4)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_APP_ID="2909400"
GAME_NAME="FINAL FANTASY VII REBIRTH"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
skip()    { echo -e "${YELLOW}[SKIP]${NC}  $*"; }
die()     { echo -e "${RED}[ERR ]${NC}  $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}── $* ──${NC}"; }

remove_file() {
    local f="$1"
    if [[ -f "$f" ]]; then
        chmod 644 "$f" 2>/dev/null || true   # strip read-only if set
        rm -f "$f"
        success "Removed $f"
    else
        skip "Not found (already removed?): $f"
    fi
}

# ── Defaults ──────────────────────────────────────────────────────────────────
GPU="nvidia"           # nvidia | amd
INSTALL_OPTISCALER=true
USE_VRR=true
UNINSTALL=false

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Installs or uninstalls FF7 Rebirth performance mods on Linux.
Mods managed: FFVIIHook, Ultimate Engine Tweaks, OptiScaler (DLSS4/FSR4).

Install options:
  --gpu nvidia|amd     Graphics card type            (default: nvidia)
  --no-optiscaler      Skip OptiScaler / upscaler installation
  --no-vrr             Use the No-VRR Engine.ini variant
                       (default: VRR / G-Sync / FreeSync enabled)

Uninstall options:
  --uninstall          Remove all installed mod files

General:
  -h, --help           Show this help

Examples:
  $(basename "$0")                     # Install: NVIDIA + DLSS4 + VRR  ← recommended
  $(basename "$0") --gpu amd           # Install: AMD + FSR4 + VRR
  $(basename "$0") --no-vrr            # Install: NVIDIA + DLSS4, no VRR
  $(basename "$0") --gpu amd --no-vrr  # Install: AMD + FSR4, no VRR
  $(basename "$0") --no-optiscaler     # Install: FFVIIHook + Engine tweaks only
  $(basename "$0") --uninstall         # Remove all mod files
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gpu)
            GPU="${2,,}"
            shift 2
            [[ "$GPU" == "nvidia" || "$GPU" == "amd" ]] \
                || die "Invalid --gpu value '$GPU'. Must be 'nvidia' or 'amd'."
            ;;
        --no-optiscaler) INSTALL_OPTISCALER=false; shift ;;
        --no-vrr)        USE_VRR=false;            shift ;;
        --uninstall)     UNINSTALL=true;           shift ;;
        -h|--help)       usage; exit 0 ;;
        *) die "Unknown option: $1  (use --help for usage)" ;;
    esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo
if [[ "$UNINSTALL" == "true" ]]; then
    echo -e "${BOLD}${RED}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║   FF7 Rebirth — Mod Uninstaller (Linux)      ║${NC}"
    echo -e "${BOLD}${RED}╚══════════════════════════════════════════════╝${NC}"
else
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║   FF7 Rebirth — Mod Installer (Linux)        ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo
    info "GPU profile : $GPU"
    info "OptiScaler  : $INSTALL_OPTISCALER"
    info "VRR mode    : $USE_VRR"
fi

# ── Helper: collect Steam library paths ──────────────────────────────────────
collect_steam_libraries() {
    local steam_root="$1"
    local libraries=("$steam_root")
    local vdf="$steam_root/steamapps/libraryfolders.vdf"

    if [[ -f "$vdf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ \"path\"[[:space:]]+'\"'([^\"]+)'\"' ]]; then
                local lib="${BASH_REMATCH[1]}"
                [[ -d "$lib/steamapps" ]] && libraries+=("$lib")
            fi
        done < "$vdf"
    fi
    printf '%s\n' "${libraries[@]}"
}

# ── Locate Steam and the game ─────────────────────────────────────────────────
step "Locating Steam and $GAME_NAME"

STEAM_CANDIDATES=(
    "$HOME/.steam/steam"
    "$HOME/.local/share/Steam"
    "/opt/steam"
    "/usr/games/steam"
)

STEAM_ROOT=""
for candidate in "${STEAM_CANDIDATES[@]}"; do
    if [[ -d "$candidate/steamapps" ]]; then
        STEAM_ROOT="$candidate"
        break
    fi
done
[[ -n "$STEAM_ROOT" ]] || die "Steam not found. Make sure Steam has been run at least once."
success "Steam root   : $STEAM_ROOT"

mapfile -t STEAM_LIBRARIES < <(collect_steam_libraries "$STEAM_ROOT")
info "Libraries    : ${#STEAM_LIBRARIES[@]} found"

GAME_DIR=""
for lib in "${STEAM_LIBRARIES[@]}"; do
    candidate="$lib/steamapps/common/$GAME_NAME"
    if [[ -d "$candidate/End/Binaries/Win64" ]]; then
        GAME_DIR="$candidate"
        break
    fi
done
[[ -n "$GAME_DIR" ]] \
    || die "'$GAME_NAME' not found in any Steam library. Install the game first."
success "Game dir     : $GAME_DIR"

BINARIES_DIR="$GAME_DIR/End/Binaries/Win64"

# Locate the Wine prefix config dir
CONFIG_DIR=""
for lib in "${STEAM_LIBRARIES[@]}"; do
    candidate="$lib/steamapps/compatdata/$GAME_APP_ID/pfx/drive_c/users/steamuser/Documents/My Games/$GAME_NAME/Saved/Config/WindowsNoEditor"
    if [[ -d "$candidate" ]]; then
        CONFIG_DIR="$candidate"
        break
    fi
done

if [[ -z "$CONFIG_DIR" ]]; then
    warn "Engine.ini config directory not found."
    warn "Have you launched the game at least once?"
    warn "Expected path (after first launch):"
    warn "  <SteamLibrary>/steamapps/compatdata/$GAME_APP_ID/pfx/drive_c/users/steamuser/Documents/My Games/$GAME_NAME/Saved/Config/WindowsNoEditor"
    echo
    read -rp "  Enter config dir path manually, or press Enter to skip Engine.ini: " CONFIG_DIR
fi

# ══════════════════════════════════════════════════════════════════════════════
# UNINSTALL
# ══════════════════════════════════════════════════════════════════════════════
if [[ "$UNINSTALL" == "true" ]]; then

    step "Removing FFVIIHook"
    remove_file "$BINARIES_DIR/xinput1_3.dll"

    step "Removing Ultimate Engine Tweaks (Engine.ini)"
    if [[ -n "$CONFIG_DIR" && -d "$CONFIG_DIR" ]]; then
        remove_file "$CONFIG_DIR/Engine.ini"
    else
        warn "Config directory not found — skipping Engine.ini removal."
    fi

    step "Removing OptiScaler files"
    # Remove all possible OptiScaler files regardless of which variant was installed
    OPTISCALER_FILES=(
        "amd_fidelityfx_dx12.dll"   # both variants
        "OptiScaler.ini"             # both variants
        "version.dll"                # DLSS variant
        "nvngx_dlss_updated.dll"    # DLSS variant
        "dxgi.dll"                   # FSR / XeSS variant
        "nvngx.dll"                  # FSR / XeSS variant
        "libxess.dll"                # XeSS variant
    )
    for f in "${OPTISCALER_FILES[@]}"; do
        remove_file "$BINARIES_DIR/$f"
    done

    echo
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║   Uninstall complete!                        ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BOLD}${YELLOW}Manual step remaining:${NC}"
    echo "  Remove the WINEDLLOVERRIDES launch options from Steam:"
    echo "  Steam → right-click game → Properties → Launch Options → clear the field"
    echo
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# INSTALL
# ══════════════════════════════════════════════════════════════════════════════

# ── Step 1: FFVIIHook ─────────────────────────────────────────────────────────
step "Step 1 — FFVIIHook"

HOOK_SRC=$(find "$SCRIPT_DIR/FFVIIHook-Rebirth"* -name "xinput1_3.dll" 2>/dev/null | head -1)
[[ -n "$HOOK_SRC" ]] \
    || die "xinput1_3.dll not found. Make sure the FFVIIHook-Rebirth-* folder is present."

cp "$HOOK_SRC" "$BINARIES_DIR/xinput1_3.dll"
success "Copied xinput1_3.dll  →  $BINARIES_DIR/"

# ── Step 2: Engine.ini ────────────────────────────────────────────────────────
step "Step 2 — Ultimate Engine Tweaks (Engine.ini)"

if [[ -n "$CONFIG_DIR" && -d "$CONFIG_DIR" ]]; then
    if [[ "$USE_VRR" == "true" ]]; then
        INI_SRC=$(find "$SCRIPT_DIR" -name "Engine.ini" -path "*VRR*" ! -path "*No VRR*" | head -1)
        VRR_LABEL="VRR"
    else
        INI_SRC=$(find "$SCRIPT_DIR" -name "Engine.ini" -path "*No VRR*" | head -1)
        VRR_LABEL="No VRR"
    fi
    [[ -n "$INI_SRC" ]] || die "Engine.ini ($VRR_LABEL variant) not found in repo."

    # Remove read-only flag if a previous install exists
    [[ -f "$CONFIG_DIR/Engine.ini" ]] && chmod 644 "$CONFIG_DIR/Engine.ini"

    cp "$INI_SRC" "$CONFIG_DIR/Engine.ini"
    chmod 444 "$CONFIG_DIR/Engine.ini"
    success "Copied Engine.ini ($VRR_LABEL)  →  $CONFIG_DIR/"
    success "Set Engine.ini read-only (chmod 444)"
else
    warn "Skipping Engine.ini — config directory not available."
fi

# ── Step 3: OptiScaler ────────────────────────────────────────────────────────
OPTISCALER_DLL_OVERRIDE=""

if [[ "$INSTALL_OPTISCALER" == "true" ]]; then
    step "Step 3 — OptiScaler ($([ "$GPU" = "nvidia" ] && echo "DLSS4" || echo "FSR4"))"

    OPTISCALER_DIR="$SCRIPT_DIR/FFVII DLSS4-FSR4"

    if [[ "$GPU" == "nvidia" ]]; then
        DLSS_ZIP=$(find "$OPTISCALER_DIR" -maxdepth 1 -name "*DLSS*Mod*.zip" | head -1)
        [[ -n "$DLSS_ZIP" ]] \
            || die "DLSS mod zip not found in 'FFVII DLSS4-FSR4/'. Check the repo is complete."

        info "Extracting: $(basename "$DLSS_ZIP")"
        unzip -o "$DLSS_ZIP" -d "$BINARIES_DIR" -x "Readme.txt" > /dev/null
        success "Extracted DLSS4 files  →  $BINARIES_DIR/"
        OPTISCALER_DLL_OVERRIDE="version.dll=n,b"

    else  # amd
        FSR_ZIP=$(find "$OPTISCALER_DIR" -maxdepth 1 -name "*FSR*Mod*.zip" | head -1)
        [[ -n "$FSR_ZIP" ]] \
            || die "FSR mod zip not found in 'FFVII DLSS4-FSR4/'. Check the repo is complete."

        info "Extracting: $(basename "$FSR_ZIP")"
        unzip -o "$FSR_ZIP" -d "$BINARIES_DIR" -x "Readme.txt" > /dev/null
        success "Extracted FSR4 files  →  $BINARIES_DIR/"
        OPTISCALER_DLL_OVERRIDE="dxgi.dll=n,b"
    fi
fi

# ── Step 4: Print Steam launch options ───────────────────────────────────────
step "Step 4 — Steam Launch Options"

DLL_OVERRIDES="xinput1_3=n,b"
[[ -n "$OPTISCALER_DLL_OVERRIDE" ]] && DLL_OVERRIDES="${DLL_OVERRIDES};${OPTISCALER_DLL_OVERRIDE}"

if [[ "$GPU" == "nvidia" ]]; then
    ENV_VAR="__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1"
else
    ENV_VAR="RADV_PERFTEST=nggc"
fi

LAUNCH_OPTIONS="WINEDLLOVERRIDES=\"${DLL_OVERRIDES}\" ${ENV_VAR} gamemoderun %command% -nodirectstorage"

echo
echo -e "${YELLOW}Set the following in Steam → right-click game → Properties → Launch Options:${NC}"
echo
echo -e "  ${BOLD}${LAUNCH_OPTIONS}${NC}"
echo
echo -e "${YELLOW}(Steam launch options cannot be set automatically from a script.)${NC}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   Installation complete!                     ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Copy the Launch Options above into Steam"
echo "  2. Launch the game"
echo "  3. Graphics → Anti-Aliasing Method → DLSS"
echo "  4. Graphics → Background Model Detail → Ultra"
if [[ "$INSTALL_OPTISCALER" == "true" ]]; then
    echo "  5. Optional: Press Insert in-game to enable Frame Generation"
    echo "     (note: currently causes HUD glitching)"
fi
echo
