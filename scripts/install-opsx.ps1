#Requires -Version 5.1
<#
.SYNOPSIS
    gentle-ai OPSX — Install Script for Windows
    One command to install the OPSX-enhanced Gentle AI Stack.

.DESCRIPTION
    Clones the repository, builds from source, and syncs.
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

# ============================================================================
# Banner
# ============================================================================

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
        Stop-WithError "Missing required tools: $($missing -join ', '). Please install them and try again."
    }

    # Check Go version
    $goVersionOutput = & go version 2>&1
    if ($goVersionOutput -match "go(\d+)\.(\d+)") {
        $goMajor = [int]$Matches[1]
        $goMinor = [int]$Matches[2]
        if ($goMajor -lt 1 -or ($goMajor -eq 1 -and $goMinor -lt 24)) {
            Stop-WithError "Go 1.24+ required, found go${goMajor}.${goMinor}. Update from https://go.dev/dl/"
        }
    }

    Write-Success "git and Go are available"
}

# ============================================================================
# Clean legacy config
# ============================================================================

function Clear-LegacyConfig {
    Write-Step "Cleaning legacy SDD config (if present)"

    $cleaned = $false

    # OpenCode
    $opencodeCommands = Join-Path $HOME ".config\opencode\commands"
    if (Test-Path $opencodeCommands) {
        $sddFiles = Get-ChildItem -Path $opencodeCommands -Filter "sdd-*.md" -ErrorAction SilentlyContinue
        if ($sddFiles) {
            $sddFiles | Remove-Item -Force
            $cleaned = $true
        }
    }
    $opencodeJson = Join-Path $HOME ".config\opencode\opencode.json"
    if (Test-Path $opencodeJson) {
        Remove-Item $opencodeJson -Force
        $cleaned = $true
    }

    # Claude Code
    $claudeCommands = Join-Path $HOME ".claude\commands"
    if (Test-Path $claudeCommands) {
        $sddFiles = Get-ChildItem -Path $claudeCommands -Filter "sdd-*.md" -ErrorAction SilentlyContinue
        if ($sddFiles) {
            $sddFiles | Remove-Item -Force
            $cleaned = $true
        }
    }

    # Cursor
    $cursorAgents = Join-Path $HOME ".cursor\agents"
    if (Test-Path $cursorAgents) {
        $sddFiles = Get-ChildItem -Path $cursorAgents -Filter "sdd-*.md" -ErrorAction SilentlyContinue
        if ($sddFiles) {
            $sddFiles | Remove-Item -Force
            $cleaned = $true
        }
    }

    if ($cleaned) {
        Write-Success "Legacy SDD config removed"
    } else {
        Write-Success "No legacy config found - clean install"
    }
}

# ============================================================================
# Clone, build, install
# ============================================================================

function Install-FromSource {
    Write-Step "Cloning repository"

    $tmpDir = Join-Path $env:TEMP "gentle-ai-opsx-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        & git clone --depth 1 "https://github.com/$GITHUB_OWNER/$GITHUB_REPO.git" "$tmpDir\repo"
        if ($LASTEXITCODE -ne 0) { Stop-WithError "Failed to clone repository" }
        Write-Success "Repository cloned"

        Write-Step "Building $BINARY_NAME"

        Push-Location "$tmpDir\repo"
        & go build -o "$BINARY_NAME.exe" ./cmd/gentle-ai/
        if ($LASTEXITCODE -ne 0) { Stop-WithError "Build failed" }
        Pop-Location
        Write-Success "Build complete"

        Write-Step "Installing binary"

        $installDir = Join-Path $env:LOCALAPPDATA "gentle-ai\bin"
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        }

        $destPath = Join-Path $installDir "$BINARY_NAME.exe"
        Copy-Item -Path "$tmpDir\repo\$BINARY_NAME.exe" -Destination $destPath -Force
        Write-Success "Installed $BINARY_NAME to $destPath"

        # Add to PATH if needed
        if ($env:PATH -notlike "*$installDir*") {
            Write-Warn "$installDir is not in your PATH"
            Write-Info "Adding to user PATH..."
            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installDir", "User")
            $env:PATH = "$env:PATH;$installDir"
            Write-Success "Added to PATH (restart terminal for permanent effect)"
        }
    } finally {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# Run sync
# ============================================================================

function Invoke-Sync {
    Write-Step "Running $BINARY_NAME sync"

    $cmd = Get-Command $BINARY_NAME -ErrorAction SilentlyContinue
    if ($cmd) {
        & $BINARY_NAME sync
        Write-Success "Sync complete - OPSX workflow is active"
    } else {
        Write-Warn "Binary not in PATH. Run '$BINARY_NAME sync' manually after restarting terminal."
    }
}

# ============================================================================
# Verify
# ============================================================================

function Test-Installation {
    Write-Step "Verifying installation"

    $cmd = Get-Command $BINARY_NAME -ErrorAction SilentlyContinue
    if ($cmd) {
        $versionOutput = & $BINARY_NAME version 2>&1
        Write-Success "$BINARY_NAME is installed: $versionOutput"
    } else {
        Write-Warn "Could not verify. Restart terminal and run: $BINARY_NAME version"
    }
}

# ============================================================================
# Next steps
# ============================================================================

function Show-NextSteps {
    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your agents are now configured with OPSX." -ForegroundColor White
    Write-Host ""
    Write-Host "OPSX Commands:" -ForegroundColor White
    Write-Host "  /opsx:explore  - Think through ideas before committing" -ForegroundColor Cyan
    Write-Host "  /opsx:propose  - Create a change with all artifacts" -ForegroundColor Cyan
    Write-Host "  /opsx:apply    - Implement tasks from the change" -ForegroundColor Cyan
    Write-Host "  /opsx:archive  - Sync specs and close the change" -ForegroundColor Cyan
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
    Clear-LegacyConfig
    Install-FromSource
    Invoke-Sync
    Test-Installation
    Show-NextSteps
}

Main
