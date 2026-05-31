# install.ps1 — consensus-review one-line installer for Windows (PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/NB3025/consensus-review/main/install.ps1 | iex
#   # (interactive; will prompt for tool)
#
#   $env:CR_TOOL='kiro'; irm https://raw.githubusercontent.com/NB3025/consensus-review/main/install.ps1 | iex
#   # (non-interactive; tool preset via env var)
#
# Or download first, then run:
#   irm https://raw.githubusercontent.com/NB3025/consensus-review/main/install.ps1 -OutFile install.ps1
#   .\install.ps1 -Tool kiro
#
# Supported tools:
#   kiro         → $env:USERPROFILE\.kiro\skills\consensus-review
#   kiro-local   → .\.kiro\skills\consensus-review
#   claude-code  → $env:USERPROFILE\.claude\skills\consensus-review
#   claude-local → .\.claude\skills\consensus-review
#   cursor       → .\.cursor\skills\consensus-review
#   codex        → $env:USERPROFILE\.agents\skills\consensus-review
#   codex-local  → .\.agents\skills\consensus-review
#   gemini       → .\.gemini\skills\consensus-review
#   opencode     → .\.opencode\skills\consensus-review
#   copilot      → .\.github\skills\consensus-review

[CmdletBinding()]
param(
    [string]$Tool = $env:CR_TOOL,
    [string]$Ref = $(if ($env:CR_REF) { $env:CR_REF } else { 'main' }),
    [string]$Repo = $(if ($env:CR_REPO) { $env:CR_REPO } else { 'https://github.com/NB3025/consensus-review' })
)

$ErrorActionPreference = 'Stop'
$SkillName = 'consensus-review'

function Write-Info  { param($m) Write-Host "> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err2  { param($m) Write-Host "[X] $m" -ForegroundColor Red }

function Show-Usage {
    @"
consensus-review installer (PowerShell)

Usage:
  # Download then run (recommended)
  irm $Repo/raw/$Ref/install.ps1 -OutFile install.ps1
  .\install.ps1 -Tool kiro

  # Env var piping
  `$env:CR_TOOL='kiro'; irm $Repo/raw/$Ref/install.ps1 | iex

Supported tools:
  kiro         Kiro (global)        -> `$env:USERPROFILE\.kiro\skills\$SkillName
  kiro-local   Kiro (workspace)     -> .\.kiro\skills\$SkillName
  claude-code  Claude Code (global) -> `$env:USERPROFILE\.claude\skills\$SkillName
  claude-local Claude Code (proj)   -> .\.claude\skills\$SkillName
  cursor       Cursor               -> .\.cursor\skills\$SkillName
  codex        Codex CLI (user)     -> `$env:USERPROFILE\.agents\skills\$SkillName
  codex-local  Codex CLI (proj)     -> .\.agents\skills\$SkillName
  gemini       Gemini CLI           -> .\.gemini\skills\$SkillName
  opencode     OpenCode             -> .\.opencode\skills\$SkillName
  copilot      GitHub Copilot       -> .\.github\skills\$SkillName
"@ | Write-Host
}

function Resolve-Target {
    param([string]$ToolName)
    $u = $env:USERPROFILE
    switch ($ToolName) {
        'kiro'          { return "$u\.kiro\skills\$SkillName" }
        'kiro-local'    { return ".\.kiro\skills\$SkillName" }
        'claude'        { return "$u\.claude\skills\$SkillName" }
        'claude-code'   { return "$u\.claude\skills\$SkillName" }
        'claude-local'  { return ".\.claude\skills\$SkillName" }
        'cursor'        { return ".\.cursor\skills\$SkillName" }
        'codex'         { return "$u\.agents\skills\$SkillName" }
        'codex-local'   { return ".\.agents\skills\$SkillName" }
        'gemini'        { return ".\.gemini\skills\$SkillName" }
        'opencode'      { return ".\.opencode\skills\$SkillName" }
        'copilot'       { return ".\.github\skills\$SkillName" }
        default         { return $null }
    }
}

# Interactive fallback if no tool specified
if (-not $Tool -or $Tool -in @('-h', '--help', 'help')) {
    if ($Tool) { Show-Usage; exit 0 }
    Show-Usage
    Write-Host ""
    $Tool = Read-Host "Which tool? (e.g. kiro, claude-code, cursor)"
    if (-not $Tool) { Write-Err2 "No tool provided. Aborting."; exit 1 }
}

$target = Resolve-Target $Tool
if (-not $target) {
    Write-Err2 "Unknown tool: $Tool"
    Show-Usage
    exit 1
}

Write-Info "Installing $SkillName for $Tool"
Write-Info "Source: $Repo (ref: $Ref)"
Write-Info "Target: $target"

# Overwrite check
if (Test-Path $target) {
    Write-Warn2 "Target already exists: $target"
    $reply = Read-Host "Overwrite? [y/N]"
    if ($reply -notmatch '^(y|Y|yes)$') { Write-Err2 "Aborted."; exit 1 }
    Remove-Item -Recurse -Force $target
}

# Download tarball
$tmp = Join-Path $env:TEMP "consensus-review-$(Get-Random)"
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $tarballUrl = "$Repo/archive/refs/heads/$Ref.tar.gz"
    $tarball = Join-Path $tmp 'skill.tar.gz'
    Write-Info "Downloading $tarballUrl"
    try {
        Invoke-WebRequest -Uri $tarballUrl -OutFile $tarball -UseBasicParsing
    } catch {
        $tarballUrl = "$Repo/archive/$Ref.tar.gz"
        Write-Info "Retry with $tarballUrl"
        Invoke-WebRequest -Uri $tarballUrl -OutFile $tarball -UseBasicParsing
    }

    Write-Info "Extracting"
    # tar is built in on Windows 10 1803+ and Windows 11
    if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
        Write-Err2 "'tar' command not found. Requires Windows 10 1803+ or Windows 11."
        exit 1
    }
    & tar -xzf $tarball -C $tmp
    if ($LASTEXITCODE -ne 0) { Write-Err2 "tar extraction failed."; exit 1 }

    # Find extracted root (GitHub tarball creates one top-level dir)
    $extractedRoot = Get-ChildItem -Path $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } | Select-Object -First 1
    if (-not $extractedRoot) {
        Write-Err2 "Unexpected tarball structure (no SKILL.md at root)."
        exit 1
    }

    # Prepare target parent and copy
    $targetParent = Split-Path $target -Parent
    if (-not (Test-Path $targetParent)) { New-Item -ItemType Directory -Force -Path $targetParent | Out-Null }
    New-Item -ItemType Directory -Force -Path $target | Out-Null

    Write-Info "Installing files"
    foreach ($item in @('SKILL.md','LICENSE','README.md','prompts','references','examples')) {
        $src = Join-Path $extractedRoot.FullName $item
        if (Test-Path $src) {
            Copy-Item -Recurse -Force -Path $src -Destination $target
        }
    }

    $resolvedTarget = (Resolve-Path $target).Path
    Write-Ok "Installed $SkillName to $resolvedTarget"
    Write-Host ""

    switch ($Tool) {
        { $_ -in 'kiro','kiro-local' } {
            Write-Info "Next: open Kiro CLI (kiro chat) and invoke /consensus-review, or just ask to review a document."
        }
        { $_ -in 'claude','claude-code','claude-local' } {
            Write-Info "Next: run 'claude', then try '/consensus-review' or ask 'review this document'."
        }
        'cursor' {
            Write-Warn2 "Cursor: ensure Nightly channel + Agent Skills enabled (Settings -> Beta / Rules)."
        }
        'gemini' {
            Write-Warn2 "Gemini CLI: install preview via 'npm i -g @google/gemini-cli@preview', then /settings -> enable Skills."
        }
    }
    Write-Host ""
    Write-Ok "Try it: share a document with your agent and ask '리뷰해줘' or 'review this document'."
}
finally {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}
