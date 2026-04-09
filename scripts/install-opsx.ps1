#Requires -Version 5.1
<#
.SYNOPSIS
    gentle-ai OPSX — Install Script for Windows
    Compiles the OPSX fork and syncs it, creating the full config from scratch.

.DESCRIPTION
    Clones the OPSX fork, builds from source, and runs sync with self-update
    disabled so the official binary doesn't overwrite OPSX changes.
    Requires Go 1.24+ and git.

.EXAMPLE
    irm https://raw.githubusercontent.com/JuanCruzRobledo/Gentle-Ai-Stack-SDD-OPSX/main/scripts/install-opsx.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$GITHUB_OWNER = "JuanCruzRobledo"
$GITHUB_REPO = "Gentle-Ai-Stack-SDD-OPSX"
$BINARY_NAME = "gentle-ai"

# ============================================================================
# Logging helpers
# ============================================================================

function Write-Info    { param([string]$Message) Write-Host "[info]    $Message" -ForegroundColor Blue }
function Write-Success { param([string]$Message) Write-Host "[ok]      $Message" -ForegroundColor Green }
function Write-Warn    { param([string]$Message) Write-Host "[warn]    $Message" -ForegroundColor Yellow }
function Write-Err     { param([string]$Message) Write-Host "[error]   $Message" -ForegroundColor Red }
function Write-Step    { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }

function Stop-WithError {
    param([string]$Message)
    Write-Err $Message
    exit 1
}

function Show-Banner {
    Write-Host ""
    Write-Host "   ____            _   _              _    ___ " -ForegroundColor Cyan
    Write-Host "  / ___| ___ _ __ | |_| | ___        / \  |_ _|" -ForegroundColor Cyan
    Write-Host " | |  _ / _ \ '_ \| __| |/ _ \_____ / _ \  | | " -ForegroundColor Cyan
    Write-Host " | |_| |  __/ | | | |_| |  __/_____/ ___ \ | | " -ForegroundColor Cyan
    Write-Host "  \____|\___|_| |_|\__|_|\___|    /_/   \_\___|" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  OPSX Edition - Fluid workflow powered by OpenSpec CLI" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
# Prerequisites
# ============================================================================

function Test-Prerequisites {
    Write-Step "Checking prerequisites"

    $missing = @()
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) { $missing += "git" }
    if (-not (Get-Command "go" -ErrorAction SilentlyContinue))  { $missing += "go (https://go.dev/dl/)" }

    if ($missing.Count -gt 0) {
        Stop-WithError "Missing required tools: $($missing -join ', ')"
    }

    $goVersionOutput = & go version 2>&1
    if ($goVersionOutput -match "go(\d+)\.(\d+)") {
        $goMajor = [int]$Matches[1]
        $goMinor = [int]$Matches[2]
        if ($goMajor -lt 1 -or ($goMajor -eq 1 -and $goMinor -lt 24)) {
            Stop-WithError "Go 1.24+ required, found go${goMajor}.${goMinor}. Update from https://go.dev/dl/"
        }
    }

    Write-Success "git and Go available"
}

# ============================================================================
# Clone, build, install
# ============================================================================

function Install-FromSource {
    Write-Step "Cloning OPSX fork"

    $script:TmpDir = Join-Path $env:TEMP "gentle-ai-opsx-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TmpDir -Force | Out-Null

    & git clone --depth 1 "https://github.com/$GITHUB_OWNER/$GITHUB_REPO.git" "$script:TmpDir\repo" 2>&1 | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { Stop-WithError "Failed to clone repository" }
    Write-Success "Cloned"

    Write-Step "Building $BINARY_NAME"

    Push-Location "$script:TmpDir\repo"
    & go build -o "$BINARY_NAME.exe" ./cmd/gentle-ai/
    if ($LASTEXITCODE -ne 0) { Stop-WithError "Build failed" }
    Pop-Location
    Write-Success "Built"

    Write-Step "Installing binary"

    $installDir = Join-Path $env:LOCALAPPDATA "gentle-ai\bin"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    $destPath = Join-Path $installDir "$BINARY_NAME.exe"
    Copy-Item -Path "$script:TmpDir\repo\$BINARY_NAME.exe" -Destination $destPath -Force
    Write-Success "Installed to $destPath"

    if ($env:PATH -notlike "*$installDir*") {
        Write-Info "Adding to user PATH..."
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notlike "*$installDir*") {
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installDir", "User")
        }
        $env:PATH = "$env:PATH;$installDir"
        Write-Success "Added to PATH"
    }
}

# ============================================================================
# Sync (with self-update DISABLED)
# ============================================================================

function Clear-LegacyConfig {
    Write-Step "Cleaning previous config (so sync creates fresh OPSX)"

    $cleaned = $false

    # OpenCode: remove opencode.json entirely (sync recreates it with OPSX)
    $ocJson = Join-Path $HOME ".config\opencode\opencode.json"
    if (Test-Path $ocJson) {
        Remove-Item $ocJson -Force
        $cleaned = $true
    }

    # OpenCode: remove old sdd-* commands
    $ocCmds = Join-Path $HOME ".config\opencode\commands"
    if (Test-Path $ocCmds) {
        $sddFiles = Get-ChildItem -Path $ocCmds -Filter "sdd-*.md" -ErrorAction SilentlyContinue
        if ($sddFiles) { $sddFiles | Remove-Item -Force; $cleaned = $true }
    }

    # Claude Code: remove sdd-orchestrator section marker so sync injects fresh
    $claudeMd = Join-Path $HOME ".claude\CLAUDE.md"
    if (Test-Path $claudeMd) {
        $content = Get-Content -Path $claudeMd -Raw
        $openMarker = "<!-- gentle-ai:sdd-orchestrator -->"
        $closeMarker = "<!-- /gentle-ai:sdd-orchestrator -->"
        if ($content -match [regex]::Escape($openMarker)) {
            $pattern = "(?s)$([regex]::Escape($openMarker)).*?$([regex]::Escape($closeMarker))\r?\n?"
            $content = [regex]::Replace($content, $pattern, "")
            Set-Content -Path $claudeMd -Value $content -NoNewline
            $cleaned = $true
        }
    }

    # Cursor: remove old sdd-* agent files
    $cursorAgents = Join-Path $HOME ".cursor\agents"
    if (Test-Path $cursorAgents) {
        $sddFiles = Get-ChildItem -Path $cursorAgents -Filter "sdd-*.md" -ErrorAction SilentlyContinue
        if ($sddFiles) { $sddFiles | Remove-Item -Force; $cleaned = $true }
    }

    if ($cleaned) {
        Write-Success "Previous config cleaned"
    } else {
        Write-Success "No previous config found - clean install"
    }
}

function Invoke-Sync {
    Write-Step "Running OPSX binary sync (self-update disabled)"

    # CRITICAL: Disable self-update so our OPSX binary doesn't get replaced
    # by the official release from Gentleman-Programming/gentle-ai
    $env:GENTLE_AI_NO_SELF_UPDATE = "1"

    # Use the EXACT path of our installed binary, NOT whatever is in PATH
    # (the official binary may be in ~/go/bin/ and take priority)
    $opsxBinary = Join-Path $env:LOCALAPPDATA "gentle-ai\bin\$BINARY_NAME.exe"

    if (Test-Path $opsxBinary) {
        Write-Info "Using: $opsxBinary"
        & $opsxBinary sync
        Write-Success "Sync complete - OPSX config created"
    } else {
        Stop-WithError "OPSX binary not found at $opsxBinary"
    }

    # Clean up env var
    Remove-Item Env:\GENTLE_AI_NO_SELF_UPDATE -ErrorAction SilentlyContinue
}

# ============================================================================
# Summary
# ============================================================================

function Show-Summary {
    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your agents are configured with OPSX." -ForegroundColor White
    Write-Host ""
    Write-Host "OPSX Commands:" -ForegroundColor White
    Write-Host "  /opsx:explore  - Think through ideas before committing" -ForegroundColor Cyan
    Write-Host "  /opsx:propose  - Create a change with all artifacts" -ForegroundColor Cyan
    Write-Host "  /opsx:apply    - Implement tasks from the change" -ForegroundColor Cyan
    Write-Host "  /opsx:archive  - Sync specs and close the change" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IMPORTANT: If you run 'gentle-ai sync' in the future, always use:" -ForegroundColor Yellow
    Write-Host '  $env:GENTLE_AI_NO_SELF_UPDATE = "1"; gentle-ai sync' -ForegroundColor DarkGray
    Write-Host "  Otherwise the official binary will overwrite OPSX." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Docs: https://github.com/$GITHUB_OWNER/$GITHUB_REPO" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
# Main
# ============================================================================

function Main {
    Show-Banner
    Test-Prerequisites
    Install-FromSource
    Clear-LegacyConfig
    Invoke-Sync
    Show-Summary

    # Cleanup
    if ($script:TmpDir -and (Test-Path $script:TmpDir)) {
        Remove-Item -Path $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Main
