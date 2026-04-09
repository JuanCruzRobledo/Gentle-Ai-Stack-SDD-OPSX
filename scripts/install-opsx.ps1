#Requires -Version 5.1
<#
.SYNOPSIS
    gentle-ai OPSX — Patch Script for Windows
    Applies OPSX workflow on top of an existing gentle-ai installation.

.DESCRIPTION
    Clones the OPSX fork and patches skills, orchestrators, and commands.
    Requires git. NO Go required.
    Pre-requisite: gentle-ai must be already installed and synced.

.EXAMPLE
    irm https://raw.githubusercontent.com/JuanCruzRobledo/Gentle-Ai-Stack-SDD-OPSX/main/scripts/install-opsx.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$GITHUB_OWNER = "JuanCruzRobledo"
$GITHUB_REPO = "Gentle-Ai-Stack-SDD-OPSX"

$SKILLS = @("sdd-init", "sdd-apply", "sdd-verify", "sdd-explore", "sdd-propose",
            "sdd-spec", "sdd-design", "sdd-tasks", "sdd-archive", "sdd-onboard")

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
    Write-Host "  OPSX Patch - Fluid workflow powered by OpenSpec CLI" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
# Prerequisites
# ============================================================================

function Test-Prerequisites {
    Write-Step "Checking prerequisites"

    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Stop-WithError "git is required. Install it and try again."
    }

    $found = $false
    $dirs = @(
        (Join-Path $HOME ".claude"),
        (Join-Path $HOME ".config\opencode"),
        (Join-Path $HOME ".cursor"),
        (Join-Path $HOME ".gemini"),
        (Join-Path $HOME ".codex"),
        (Join-Path $HOME ".codeium\windsurf")
    )
    foreach ($dir in $dirs) {
        if (Test-Path $dir) { $found = $true; break }
    }

    if (-not $found) {
        Stop-WithError "No AI agent configuration found. Install gentle-ai first: https://github.com/Gentleman-Programming/gentle-ai"
    }

    Write-Success "Prerequisites OK"
}

# ============================================================================
# Clone fork
# ============================================================================

function Get-ForkAssets {
    Write-Step "Downloading OPSX patch files"

    $script:TmpDir = Join-Path $env:TEMP "gentle-ai-opsx-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TmpDir -Force | Out-Null

    & git clone --depth 1 "https://github.com/$GITHUB_OWNER/$GITHUB_REPO.git" "$script:TmpDir\repo" 2>&1 | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { Stop-WithError "Failed to clone repository" }

    $script:Assets = Join-Path $script:TmpDir "repo\internal\assets"
    Write-Success "Downloaded"
}

# ============================================================================
# Clean legacy
# ============================================================================

function Clear-LegacyCommands {
    Write-Step "Cleaning legacy SDD commands"

    $cleaned = $false

    # OpenCode commands
    $ocCmds = Join-Path $HOME ".config\opencode\commands"
    if (Test-Path $ocCmds) {
        $sddFiles = Get-ChildItem -Path $ocCmds -Filter "sdd-*.md" -ErrorAction SilentlyContinue
        if ($sddFiles) {
            $sddFiles | Remove-Item -Force
            $cleaned = $true
        }
    }

    # OpenCode JSON
    $ocJson = Join-Path $HOME ".config\opencode\opencode.json"
    if (Test-Path $ocJson) {
        Remove-Item $ocJson -Force
        $cleaned = $true
    }

    if ($cleaned) {
        Write-Success "Legacy commands removed"
    } else {
        Write-Success "No legacy commands found"
    }
}

# ============================================================================
# Patch skills
# ============================================================================

function Update-Skills {
    Write-Step "Patching skills to OPSX"

    $skillDirs = @(
        (Join-Path $HOME ".claude\skills"),
        (Join-Path $HOME ".config\opencode\skills"),
        (Join-Path $HOME ".cursor\skills"),
        (Join-Path $HOME ".gemini\skills"),
        (Join-Path $HOME ".codex\skills"),
        (Join-Path $HOME ".codeium\windsurf\skills"),
        (Join-Path $HOME ".gemini\antigravity\skills")
    )

    $patched = 0

    foreach ($skillDir in $skillDirs) {
        if (-not (Test-Path $skillDir)) { continue }

        foreach ($skill in $SKILLS) {
            $target = Join-Path $skillDir "$skill\SKILL.md"
            $source = Join-Path $script:Assets "skills\$skill\SKILL.md"

            if ((Test-Path $target) -and (Test-Path $source)) {
                Copy-Item -Path $source -Destination $target -Force
                $patched++
            }
        }
    }

    Write-Success "Patched $patched skill files"
}

# ============================================================================
# Patch orchestrator via markdown section replacement
# ============================================================================

function Update-MarkdownSection {
    param(
        [string]$FilePath,
        [string]$NewContent,
        [string]$AgentName
    )

    $openMarker = "<!-- gentle-ai:sdd-orchestrator -->"
    $closeMarker = "<!-- /gentle-ai:sdd-orchestrator -->"

    if (-not (Test-Path $FilePath)) { return }

    $fileContent = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $fileContent) { return }

    if ($fileContent.Contains($openMarker)) {
        # Replace content between markers
        $pattern = "(?s)$([regex]::Escape($openMarker)).*?$([regex]::Escape($closeMarker))"
        $replacement = "$openMarker`n$NewContent`n$closeMarker"
        $updated = [regex]::Replace($fileContent, $pattern, $replacement)
        Set-Content -Path $FilePath -Value $updated -NoNewline
        Write-Info "  ${AgentName}: orchestrator replaced"
    } else {
        # Append new section
        $section = "`n$openMarker`n$NewContent`n$closeMarker`n"
        Add-Content -Path $FilePath -Value $section
        Write-Info "  ${AgentName}: orchestrator appended"
    }
}

# ============================================================================
# Patch all agents
# ============================================================================

function Update-Orchestrators {
    Write-Step "Patching agent orchestrators"

    # Claude Code (markdown sections)
    $claudeMd = Join-Path $HOME ".claude\CLAUDE.md"
    $claudeContent = Get-Content -Path (Join-Path $script:Assets "claude\sdd-orchestrator.md") -Raw
    Update-MarkdownSection -FilePath $claudeMd -NewContent $claudeContent -AgentName "Claude Code"

    # OpenCode
    $ocAgents = Join-Path $HOME ".config\opencode\AGENTS.md"
    $ocContent = Get-Content -Path (Join-Path $script:Assets "generic\sdd-orchestrator.md") -Raw
    Update-MarkdownSection -FilePath $ocAgents -NewContent $ocContent -AgentName "OpenCode"

    # Cursor
    $cursorFile = Join-Path $HOME ".cursor\rules\gentle-ai.mdc"
    $cursorContent = Get-Content -Path (Join-Path $script:Assets "cursor\sdd-orchestrator.md") -Raw
    Update-MarkdownSection -FilePath $cursorFile -NewContent $cursorContent -AgentName "Cursor"

    # Gemini
    $geminiMd = Join-Path $HOME ".gemini\GEMINI.md"
    $geminiContent = Get-Content -Path (Join-Path $script:Assets "gemini\sdd-orchestrator.md") -Raw
    Update-MarkdownSection -FilePath $geminiMd -NewContent $geminiContent -AgentName "Gemini CLI"

    # Codex
    $codexMd = Join-Path $HOME ".codex\agents.md"
    $codexContent = Get-Content -Path (Join-Path $script:Assets "codex\sdd-orchestrator.md") -Raw
    Update-MarkdownSection -FilePath $codexMd -NewContent $codexContent -AgentName "Codex"

    # Windsurf
    $windsurfMd = Join-Path $HOME ".codeium\windsurf\memories\global_rules.md"
    $windsurfContent = Get-Content -Path (Join-Path $script:Assets "windsurf\sdd-orchestrator.md") -Raw
    Update-MarkdownSection -FilePath $windsurfMd -NewContent $windsurfContent -AgentName "Windsurf"

    # Antigravity (shares GEMINI.md but has separate skills)
    # Orchestrator already patched via Gemini above
}

# ============================================================================
# Patch OpenCode commands
# ============================================================================

function Update-OpenCodeCommands {
    $commandsDir = Join-Path $HOME ".config\opencode\commands"

    if (-not (Test-Path $commandsDir)) { return }

    $sourceDir = Join-Path $script:Assets "opencode\commands"
    $cmdFiles = Get-ChildItem -Path $sourceDir -Filter "*.md" -ErrorAction SilentlyContinue

    foreach ($file in $cmdFiles) {
        Copy-Item -Path $file.FullName -Destination (Join-Path $commandsDir $file.Name) -Force
    }

    Write-Info "  OpenCode: OPSX commands installed"
}

# ============================================================================
# Summary
# ============================================================================

function Show-Summary {
    Write-Host ""
    Write-Host "OPSX patch applied successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "What was patched:" -ForegroundColor White
    Write-Host "  - Skills rewritten to use openspec CLI" -ForegroundColor Cyan
    Write-Host "  - Orchestrator instructions updated to OPSX workflow" -ForegroundColor Cyan
    Write-Host "  - Legacy SDD commands removed" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "OPSX Commands (in your AI agent):" -ForegroundColor White
    Write-Host "  /opsx:explore  - Think through ideas before committing" -ForegroundColor Cyan
    Write-Host "  /opsx:propose  - Create a change with all artifacts" -ForegroundColor Cyan
    Write-Host "  /opsx:apply    - Implement tasks from the change" -ForegroundColor Cyan
    Write-Host "  /opsx:archive  - Sync specs and close the change" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Restart your AI agent for changes to take effect." -ForegroundColor DarkGray
    Write-Host "Docs: https://github.com/$GITHUB_OWNER/$GITHUB_REPO" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
# Main
# ============================================================================

function Main {
    Show-Banner
    Test-Prerequisites
    Get-ForkAssets
    Clear-LegacyCommands
    Update-Skills
    Update-Orchestrators
    Update-OpenCodeCommands
    Show-Summary

    # Cleanup
    if ($script:TmpDir -and (Test-Path $script:TmpDir)) {
        Remove-Item -Path $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Main
