#!/usr/bin/env bash
# FF7 Rebirth — Mod Installer / Uninstaller / Verifier for Linux
# Manages: FFVIIHook, Ultimate Engine Tweaks, OptiScaler (DLSS4/FSR4),
#          Fantasy Optimizer, Enhanced Fantasy Visuals
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
fail()    { echo -e "${RED}[FAIL]${NC}  $*"; VERIFY_FAILED=true; }
die()     { echo -e "${RED}[ERR ]${NC}  $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}── $* ──${NC}"; }

remove_file() {
    local f="$1"
    if [[ -f "$f" ]]; then
        chmod 644 "$f" 2>/dev/null || true
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
INSTALL_FANTASY_OPTIMIZER=true
INSTALL_ENHANCED_VISUALS=true
EFV_FOG=false
UNINSTALL=false
VERIFY=false
VERIFY_FAILED=false

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Installs, uninstalls, or verifies FF7 Rebirth performance mods on Linux.
Mods managed: FFVIIHook, Ultimate Engine Tweaks, OptiScaler (DLSS4/FSR4),
              Fantasy Optimizer, Enhanced Fantasy Visuals.

Install options:
  --gpu nvidia|amd          Graphics card type            (default: nvidia)
  --no-optiscaler           Skip OptiScaler / upscaler installation
  --no-vrr                  Use the No-VRR Engine.ini variant
                            (default: VRR / G-Sync / FreeSync enabled)
  --no-fantasy-optimizer    Skip Fantasy Optimizer (.pak) installation
  --no-enhanced-visuals     Skip Enhanced Fantasy Visuals (.pak) installation
  --efv-fog                 Use the Fog Enabled variant of Enhanced Fantasy Visuals
                            (default: standard variant)

Other options:
  --uninstall               Remove all installed mod files
  --verify                  Check that all mods are correctly installed
  -h, --help                Show this help

Examples:
  $(basename "$0")                             # Install all mods: NVIDIA + DLSS4 + VRR  ← recommended
  $(basename "$0") --gpu amd                   # Install: AMD + FSR4 + VRR
  $(basename "$0") --no-vrr                    # Install: NVIDIA + DLSS4, no VRR
  $(basename "$0") --gpu amd --no-vrr          # Install: AMD + FSR4, no VRR
  $(basename "$0") --no-optiscaler             # Install: FFVIIHook + Engine tweaks only
  $(basename "$0") --no-fantasy-optimizer      # Skip Fantasy Optimizer
  $(basename "$0") --no-enhanced-visuals       # Skip Enhanced Fantasy Visuals
  $(basename "$0") --efv-fog                   # Use Fog Enabled variant
  $(basename "$0") --uninstall                 # Remove all mod files
  $(basename "$0") --verify                    # Verify all mods are correctly applied
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
        --no-optiscaler)          INSTALL_OPTISCALER=false;        shift ;;
        --no-vrr)                 USE_VRR=false;                   shift ;;
        --no-fantasy-optimizer)   INSTALL_FANTASY_OPTIMIZER=false; shift ;;
        --no-enhanced-visuals)    INSTALL_ENHANCED_VISUALS=false;  shift ;;
        --efv-fog)                EFV_FOG=true;                    shift ;;
        --uninstall)              UNINSTALL=true;                  shift ;;
        --verify)                 VERIFY=true;                     shift ;;
        -h|--help)                usage; exit 0 ;;
        *) die "Unknown option: $1  (use --help for usage)" ;;
    esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo
if [[ "$UNINSTALL" == "true" ]]; then
    echo -e "${BOLD}${RED}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║   FF7 Rebirth — Mod Uninstaller (Linux)      ║${NC}"
    echo -e "${BOLD}${RED}╚══════════════════════════════════════════════╝${NC}"
elif [[ "$VERIFY" == "true" ]]; then
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║   FF7 Rebirth — Mod Verifier (Linux)         ║${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════╝${NC}"
    echo
    info "GPU profile      : $GPU"
    info "OptiScaler       : $INSTALL_OPTISCALER"
    info "VRR mode         : $USE_VRR"
    info "Fantasy Optimizer: $INSTALL_FANTASY_OPTIMIZER"
    EFV_VARIANT="$( [[ "$EFV_FOG" == "true" ]] && echo "fog" || echo "standard" )"
    info "Enhanced Visuals : $INSTALL_ENHANCED_VISUALS ($EFV_VARIANT)"
else
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║   FF7 Rebirth — Mod Installer (Linux)        ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo
    info "GPU profile      : $GPU"
    info "OptiScaler       : $INSTALL_OPTISCALER"
    info "VRR mode         : $USE_VRR"
    info "Fantasy Optimizer: $INSTALL_FANTASY_OPTIMIZER"
    EFV_VARIANT="$( [[ "$EFV_FOG" == "true" ]] && echo "fog" || echo "standard" )"
    info "Enhanced Visuals : $INSTALL_ENHANCED_VISUALS ($EFV_VARIANT)"
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
PAKS_MOD_DIR="$GAME_DIR/End/Content/Paks/~mods"

# Locate the Wine prefix config dir
CONFIG_DIR=""
for lib in "${STEAM_LIBRARIES[@]}"; do
    candidate="$lib/steamapps/compatdata/$GAME_APP_ID/pfx/drive_c/users/steamuser/Documents/My Games/$GAME_NAME/Saved/Config/WindowsNoEditor"
    if [[ -d "$candidate" ]]; then
        CONFIG_DIR="$candidate"
        break
    fi
done

if [[ -z "$CONFIG_DIR" && "$UNINSTALL" != "true" ]]; then
    warn "Engine.ini config directory not found."
    warn "Have you launched the game at least once?"
    warn "Expected path (after first launch):"
    warn "  <SteamLibrary>/steamapps/compatdata/$GAME_APP_ID/pfx/drive_c/users/steamuser/Documents/My Games/$GAME_NAME/Saved/Config/WindowsNoEditor"
    echo
    read -rp "  Enter config dir path manually, or press Enter to skip Engine.ini: " CONFIG_DIR
fi

# ══════════════════════════════════════════════════════════════════════════════
# VERIFY
# ══════════════════════════════════════════════════════════════════════════════
if [[ "$VERIFY" == "true" ]]; then

    # ── Check 1: FFVIIHook ────────────────────────────────────────────────────
    step "Check 1 — FFVIIHook"

    HOOK_FILE="$BINARIES_DIR/xinput1_3.dll"
    if [[ -f "$HOOK_FILE" ]]; then
        success "xinput1_3.dll present in $BINARIES_DIR/"
    else
        fail "xinput1_3.dll NOT found in $BINARIES_DIR/"
        warn "  → Fix: run  ./install-mods.sh  (or check Step 1 in README)"
        warn "  → Without FFVIIHook, Engine.ini CVars are ignored and stutters persist"
        # Check for alternate DLL names the user may have used
        for alt in dxgi.dll winmm.dll d3d9.dll d3d11.dll; do
            if [[ -f "$BINARIES_DIR/$alt" ]]; then
                info "  Found $alt — if this is FFVIIHook renamed, that is OK"
                info "  Make sure your Steam Launch Options use WINEDLLOVERRIDES=\"${alt%.*}=n,b;...\""
            fi
        done
    fi

    # ── Check 2: Engine.ini ───────────────────────────────────────────────────
    step "Check 2 — Ultimate Engine Tweaks (Engine.ini)"

    INI_FILE="${CONFIG_DIR:+$CONFIG_DIR/Engine.ini}"

    if [[ -z "$CONFIG_DIR" || ! -d "$CONFIG_DIR" ]]; then
        fail "Config directory not found — Engine.ini cannot be checked"
        warn "  → Launch the game once to create it, then re-run --verify"
    elif [[ ! -f "$CONFIG_DIR/Engine.ini" ]]; then
        fail "Engine.ini NOT found in $CONFIG_DIR/"
        warn "  → Fix: run  ./install-mods.sh  to copy the optimised Engine.ini"
    else
        success "Engine.ini present in $CONFIG_DIR/"

        # Check read-only
        if [[ ! -w "$CONFIG_DIR/Engine.ini" ]]; then
            success "Engine.ini is read-only (protected from game overwrite)"
        else
            fail "Engine.ini is NOT read-only — the game may overwrite it on launch"
            warn "  → Fix: chmod 444 \"$CONFIG_DIR/Engine.ini\""
        fi

        # Check it is the Ultimate Tweaks file (not the vanilla game file)
        if grep -q "Ultimate Engine Tweaks\|P40L0\|techoptimized" "$CONFIG_DIR/Engine.ini" 2>/dev/null; then
            success "Engine.ini signature matches Ultimate Engine Tweaks"
        else
            fail "Engine.ini does not look like the Ultimate Engine Tweaks file"
            warn "  → The file may be vanilla or from a different mod"
            warn "  → Fix: run  ./install-mods.sh  to replace it"
        fi

        # Check ConsoleVariables section (required for CVars to work with FFVIIHook)
        if grep -q "\[ConsoleVariables\]" "$CONFIG_DIR/Engine.ini" 2>/dev/null; then
            success "[ConsoleVariables] section present"
        else
            fail "[ConsoleVariables] section missing from Engine.ini"
            warn "  → FFVIIHook reads from this section; missing it means no CVar overrides"
        fi

        # VRR-specific check
        if grep -q "r\.VSync=0" "$CONFIG_DIR/Engine.ini" 2>/dev/null; then
            info "VRR variant detected (r.VSync=0 found)"
        else
            info "No-VRR variant detected"
        fi
    fi

    # ── Check 3: OptiScaler ───────────────────────────────────────────────────
    step "Check 3 — OptiScaler (DLSS4 / FSR4)"

    if [[ "$GPU" == "nvidia" ]]; then
        OPTISCALER_DLL="$BINARIES_DIR/version.dll"
        OPTISCALER_LABEL="version.dll (DLSS4/NVIDIA)"
    else
        OPTISCALER_DLL="$BINARIES_DIR/dxgi.dll"
        OPTISCALER_LABEL="dxgi.dll (FSR4/AMD)"
    fi
    OPTISCALER_COMMON="$BINARIES_DIR/amd_fidelityfx_dx12.dll"
    OPTISCALER_INI="$BINARIES_DIR/OptiScaler.ini"

    if [[ -f "$OPTISCALER_DLL" ]]; then
        success "$OPTISCALER_LABEL present"
    else
        fail "$OPTISCALER_LABEL NOT found"
        warn "  → Fix: run  ./install-mods.sh --gpu $GPU"
        warn "  → Without this, the DLSS/FSR upscaler won't load"
    fi

    if [[ -f "$OPTISCALER_COMMON" ]]; then
        success "amd_fidelityfx_dx12.dll present"
    else
        fail "amd_fidelityfx_dx12.dll NOT found"
        warn "  → Fix: run  ./install-mods.sh --gpu $GPU"
    fi

    # fakenvapi is new in 0.9 — check it
    if [[ -f "$BINARIES_DIR/fakenvapi.dll" ]]; then
        success "fakenvapi.dll present (OptiScaler 0.9+)"
    else
        warn "fakenvapi.dll not found — you may be running an older OptiScaler; re-run ./install-mods.sh to upgrade"
    fi

    if [[ -f "$OPTISCALER_INI" ]]; then
        success "OptiScaler.ini present"
        # Check overlays disabled (recommended)
        if grep -q "DisableOverlays.*true\|DisableOverlays.*1" "$OPTISCALER_INI" 2>/dev/null; then
            info "Steam/Epic overlay is disabled in OptiScaler.ini (recommended)"
        fi
    else
        fail "OptiScaler.ini NOT found"
        warn "  → Fix: run  ./install-mods.sh --gpu $GPU"
    fi

    # ── Check 4: Proton / Wine compat data ───────────────────────────────────
    step "Check 4 — Proton compatibility data"

    COMPAT_DIR=""
    for lib in "${STEAM_LIBRARIES[@]}"; do
        candidate="$lib/steamapps/compatdata/$GAME_APP_ID"
        if [[ -d "$candidate" ]]; then
            COMPAT_DIR="$candidate"
            break
        fi
    done

    if [[ -n "$COMPAT_DIR" ]]; then
        success "Proton compat data found: $COMPAT_DIR"
    else
        fail "Proton compat data not found for app ID $GAME_APP_ID"
        warn "  → The game has not been run with Proton yet"
        warn "  → Launch the game once, let it reach the menu, then re-verify"
    fi

    # ── Check 5: PROTON_ENABLE_NVAPI (NVIDIA only) ────────────────────────────
    if [[ "$GPU" == "nvidia" ]]; then
        step "Check 5 — PROTON_ENABLE_NVAPI (NVIDIA / DLSS)"

        # Try to read Steam localconfig.vdf for the stored launch options
        LAUNCH_OPTS_FOUND=""
        for userdata_dir in "$STEAM_ROOT/userdata"/*/config/localconfig.vdf \
                            "$HOME/.local/share/Steam/userdata"/*/config/localconfig.vdf; do
            [[ -f "$userdata_dir" ]] || continue
            # Extract everything after the app ID block
            snippet=$(python3 -c "
import sys, re
c = open('$userdata_dir', errors='ignore').read()
# Match standalone '2909400' block, capture LaunchOptions handling escaped quotes
m = re.search(r'\t+\"2909400\"\n\t+\{.*?\"LaunchOptions\"\s*\"((?:[^\"\\\\]|\\\\.)*)\"', c, re.DOTALL)
if m: print(m.group(1).replace('\\\\\"', '\"'))
" 2>/dev/null)
            [[ -n "$snippet" ]] && LAUNCH_OPTS_FOUND="$snippet" && break
        done

        if [[ -n "$LAUNCH_OPTS_FOUND" ]]; then
            info "Detected Launch Options: $LAUNCH_OPTS_FOUND"
            if echo "$LAUNCH_OPTS_FOUND" | grep -q "PROTON_ENABLE_NVAPI=1"; then
                success "PROTON_ENABLE_NVAPI=1 is set in Steam Launch Options"
                success "DLSS will communicate with the NVIDIA GPU correctly"
            else
                fail "PROTON_ENABLE_NVAPI=1 is MISSING from Steam Launch Options"
                warn "  → Without this, DLSS silently fails and the game falls back"
                warn "    to unoptimised rendering — this is the most common stutter cause on Linux"
                warn "  → Fix: update your Steam Launch Options to:"
                warn "    WINEDLLOVERRIDES=\"xinput1_3=n,b;version.dll=n,b\" PROTON_ENABLE_NVAPI=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 gamemoderun %command% -nodirectstorage"
            fi
            if echo "$LAUNCH_OPTS_FOUND" | grep -q "gamemoderun"; then
                success "gamemoderun is present in Steam Launch Options"
            else
                fail "gamemoderun is MISSING from Steam Launch Options"
                warn "  → Install gamemode:  sudo apt install gamemode"
                warn "  → Then add gamemoderun before %command% in Launch Options"
            fi
        else
            warn "Could not read Steam Launch Options automatically"
            warn "  → Manually verify your Launch Options contain:"
            warn "    PROTON_ENABLE_NVAPI=1  and  gamemoderun"
        fi
    fi

    # ── Check 6: CPU power governor ───────────────────────────────────────────
    step "Check 6 — CPU power governor"

    GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    info "Current CPU governor: $GOVERNOR"

    if [[ "$GOVERNOR" == "performance" ]]; then
        success "CPU governor is set to 'performance'"
    elif [[ "$GOVERNOR" == "powersave" ]]; then
        warn "CPU governor is 'powersave' — this throttles CPU frequency and causes stuttering"
        warn "  GameMode should switch it to 'performance' while the game runs."
        warn "  If you're still stuttering, set it manually before launching:"
        warn "    sudo apt install cpufrequtils"
        warn "    sudo cpufreq-set -g performance"
        warn "  Or permanently via TLP/auto-cpufreq if on a laptop"
    else
        info "CPU governor '$GOVERNOR' — for best performance, 'performance' is recommended"
    fi

    # ── Check 7: Fantasy Optimizer ────────────────────────────────────────────
    step "Check 7 — Fantasy Optimizer"

    FO_PAK="$PAKS_MOD_DIR/ZZFrancisLouisFOVer2_P.pak"
    if [[ -f "$FO_PAK" ]]; then
        success "Fantasy Optimizer .pak present: $FO_PAK"
    else
        fail "Fantasy Optimizer .pak NOT found: $FO_PAK"
        warn "  → Fix: run  ./install-mods.sh  (or check Step 6 in README)"
    fi

    # ── Check 8: Enhanced Fantasy Visuals ─────────────────────────────────────
    step "Check 8 — Enhanced Fantasy Visuals"

    EFV_PAK_STD="$PAKS_MOD_DIR/ZFrancisLouis_EFVEpic_P.pak"
    EFV_PAK_FOG="$PAKS_MOD_DIR/ZFrancisLouis_EFVFogEpic_P.pak"
    if [[ -f "$EFV_PAK_STD" ]]; then
        success "Enhanced Fantasy Visuals (standard) .pak present: $EFV_PAK_STD"
    elif [[ -f "$EFV_PAK_FOG" ]]; then
        success "Enhanced Fantasy Visuals (fog) .pak present: $EFV_PAK_FOG"
    else
        fail "Enhanced Fantasy Visuals .pak NOT found in $PAKS_MOD_DIR/"
        warn "  → Fix: run  ./install-mods.sh  (or check Step 7 in README)"
    fi

    # ── Summary ───────────────────────────────────────────────────────────────
    echo
    if [[ "$VERIFY_FAILED" == "true" ]]; then
        echo -e "${BOLD}${RED}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║   Verification FAILED — issues found above   ║${NC}"
        echo -e "${BOLD}${RED}╚══════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${BOLD}Stuttering troubleshooting checklist:${NC}"
        echo "  1. Re-run installation:   ./install-mods.sh"
        echo "  2. Confirm Steam Launch Options include all WINEDLLOVERRIDES"
        echo "     (see Step 4 in README for the exact string)"
        echo "  3. Set Anti-Aliasing → DLSS in-game Graphics settings"
        echo "  4. Make sure Engine.ini is read-only after install"
        echo "  5. After any game update, re-run: ./install-mods.sh"
        echo
        exit 1
    else
        echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${GREEN}║   All checks passed!                         ║${NC}"
        echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${BOLD}Mods are correctly installed. If you are still stuttering:${NC}"
        echo "  • Verify Steam Launch Options match what the installer printed"
        echo "    (right-click game → Properties → Launch Options)"
        echo "  • In-game: Graphics → Anti-Aliasing Method must be set to DLSS"
        echo "  • In-game: Background Model Detail → Ultra (avoids billboarding)"
        echo "  • After any game patch, re-run: ./install-mods.sh"
        echo "  • First-run shader compilation causes one-time stutters — play"
        echo "    for 30–60 min and let the shader cache warm up"
        echo
    fi
    exit 0
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
    OPTISCALER_FILES=(
        "amd_fidelityfx_dx12.dll"
        "amd_fidelityfx_upscaler_dx12.dll"
        "amd_fidelityfx_framegeneration_dx12.dll"
        "amd_fidelityfx_vk.dll"
        "OptiScaler.ini"
        "version.dll"
        "dxgi.dll"
        "nvngx_dlss_updated.dll"
        "nvngx.dll"
        "fakenvapi.dll"
        "fakenvapi.ini"
        "dlssg_to_fsr3_amd_is_better.dll"
        "libxell.dll"
        "libxess.dll"
        "libxess_fg.dll"
        "libxess_dx11.dll"
        "remove_optiscaler.sh"
    )
    for f in "${OPTISCALER_FILES[@]}"; do
        remove_file "$BINARIES_DIR/$f"
    done
    rm -rf "$BINARIES_DIR/D3D12_Optiscaler" 2>/dev/null && info "  Removed D3D12_Optiscaler/"

    step "Removing Fantasy Optimizer"
    remove_file "$PAKS_MOD_DIR/ZZFrancisLouisFOVer2_P.pak"

    step "Removing Enhanced Fantasy Visuals"
    remove_file "$PAKS_MOD_DIR/ZFrancisLouis_EFVEpic_P.pak"
    remove_file "$PAKS_MOD_DIR/ZFrancisLouis_EFVFogEpic_P.pak"

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

    OPTI_SRC=$(find "$OPTISCALER_DIR" -maxdepth 1 -type d -name "OptiScaler-v*" | sort -V | tail -1)
    [[ -n "$OPTI_SRC" ]] \
        || die "OptiScaler folder not found in 'FFVII DLSS4-FSR4/'. Check the repo is complete."

    info "Copying OptiScaler files from: $(basename "$OPTI_SRC")"

    if [[ "$GPU" == "nvidia" ]]; then
        # Remove old hook DLL names from previous installs
        rm -f "$BINARIES_DIR/dxgi.dll" "$BINARIES_DIR/nvngx_dlss_updated.dll" "$BINARIES_DIR/nvngx.dll"
        # Copy all files, then rename OptiScaler.dll → version.dll (NVIDIA hook)
        cp -r "$OPTI_SRC/." "$BINARIES_DIR/"
        mv "$BINARIES_DIR/OptiScaler.dll" "$BINARIES_DIR/version.dll"
        success "Installed OptiScaler (DLSS4/NVIDIA)  →  $BINARIES_DIR/"
        OPTISCALER_DLL_OVERRIDE="version.dll=n,b"

    else  # amd
        # AMD requires the large FSR DLLs — check they are present
        MISSING_FSR=false
        for f in amd_fidelityfx_upscaler_dx12.dll amd_fidelityfx_framegeneration_dx12.dll; do
            [[ -f "$OPTI_SRC/$f" ]] || { warn "Missing AMD file: $f"; MISSING_FSR=true; }
        done
        if [[ "$MISSING_FSR" == "true" ]]; then
            die "AMD FSR DLLs are not bundled in the repo (too large for git).
  Download the full OptiScaler release and place the missing DLLs inside:
  $OPTI_SRC/
  Release URL: https://github.com/optiscaler/OptiScaler/releases/latest"
        fi
        rm -f "$BINARIES_DIR/version.dll" "$BINARIES_DIR/nvngx_dlss_updated.dll" "$BINARIES_DIR/nvngx.dll"
        cp -r "$OPTI_SRC/." "$BINARIES_DIR/"
        mv "$BINARIES_DIR/OptiScaler.dll" "$BINARIES_DIR/dxgi.dll"
        success "Installed OptiScaler (FSR4/AMD)  →  $BINARIES_DIR/"
        OPTISCALER_DLL_OVERRIDE="dxgi.dll=n,b"
    fi
fi

# ── Step 4: Fantasy Optimizer ────────────────────────────────────────────────
if [[ "$INSTALL_FANTASY_OPTIMIZER" == "true" ]]; then
    step "Step 4 — Fantasy Optimizer"

    FO_SRC=$(find "$SCRIPT_DIR/Final Optimizer"* -name "*.pak" 2>/dev/null | head -1)
    [[ -n "$FO_SRC" ]] \
        || die "Fantasy Optimizer .pak not found. Make sure the 'Final Optimizer (Ver2)-*' folder is present."

    mkdir -p "$PAKS_MOD_DIR"
    cp "$FO_SRC" "$PAKS_MOD_DIR/$(basename "$FO_SRC")"
    success "Copied $(basename "$FO_SRC")  →  $PAKS_MOD_DIR/"
else
    skip "Fantasy Optimizer (--no-fantasy-optimizer)"
fi

# ── Step 5: Enhanced Fantasy Visuals ─────────────────────────────────────────
if [[ "$INSTALL_ENHANCED_VISUALS" == "true" ]]; then
    if [[ "$EFV_FOG" == "true" ]]; then
        step "Step 5 — Enhanced Fantasy Visuals (Fog Enabled)"
        EFV_SRC=$(find "$SCRIPT_DIR/Enhanced-Fantasy-Visuals" -name "*Fog*" -name "*.pak" 2>/dev/null | head -1)
        [[ -n "$EFV_SRC" ]] \
            || die "Enhanced Fantasy Visuals (Fog) .pak not found inside 'Enhanced-Fantasy-Visuals/'."
    else
        step "Step 5 — Enhanced Fantasy Visuals (Standard)"
        EFV_SRC=$(find "$SCRIPT_DIR/Enhanced-Fantasy-Visuals" -name "*.pak" ! -name "*Fog*" 2>/dev/null | head -1)
        [[ -n "$EFV_SRC" ]] \
            || die "Enhanced Fantasy Visuals .pak not found inside 'Enhanced-Fantasy-Visuals/'."
    fi

    mkdir -p "$PAKS_MOD_DIR"
    # Remove the other variant to avoid conflicts
    rm -f "$PAKS_MOD_DIR/ZFrancisLouis_EFVEpic_P.pak" \
          "$PAKS_MOD_DIR/ZFrancisLouis_EFVFogEpic_P.pak"
    cp "$EFV_SRC" "$PAKS_MOD_DIR/$(basename "$EFV_SRC")"
    success "Copied $(basename "$EFV_SRC")  →  $PAKS_MOD_DIR/"
else
    skip "Enhanced Fantasy Visuals (--no-enhanced-visuals)"
fi

# ── Step 6: Print Steam launch options ───────────────────────────────────────
step "Step 6 — Steam Launch Options"

DLL_OVERRIDES="xinput1_3=n,b"
[[ -n "$OPTISCALER_DLL_OVERRIDE" ]] && DLL_OVERRIDES="${DLL_OVERRIDES};${OPTISCALER_DLL_OVERRIDE}"

if [[ "$GPU" == "nvidia" ]]; then
    ENV_VAR="PROTON_ENABLE_NVAPI=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1"
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
