# ============================================================================
# Hermes Agent Portable Environment Activator (Windows)
# Sets up portable paths on the drive root and loads .env before activating.
# Keeping this separate from activate.ps1 ensures zero merge conflicts on sync.
# ============================================================================
param([string]$TestExtras = '')
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
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $env:HERMES_HOME 'tools\python'
    [Environment]::SetEnvironmentVariable('UV_PYTHON_INSTALL_DIR', $env:UV_PYTHON_INSTALL_DIR, 'Process')
}

# Ensure directories exist
New-Item -ItemType Directory -Force -Path $env:HERMES_HOME | Out-Null
New-Item -ItemType Directory -Force -Path $env:HERMES_RUNTIME_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $env:UV_CACHE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $env:UV_PYTHON_INSTALL_DIR | Out-Null

# Link/junction python helper if needed so upstream activate.ps1 always finds it under python-*
$pyTools = Join-Path $env:HERMES_HOME 'tools'
$hasPy = Get-ChildItem -LiteralPath $pyTools -Directory -Filter 'python-*' -ErrorAction SilentlyContinue
if (-not $hasPy) {
    $candDirs = @(
        (Join-Path $pyTools 'python'),
        (Join-Path $env:UV_PYTHON_INSTALL_DIR 'cpython*')
    )
    foreach ($cand in $candDirs) {
        $found = Get-ChildItem -Path $cand -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $dest = Join-Path $pyTools 'python-portable'
            if (-not (Test-Path $dest)) {
                try { New-Item -ItemType Junction -Path $dest -Target $found.FullName -ErrorAction SilentlyContinue | Out-Null } catch {}
            }
            break
        }
    }
}

# Run upstream activate.ps1
. "$repo\activate.ps1" @args
