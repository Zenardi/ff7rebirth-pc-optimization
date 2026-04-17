# FF7 Rebirth PC Optimization — Copilot Instructions

## Repository purpose

This is a documentation and mod-distribution repository for Final Fantasy VII Rebirth PC performance optimization. It bundles three third-party mods together with a guide (`README.md`) that explains how to install them in the correct order.

## Repository layout

| Path | What it contains |
|---|---|
| `README.md` | The main guide — installation order, per-mod instructions, Windows/Linux variants |
| `FF7Rebirth Ultimate Unreal Engine.ini (VRR)-*/Engine.ini` | Optimized `Engine.ini` for monitors with Variable Refresh Rate (G-Sync / FreeSync) |
| `FF7Rebirth Ultimate Unreal Engine.ini (No VRR)-*/Engine.ini` | Same tweaks without VRR-specific flags |
| `FFVIIHook-Rebirth-*/` | Hook DLL (`xinput1_3.dll`) that forces the game to read `[ConsoleVariables]` from `Engine.ini`; also includes a template `Engine.ini` |
| `FFVII DLSS4-FSR4/` | OptiScaler + Intel SDE AVX2 emulator for DLSS4, FSR4, XeSS and old CPUs |

## Key conventions

### Engine.ini structure
- The Ultimate Tweaks `Engine.ini` files use **INI section headers** (e.g. `[/Script/Engine.RendererSettings]`) followed by `key=value` pairs.
- Inline comments use `;` (semicolons). The FFVIIHook template uses `#` (hash). Both are valid in Unreal Engine INI files.
- Many lines include a trailing comment explaining when to delete that line (e.g. VRR-only settings, Film Grain overrides).
- The VRR variant adds `r.VSync=0` and `r.D3D12.UseAllowTearing=1`; the No VRR variant omits those lines. This is the **only** meaningful difference between the two variants.

### Installation dependency order
1. **FFVIIHook must be installed first** — without it the game ignores `[ConsoleVariables]` in `Engine.ini`.
2. **Ultimate Engine Tweaks** depends on FFVIIHook being present and up to date after every official game patch.
3. **DLSS4-FSR4 / AVX2 mod** is independent and installed directly into `End\Binaries\Win64\`.

### Platform-specific notes
- **Windows** config path: `%USERPROFILE%\Documents\My Games\FINAL FANTASY VII REBIRTH\Saved\Config\WindowsNoEditor\`
- **Linux/Steam Deck** config path: `.../steamapps/compatdata/2909400/pfx/drive_c/users/steamuser/Documents/My Games/FINAL FANTASY VII REBIRTH/Saved/Config/WindowsNoEditor/`
- Linux users need `WINEDLLOVERRIDES="xinput1_3=n,b" %command%` for FFVIIHook, and `WINEDLLOVERRIDES="version.dll=n,b"` (DLSS) or `WINEDLLOVERRIDES="dxgi.dll=n,b"` (FSR/XeSS) for OptiScaler.
- After placing `Engine.ini`, set it **Read-Only** on Windows to prevent the game from overwriting it.

### Mod file naming
Directory names include a NexusMods file-ID suffix (e.g. `-3-106-1774290314`). When updating mods, replace the entire versioned directory rather than editing files in place.
