[CmdletBinding()]
param(
    [ValidateSet('nvidia', 'amd')]
    [string]$Gpu = 'nvidia',
    [switch]$NoOptiScaler,
    [switch]$NoVrr,
    [switch]$Uninstall,
    [switch]$Verify,
    [string]$GameDir,
    [string]$ConfigDir,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GameName = 'FINAL FANTASY VII REBIRTH'

$script:VerifyFailed = $false

function Write-Status {
    param(
        [string]$Label,
        [ConsoleColor]$Color,
        [string]$Message
    )

    Write-Host ('[{0}] {1}' -f $Label, $Message) -ForegroundColor $Color
}

function Write-Info($Message) { Write-Status 'INFO' 'Cyan' $Message }
function Write-Success($Message) { Write-Status ' OK ' 'Green' $Message }
function Write-Warn($Message) { Write-Status 'WARN' 'Yellow' $Message }
function Write-Skip($Message) { Write-Status 'SKIP' 'Yellow' $Message }

function Write-Fail($Message) {
    $script:VerifyFailed = $true
    Write-Status 'FAIL' 'Red' $Message
}

function Stop-Script($Message) {
    Write-Status 'ERR ' 'Red' $Message
    exit 1
}

function Write-Step($Message) {
    Write-Host ''
    Write-Host ('-- {0} --' -f $Message) -ForegroundColor Cyan
}

function Show-Usage {
    @"
Usage: .\install-mods.ps1 [OPTIONS]

Installs, uninstalls, or verifies FF7 Rebirth performance mods on Windows.
Mods managed: FFVIIHook, Ultimate Engine Tweaks, OptiScaler (DLSS4/FSR4).

Install options:
  -Gpu nvidia|amd      Graphics card type            (default: nvidia)
  -NoOptiScaler        Skip OptiScaler / upscaler installation
  -NoVrr               Use the No-VRR Engine.ini variant
                       (default: VRR / G-Sync / FreeSync enabled)

Other options:
  -Uninstall           Remove all installed mod files
  -Verify              Check that all mods are correctly installed
  -GameDir <path>      Override auto-detected game directory
  -ConfigDir <path>    Override auto-detected config directory
  -Help                Show this help

Examples:
  .\install-mods.ps1
  .\install-mods.ps1 -Gpu amd
  .\install-mods.ps1 -NoVrr
  .\install-mods.ps1 -Gpu amd -NoVrr
  .\install-mods.ps1 -NoOptiScaler
  .\install-mods.ps1 -Verify
  .\install-mods.ps1 -Uninstall
"@
}

function Get-FirstMatch {
    param(
        [string]$BasePath,
        [string]$Filter,
        [switch]$Directory
    )

    $items = Get-ChildItem -Path $BasePath -Filter $Filter -ErrorAction SilentlyContinue
    if ($Directory) {
        $items = $items | Where-Object { $_.PSIsContainer }
    }
    else {
        $items = $items | Where-Object { -not $_.PSIsContainer }
    }

    return $items | Sort-Object FullName | Select-Object -First 1
}

function Get-SteamLibraries {
    $roots = New-Object System.Collections.Generic.List[string]

    $registryCandidates = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )

    foreach ($registryPath in $registryCandidates) {
        try {
            $item = Get-ItemProperty -Path $registryPath -ErrorAction Stop
            foreach ($property in 'SteamPath', 'InstallPath') {
                $value = $item.$property
                if ($value -and (Test-Path (Join-Path $value 'steamapps'))) {
                    $roots.Add((Resolve-Path $value).Path)
                }
            }
        }
        catch {
        }
    }

    foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\Steam",
        "${env:ProgramFiles}\Steam",
        "${env:LOCALAPPDATA}\Steam"
    )) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'steamapps'))) {
            $roots.Add((Resolve-Path $candidate).Path)
        }
    }

    $libraries = New-Object System.Collections.Generic.List[string]
    foreach ($root in ($roots | Select-Object -Unique)) {
        $libraries.Add($root)

        $vdfPath = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path $vdfPath)) {
            continue
        }

        foreach ($line in Get-Content -Path $vdfPath) {
            if ($line -match '"path"\s+"([^"]+)"') {
                $libraryPath = $matches[1] -replace '\\\\', '\'
                if (Test-Path (Join-Path $libraryPath 'steamapps')) {
                    $libraries.Add((Resolve-Path $libraryPath).Path)
                }
            }
        }
    }

    return $libraries | Select-Object -Unique
}

function Get-GamePaths {
    $steamLibraries = Get-SteamLibraries
    if (-not $steamLibraries) {
        Stop-Script 'Steam not found. Make sure Steam is installed and has been run at least once.'
    }

    $resolvedGameDir = $null
    if ($GameDir) {
        $resolvedGameDir = (Resolve-Path $GameDir -ErrorAction Stop).Path
    }
    else {
        foreach ($library in $steamLibraries) {
            $candidate = Join-Path $library ('steamapps\common\{0}' -f $GameName)
            if (Test-Path (Join-Path $candidate 'End\Binaries\Win64')) {
                $resolvedGameDir = $candidate
                break
            }
        }
    }

    if (-not $resolvedGameDir) {
        Stop-Script "'$GameName' not found in any Steam library. Install the game first or pass -GameDir."
    }

    $resolvedConfigDir = if ($ConfigDir) {
        $ConfigDir
    }
    else {
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "My Games\$GameName\Saved\Config\WindowsNoEditor"
    }

    [pscustomobject]@{
        SteamLibraries = $steamLibraries
        GameDir        = $resolvedGameDir
        BinariesDir    = Join-Path $resolvedGameDir 'End\Binaries\Win64'
        ConfigDir      = $resolvedConfigDir
    }
}

function Remove-InstalledFile {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path
        if ($item.Attributes -band [IO.FileAttributes]::ReadOnly) {
            $item.Attributes = $item.Attributes -bxor [IO.FileAttributes]::ReadOnly
        }
        Remove-Item -LiteralPath $Path -Force
        Write-Success "Removed $Path"
    }
    else {
        Write-Skip "Not found (already removed?): $Path"
    }
}

function Expand-ZipFiltered {
    param(
        [string]$ZipPath,
        [string]$Destination,
        [string[]]$ExcludeLeafNames = @()
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $destinationRoot = [IO.Path]::GetFullPath($Destination)

    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.FullName)) {
                continue
            }

            $leafName = Split-Path -Leaf $entry.FullName
            if ($leafName -and $ExcludeLeafNames -contains $leafName) {
                continue
            }

            $targetPath = [IO.Path]::GetFullPath((Join-Path $Destination $entry.FullName))
            if (-not $targetPath.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to extract '$($entry.FullName)' outside '$Destination'."
            }

            if ($entry.FullName.EndsWith('/')) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                continue
            }

            $targetDirectory = Split-Path -Parent $targetPath
            if ($targetDirectory) {
                New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
            }

            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Test-IniContains {
    param(
        [string]$Path,
        [string]$Pattern
    )

    return Select-String -Path $Path -Pattern $Pattern -Quiet -SimpleMatch:$false
}

if ($Help) {
    Show-Usage
    exit 0
}

if ($Uninstall -and $Verify) {
    Stop-Script 'Use either -Uninstall or -Verify, not both.'
}

$modeLabel = if ($Uninstall) { 'Uninstaller' } elseif ($Verify) { 'Verifier' } else { 'Installer' }
$modeColor = if ($Uninstall) { 'Red' } elseif ($Verify) { 'Yellow' } else { 'Cyan' }

Write-Host ''
Write-Host ('FF7 Rebirth - Mod {0} (Windows)' -f $modeLabel) -ForegroundColor $modeColor
Write-Host ''
Write-Info "GPU profile : $Gpu"
Write-Info "OptiScaler  : $(-not $NoOptiScaler)"
Write-Info "VRR mode    : $(-not $NoVrr)"

$paths = Get-GamePaths
Write-Step "Locating Steam and $GameName"
Write-Info ('Libraries    : {0} found' -f @($paths.SteamLibraries).Count)
Write-Success "Game dir     : $($paths.GameDir)"
Write-Success "Binaries dir : $($paths.BinariesDir)"
Write-Success "Config dir   : $($paths.ConfigDir)"

if ($Verify) {
    Write-Step 'Check 1 - FFVIIHook'
    $hookPath = Join-Path $paths.BinariesDir 'xinput1_3.dll'
    if (Test-Path $hookPath) {
        Write-Success "xinput1_3.dll present in $($paths.BinariesDir)"
    }
    else {
        Write-Fail "xinput1_3.dll NOT found in $($paths.BinariesDir)"
        Write-Warn '  -> Without FFVIIHook, Engine.ini console variables are ignored.'
    }

    Write-Step 'Check 2 - Ultimate Engine Tweaks (Engine.ini)'
    $installedIni = Join-Path $paths.ConfigDir 'Engine.ini'
    if (-not (Test-Path $paths.ConfigDir)) {
        Write-Fail 'Config directory not found.'
        Write-Warn '  -> Launch the game once or pass -ConfigDir, then re-run -Verify.'
    }
    elseif (-not (Test-Path $installedIni)) {
        Write-Fail "Engine.ini NOT found in $($paths.ConfigDir)"
        Write-Warn '  -> Re-run .\install-mods.ps1 to copy the optimized Engine.ini.'
    }
    else {
        Write-Success "Engine.ini present in $($paths.ConfigDir)"

        $engineIniItem = Get-Item -LiteralPath $installedIni
        if ($engineIniItem.Attributes -band [IO.FileAttributes]::ReadOnly) {
            Write-Success 'Engine.ini is read-only (protected from game overwrite)'
        }
        else {
            Write-Fail 'Engine.ini is NOT read-only - the game may overwrite it on launch'
        }

        if (Test-IniContains -Path $installedIni -Pattern 'Ultimate Engine Tweaks|P40L0|techoptimized') {
            Write-Success 'Engine.ini signature matches Ultimate Engine Tweaks'
        }
        else {
            Write-Fail 'Engine.ini does not look like the Ultimate Engine Tweaks file'
        }

        if (Test-IniContains -Path $installedIni -Pattern '\[ConsoleVariables\]') {
            Write-Success '[ConsoleVariables] section present'
        }
        else {
            Write-Fail '[ConsoleVariables] section missing from Engine.ini'
        }

        if (Test-IniContains -Path $installedIni -Pattern 'r\.VSync=0') {
            Write-Info 'VRR variant detected (r.VSync=0 found)'
        }
        else {
            Write-Info 'No-VRR variant detected'
        }
    }

    if ($NoOptiScaler) {
        Write-Step 'Check 3 - OptiScaler'
        Write-Skip 'Skipped because -NoOptiScaler was selected.'
    }
    else {
        Write-Step 'Check 3 - OptiScaler (DLSS4 / FSR4)'
        $variantDll = if ($Gpu -eq 'nvidia') { 'version.dll' } else { 'dxgi.dll' }
        $variantLabel = if ($Gpu -eq 'nvidia') { 'version.dll (DLSS4/NVIDIA)' } else { 'dxgi.dll (FSR4/AMD)' }
        $commonDll = Join-Path $paths.BinariesDir 'amd_fidelityfx_dx12.dll'
        $variantPath = Join-Path $paths.BinariesDir $variantDll
        $optiScalerIni = Join-Path $paths.BinariesDir 'OptiScaler.ini'

        if (Test-Path $variantPath) {
            Write-Success "$variantLabel present"
        }
        else {
            Write-Fail "$variantLabel NOT found"
        }

        if (Test-Path $commonDll) {
            Write-Success 'amd_fidelityfx_dx12.dll present'
        }
        else {
            Write-Fail 'amd_fidelityfx_dx12.dll NOT found'
        }

        if (Test-Path $optiScalerIni) {
            Write-Success 'OptiScaler.ini present'
        }
        else {
            Write-Fail 'OptiScaler.ini NOT found'
        }
    }

    Write-Host ''
    if ($script:VerifyFailed) {
        Write-Host 'Verification FAILED - issues found above' -ForegroundColor Red
        exit 1
    }

    Write-Host 'All checks passed.' -ForegroundColor Green
    Write-Host 'No Steam launch options are required on Windows.' -ForegroundColor Green
    exit 0
}

if ($Uninstall) {
    Write-Step 'Removing FFVIIHook'
    Remove-InstalledFile -Path (Join-Path $paths.BinariesDir 'xinput1_3.dll')

    Write-Step 'Removing Ultimate Engine Tweaks (Engine.ini)'
    if (Test-Path $paths.ConfigDir) {
        Remove-InstalledFile -Path (Join-Path $paths.ConfigDir 'Engine.ini')
    }
    else {
        Write-Warn 'Config directory not found - skipping Engine.ini removal.'
    }

    Write-Step 'Removing OptiScaler files'
    foreach ($fileName in @(
        'amd_fidelityfx_dx12.dll',
        'OptiScaler.ini',
        'version.dll',
        'nvngx_dlss_updated.dll',
        'dxgi.dll',
        'nvngx.dll',
        'libxess.dll'
    )) {
        Remove-InstalledFile -Path (Join-Path $paths.BinariesDir $fileName)
    }

    Write-Host ''
    Write-Host 'Uninstall complete.' -ForegroundColor Green
    exit 0
}

Write-Step 'Step 1 - FFVIIHook'
$hookDir = Get-FirstMatch -BasePath $ScriptDir -Filter 'FFVIIHook-Rebirth-*' -Directory
if (-not $hookDir) {
    Stop-Script 'FFVIIHook-Rebirth-* folder not found.'
}

$hookSource = Join-Path $hookDir.FullName 'End\Binaries\Win64\xinput1_3.dll'
if (-not (Test-Path $hookSource)) {
    Stop-Script 'xinput1_3.dll not found. Make sure the FFVIIHook-Rebirth-* folder is present.'
}

Copy-Item -LiteralPath $hookSource -Destination (Join-Path $paths.BinariesDir 'xinput1_3.dll') -Force
Write-Success "Copied xinput1_3.dll -> $($paths.BinariesDir)"

Write-Step 'Step 2 - Ultimate Engine Tweaks (Engine.ini)'
$iniFolderFilter = if ($NoVrr) { 'FF7Rebirth Ultimate Unreal Engine.ini (No VRR)-*' } else { 'FF7Rebirth Ultimate Unreal Engine.ini (VRR)-*' }
$iniLabel = if ($NoVrr) { 'No VRR' } else { 'VRR' }
$iniDir = Get-FirstMatch -BasePath $ScriptDir -Filter $iniFolderFilter -Directory
if (-not $iniDir) {
    Stop-Script "Engine.ini ($iniLabel variant) not found in repo."
}

$iniSource = Join-Path $iniDir.FullName 'Engine.ini'
if (-not (Test-Path $iniSource)) {
    Stop-Script "Engine.ini ($iniLabel variant) not found in repo."
}

New-Item -ItemType Directory -Path $paths.ConfigDir -Force | Out-Null
$installedIni = Join-Path $paths.ConfigDir 'Engine.ini'
if (Test-Path $installedIni) {
    $existingIni = Get-Item -LiteralPath $installedIni
    if ($existingIni.Attributes -band [IO.FileAttributes]::ReadOnly) {
        $existingIni.Attributes = $existingIni.Attributes -bxor [IO.FileAttributes]::ReadOnly
    }
}

Copy-Item -LiteralPath $iniSource -Destination $installedIni -Force
$newIni = Get-Item -LiteralPath $installedIni
$newIni.Attributes = $newIni.Attributes -bor [IO.FileAttributes]::ReadOnly
Write-Success "Copied Engine.ini ($iniLabel) -> $($paths.ConfigDir)"
Write-Success 'Set Engine.ini read-only'

if (-not $NoOptiScaler) {
    Write-Step ("Step 3 - OptiScaler ({0})" -f ($(if ($Gpu -eq 'nvidia') { 'DLSS4' } else { 'FSR4' })))
    $optiScalerDir = Join-Path $ScriptDir 'FFVII DLSS4-FSR4'
    if (-not (Test-Path $optiScalerDir)) {
        Stop-Script "Missing '$optiScalerDir'."
    }

    $zipFilter = if ($Gpu -eq 'nvidia') { '*DLSS*Mod*.zip' } else { '*FSR*Mod*.zip' }
    $zipFile = Get-FirstMatch -BasePath $optiScalerDir -Filter $zipFilter
    if (-not $zipFile) {
        Stop-Script "$Gpu mod zip not found in 'FFVII DLSS4-FSR4'. Check the repo is complete."
    }

    Write-Info "Extracting: $($zipFile.Name)"
    Expand-ZipFiltered -ZipPath $zipFile.FullName -Destination $paths.BinariesDir -ExcludeLeafNames @('Readme.txt')
    Write-Success "Extracted $($(if ($Gpu -eq 'nvidia') { 'DLSS4' } else { 'FSR4' })) files -> $($paths.BinariesDir)"
}
else {
    Write-Step 'Step 3 - OptiScaler'
    Write-Skip 'Skipped because -NoOptiScaler was selected.'
}

Write-Host ''
Write-Host 'Installation complete.' -ForegroundColor Green
Write-Host 'Windows does not require the Linux Steam Launch Options from the README.' -ForegroundColor Green
Write-Host 'Next steps: launch the game, set Anti-Aliasing Method to DLSS, and keep Background Model Detail on Ultra.' -ForegroundColor Green
