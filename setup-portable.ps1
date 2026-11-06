# ============================================================================
# Hermes Agent Portable Environment Setup (Windows)
# Configures portable drive paths and loads .env before running setup-hermes.ps1.
# Keeping this separate from setup-hermes.ps1 ensures zero merge conflicts on sync.
# ============================================================================
param([switch]$RuntimeOnly, [string]$TestExtras = '')
$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$driveRoot = Split-Path -Qualifier $repo

# === 0. Auto-load portable environment from .env or Drive Root =======
$envCandidates = @(
    (Join-Path $repo '.env'),
    (Join-Path $driveRoot '.hermes\.env')
)
foreach ($ef in $envCandidates) {
    if (Test-Path $ef) {
        foreach ($line in Get-Content $ef -Encoding UTF8) {
            $trimmed = $line.Trim()
            if (-not $trimmed -or $trimmed.StartsWith('#') -or -not $trimmed.Contains('=')) { continue }
            $kv = $trimmed -split '=', 2
            $key = ($kv[0].Trim() -replace '^export\s+', '').Trim()
            if ($key -in @('UID', 'GID', 'EUID', 'EGID', 'PPID')) { continue }
            if ($key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { continue }
            if ($null -ne [Environment]::GetEnvironmentVariable($key)) { continue }
            $val = $kv[1].Trim()
            if ($val -match '^"(.*)"$') { $val = $Matches[1] }
            elseif ($val -match "^'(.*)'$") { $val = $Matches[1] }
            [Environment]::SetEnvironmentVariable($key, $val, 'Process')
            Set-Item "env:$key" $val
        }
    }
}

# Portable fallback defaults
if (-not $env:HERMES_HOME) {
    $env:HERMES_HOME = Join-Path $driveRoot '.hermes'
    [Environment]::SetEnvironmentVariable('HERMES_HOME', $env:HERMES_HOME, 'Process')
}
if (-not $env:HERMES_RUNTIME_DIR) {
    $env:HERMES_RUNTIME_DIR = Join-Path $env:HERMES_HOME 'tools'
    [Environment]::SetEnvironmentVariable('HERMES_RUNTIME_DIR', $env:HERMES_RUNTIME_DIR, 'Process')
}
if (-not $env:UV_TOOL_DIR) {
    $env:UV_TOOL_DIR = Join-Path $env:HERMES_HOME 'tools'
    [Environment]::SetEnvironmentVariable('UV_TOOL_DIR', $env:UV_TOOL_DIR, 'Process')
}
if (-not $env:UV_CACHE_DIR) {
    $env:UV_CACHE_DIR = Join-Path $env:HERMES_HOME 'cache'
    [Environment]::SetEnvironmentVariable('UV_CACHE_DIR', $env:UV_CACHE_DIR, 'Process')
}
if (-not $env:UV_PYTHON_INSTALL_DIR) {
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $env:HERMES_RUNTIME_DIR 'python'
    [Environment]::SetEnvironmentVariable('UV_PYTHON_INSTALL_DIR', $env:UV_PYTHON_INSTALL_DIR, 'Process')
}

# Ensure directories exist
New-Item -ItemType Directory -Force -Path $env:HERMES_HOME | Out-Null
New-Item -ItemType Directory -Force -Path $env:HERMES_RUNTIME_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $env:UV_CACHE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $env:UV_PYTHON_INSTALL_DIR | Out-Null

& "$repo\setup-hermes.ps1" @args
