# Final Fantasy 7 Rebirth: Ultimate Performance and Stutter Reduction Guide (Linux / Ubuntu)

![image](./image.png)

- [Final Fantasy 7 Rebirth: Ultimate Performance and Stutter Reduction Guide (Linux / Ubuntu)](#final-fantasy-7-rebirth-ultimate-performance-and-stutter-reduction-guide-linux--ubuntu)
  - [Automated Install Script](#automated-install-script)
    - [Quick start (NVIDIA + DLSS4 + VRR)](#quick-start-nvidia--dlss4--vrr)
    - [Options](#options)
    - [Examples](#examples)
    - [What the script does](#what-the-script-does)
  - [Before you start](#before-you-start)
  - [Step 1 — Install FFVIIHook](#step-1--install-ffviihook)
  - [Step 2 — Install Ultimate Engine Tweaks](#step-2--install-ultimate-engine-tweaks)
  - [Step 3 — Install DLSS4 / FSR4 / XeSS (OptiScaler)](#step-3--install-dlss4--fsr4--xess-optiscaler)
  - [Step 4 — Set Steam Launch Options](#step-4--set-steam-launch-options)
    - [Install GameMode](#install-gamemode)
    - [Fix CPU governor on laptops](#fix-cpu-governor-on-laptops)
    - [Set the options in Steam](#set-the-options-in-steam)
  - [Step 5 — In-game settings](#step-5--in-game-settings)
  - [Optional — AVX2 Emulation for old CPUs](#optional--avx2-emulation-for-old-cpus)
  - [Uninstall](#uninstall)

---

## Automated Install Script

`install-mods.sh` automates all three mod installations on Linux/Steam Deck. `install-mods.ps1` does the same on Windows, auto-detecting your Steam library, copying the required files, and extracting the selected OptiScaler preset.

### Quick start (NVIDIA + DLSS4 + VRR)

```bash
chmod +x install-mods.sh
./install-mods.sh
```

Then paste the printed Launch Options into Steam → right-click game → **Properties → Launch Options**.

### Quick start on Windows (PowerShell)

```powershell
.\install-mods.ps1
```

The PowerShell installer uses your Windows config folder automatically:

```text
%USERPROFILE%\Documents\My Games\FINAL FANTASY VII REBIRTH\Saved\Config\WindowsNoEditor\
```

Unlike Linux, Windows does **not** need the Steam Launch Options from Step 4.

### Options

| Flag | Description | Default |
|---|---|---|
| `--gpu nvidia` | Use DLSS4 (NVIDIA) | ✅ default |
| `--gpu amd` | Use FSR4 (AMD / other GPU) | |
| `--no-vrr` | Use No-VRR Engine.ini variant | VRR enabled |
| `--no-optiscaler` | Skip OptiScaler / upscaler install | OptiScaler installed |
| `--verify` | Check all mods are correctly applied | |
| `--uninstall` | Remove all mod files | |

PowerShell equivalents:

| PowerShell switch | Description |
|---|---|
| `-Gpu nvidia` / `-Gpu amd` | Select DLSS4 or FSR4 preset |
| `-NoVrr` | Use the No-VRR Engine.ini variant |
| `-NoOptiScaler` | Skip OptiScaler |
| `-Verify` | Check installed files |
| `-Uninstall` | Remove installed files |

### Examples

```bash
# NVIDIA with DLSS4 and VRR (recommended for most users)
./install-mods.sh

# AMD GPU with FSR4 and VRR
./install-mods.sh --gpu amd

# NVIDIA, no VRR (standard monitor without G-Sync/FreeSync)
./install-mods.sh --no-vrr

# AMD, no VRR
./install-mods.sh --gpu amd --no-vrr

# Only FFVIIHook + Engine tweaks, skip OptiScaler
./install-mods.sh --no-optiscaler

# Verify all mods are correctly installed (run this if you experience stuttering)
./install-mods.sh --verify

# Remove all installed mod files
./install-mods.sh --uninstall
```

```powershell
# NVIDIA with DLSS4 and VRR (recommended for most users)
.\install-mods.ps1

# AMD GPU with FSR4 and VRR
.\install-mods.ps1 -Gpu amd

# NVIDIA, no VRR
.\install-mods.ps1 -NoVrr

# Only FFVIIHook + Engine tweaks, skip OptiScaler
.\install-mods.ps1 -NoOptiScaler

# Verify all mods are correctly installed
.\install-mods.ps1 -Verify

# Remove all installed mod files
.\install-mods.ps1 -Uninstall
```

### What the script does

1. **Auto-detects** your Steam root and parses `libraryfolders.vdf` to find all library paths
2. **Locates** the FF7 Rebirth `End/Binaries/Win64` folder and the correct config dir (`Documents\My Games\...` on Windows, Wine prefix on Linux)
3. **Installs FFVIIHook** — copies `xinput1_3.dll` to the game binaries folder
4. **Installs Engine.ini** — copies the VRR or No-VRR variant and sets it read-only
5. **Installs OptiScaler** — extracts the DLSS4 (NVIDIA) or FSR4 (AMD) zip into the game binaries folder
6. **Prints the Steam Launch Options** on Linux; Windows does not need them

> [!NOTE]
> After the script finishes, set **Anti-Aliasing Method → DLSS** in-game (Step 5). On Linux, you must still manually paste the printed Launch Options into Steam.

---

## Before you start

> [!WARNING] 
> `FFVII XeSS Mod v1.3.1-15-1-3-1-1742123804.zip`  File too large to be tracked by Git (need to use Git LFS). Download directly from NexusMods page and put under FFVII DLSS4-FSR4 (zipped) so installation script works.

**Launch the game at least once and close it.** This creates the config folder you will need in Step 2.

Locate your two key paths and keep them handy — you will use them throughout this guide:

```
# Game binaries folder (drop DLLs here)
/path/to/SteamLibrary/steamapps/common/FINAL FANTASY VII REBIRTH/End/Binaries/Win64/

# Engine config folder (drop Engine.ini here)
/path/to/SteamLibrary/steamapps/compatdata/2909400/pfx/drive_c/users/steamuser/Documents/My Games/FINAL FANTASY VII REBIRTH/Saved/Config/WindowsNoEditor/
```

> Replace `/path/to/SteamLibrary` with your actual Steam library location (e.g. `~/.steam/steam` or `/media/you/disk/SteamLibrary`).

**Install order matters:** FFVIIHook (Step 1) must be installed before Engine Tweaks (Step 2) will have any effect.

---

## Step 1 — Install FFVIIHook

[NexusMods page](https://www.nexusmods.com/finalfantasy7rebirth/mods/4)

FFVIIHook patches the game so that `[ConsoleVariables]` settings in `Engine.ini` always take priority. Without it, the Engine Tweaks in Step 2 do nothing.

1. Copy `xinput1_3.dll` from `FFVIIHook-Rebirth-*/End/Binaries/Win64/` into your game's `End/Binaries/Win64/` folder.

> **Gamepad issues?** If the controller stops working, rename `xinput1_3.dll` to `dxgi.dll`, `winmm.dll`, `d3d9.dll`, or `d3d11.dll` — then update the `WINEDLLOVERRIDES` in Step 4 to match the new name.

> **After every official game patch**, check that the DLL is still present. Steam may remove it during updates.

---

## Step 2 — Install Ultimate Engine Tweaks

[NexusMods page](https://www.nexusmods.com/finalfantasy7rebirth/mods/3)

> Definitive optimized Engine.ini built over 1+ year across 40+ UE games. Removes most stuttering, improves performance, reduces input latency, and improves picture clarity — without visual loss or crashes.

**Choose your variant first:**

| My display supports VRR (G-Sync / FreeSync)? | Use this folder |
|---|---|
| Yes — enabled in both GPU driver **and** display settings | `FF7Rebirth Ultimate Unreal Engine.ini (VRR)-*/` |
| No, or unsure | `FF7Rebirth Ultimate Unreal Engine.ini (No VRR)-*/` |

**Install:**

1. Copy `Engine.ini` from your chosen variant folder into:
   ```
   /path/to/SteamLibrary/steamapps/compatdata/2909400/pfx/drive_c/users/steamuser/Documents/My Games/FINAL FANTASY VII REBIRTH/Saved/Config/WindowsNoEditor/
   ```
2. Make it read-only so the game cannot overwrite it:
   ```bash
   chmod 444 "/path/to/.../WindowsNoEditor/Engine.ini"
   ```

> [!WARNING]
> Do **not** use this alongside any other "optimization" mod. It is already comprehensive.

---

## Step 3 — Install DLSS4 / FSR4 / XeSS (OptiScaler)

[NexusMods page](https://www.nexusmods.com/finalfantasy7rebirth/mods/15)

OptiScaler (by cdozdil) adds DLSS4 (transformer model), FSR 3.1/4.0, and XeSS 2.0 upscalers plus frame generation support.

**Choose your upscaler:**

| GPU | Recommended preset | DLL used |
|---|---|---|
| NVIDIA (RTX) | DLSS variant | `version.dll` |
| AMD / other | FSR3/XeSS variant | `dxgi.dll` |

**Install:**

1. Copy all files from `FFVII DLSS4-FSR4/` (the upscaler preset you chose) into your game's `End/Binaries/Win64/` folder.

**Notes:**
- Steam/Epic overlay is disabled by default. Re-enable it by setting `DisableOverlays=false` in `OptiScaler.ini`.
- Adjust **Dynamic Resolution Scaling (minimum)** in Graphics settings to control resolution quality — there is no standard preset selector.
- Frame generation is partially supported. Enable it in-game with `Insert` → check Frame Generation. (Known issue: causes HUD glitching.)

---

## Step 4 — Set Steam Launch Options

### Install GameMode

`gamemoderun` tells the Linux kernel to prioritise the game process (CPU governor, scheduler, I/O) for a free performance boost.

```bash
sudo apt install gamemode
```

Verify it is working after launching the game:
```bash
gamemoded -s   # should report "gamemode is active"
```

### Fix CPU governor on laptops

On laptops the CPU often stays in `powersave` mode, which throttles clock speeds and causes stuttering even when GameMode is running. If you experience stuttering on a laptop, set the governor to `performance` before launching the game:

```bash
sudo apt install cpufrequtils
sudo cpufreq-set -g performance
```

To restore it afterwards:
```bash
sudo cpufreq-set -g powersave
```

> **Tip:** GameMode should do this automatically while the game runs. If `gamemoded -s` confirms GameMode is active but you still stutter, the governor change above is the fix.
> Run `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` to check your current governor.

### Set the options in Steam

All three mods require Wine DLL overrides to load on Linux. Combine everything into a **single** Launch Options string.

In Steam: right-click the game → **Properties** → **Launch Options**, and paste one of the following:

**DLSS4 variant (NVIDIA — recommended):**
```
WINEDLLOVERRIDES="xinput1_3=n,b;version.dll=n,b" PROTON_ENABLE_NVAPI=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1 gamemoderun %command% -nodirectstorage
```

**FSR4 variant (AMD or other GPU):**
```
WINEDLLOVERRIDES="xinput1_3=n,b;dxgi.dll=n,b" RADV_PERFTEST=nggc gamemoderun %command% -nodirectstorage
```

> If you renamed `xinput1_3.dll` in Step 1 (e.g. to `dxgi.dll`), update the first override entry to match.

---

## Step 5 — In-game settings

1. Go to **Graphics → Anti-Aliasing Method** and set it to **DLSS**.
   OptiScaler spoofs your GPU to unlock this option, then transparently redirects it to FSR4 or XeSS depending on which variant you installed.
2. Set **Background Model Detail** to **Ultra**.
   Any lower setting causes aggressive billboarding (3D objects turning into flat 2D sprites just a few meters from Cloud). It is VRAM-heavy but eliminates a very noticeable visual artefact.
3. Adjust **Dynamic Resolution Scaling (minimum)** to balance resolution vs. performance.

---

## Optional — AVX2 Emulation for old CPUs

> Only needed if your CPU does **not** support AVX2 (typically pre-2013 Intel CPUs). Skip this if you have a modern CPU.

The game refuses to launch without AVX2. This mod uses Intel SDE to emulate the missing instruction at a significant performance cost (~15–40 FPS on an overclocked i7-2700k/3770k). Frame generation is strongly recommended to compensate.

**Install:**

1. Copy the `SDE/` folder and `FFVII-SDE-Launcher.bat` from `FFVII DLSS4-FSR4/FFVII AVX2 Mod v1.2-*/` into your `End/Binaries/Win64/` folder.
2. Launch the game via `FFVII-SDE-Launcher.bat` instead of the normal executable.

**Known issues:**
- First boot can take 5–15 minutes.
- Stutters when loading new scenes, areas, or effects for the first time.
- Set **Characters Displayed** to `0` in Graphics settings when in cities.
- No sound after initial shader cache build → restart the game.
- Install the game on your fastest SSD (it uses DirectStorage).

**Uninstall:** Delete the `SDE/` folder and `FFVII-SDE-Launcher.bat`.

---

## Uninstall

| Mod | What to delete |
|---|---|
| FFVIIHook | `xinput1_3.dll` (or whichever name you used) from `End/Binaries/Win64/` |
| Ultimate Engine Tweaks | `Engine.ini` from the `WindowsNoEditor/` config folder |
| OptiScaler (DLSS) | `amd_fidelityfx_dx12.dll`, `version.dll`, `nvngx_dlss_updated.dll`, `OptiScaler.ini` from `End/Binaries/Win64/` |
| OptiScaler (FSR3/XeSS) | `amd_fidelityfx_dx12.dll`, `dxgi.dll`, `nvngx.dll`, `OptiScaler.ini` from `End/Binaries/Win64/` |
| AVX2 Emulation | `SDE/` folder and `FFVII-SDE-Launcher.bat` from `End/Binaries/Win64/` |

Also remove the `WINEDLLOVERRIDES` line from your Steam Launch Options.
