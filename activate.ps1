# Source this file to sync and apply the PM environment; deactivate restores it.
# Trusts the recorded tool digest. `hermes pm install` re-checks the bytes.
# -TestExtras a,b selects runtime extras in the test environment (default: [all]).
param([string]$TestExtras = '')
$ErrorActionPreference = 'Stop'

$OutputEncoding = [System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

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
            [Environment]::SetEnvironmentVariable($key, $val)
        }
    }
}

# Portable fallback defaults
if (-not $env:HERMES_HOME) {
    $env:HERMES_HOME = Join-Path $driveRoot '.hermes'
}
if (-not $env:HERMES_RUNTIME_DIR) {
    $env:HERMES_RUNTIME_DIR = Join-Path $env:HERMES_HOME 'tools'
}
if (-not $env:UV_TOOL_DIR) {
    $env:UV_TOOL_DIR = Join-Path $env:HERMES_HOME 'tools'
}
if (-not $env:UV_CACHE_DIR) {
    $env:UV_CACHE_DIR = Join-Path $env:HERMES_HOME 'cache'
}
if (-not $env:UV_PYTHON_INSTALL_DIR) {
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $env:HERMES_HOME 'tools\python'
}

# === 1. Run setup-hermes.ps1 in isolated shell if needed ===============
$bootstrapSaved = @{}
foreach ($key in @('PYTHONPATH', 'PYTHONHOME', 'VIRTUAL_ENV')) {
    $bootstrapSaved[$key] = [Environment]::GetEnvironmentVariable($key)
    Remove-Item "env:$key" -ErrorAction SilentlyContinue
}
try {
    # Run separately so setup's exit/failure cannot terminate the sourced shell.
    $shell = (Get-Process -Id $PID).Path
    $testArgs = @()
    if ($TestExtras) { $testArgs = @('-TestExtras', $TestExtras) }
    & $shell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$repo\setup-hermes.ps1" -RuntimeOnly @testArgs | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'activate: setup failed; shell environment unchanged' }
} finally {
    foreach ($key in $bootstrapSaved.Keys) {
        if ($null -eq $bootstrapSaved[$key]) { Remove-Item "env:$key" -ErrorAction SilentlyContinue }
        else { Set-Item "env:$key" $bootstrapSaved[$key] }
    }
}

if (Test-Path function:deactivate) { deactivate }

# === 2. Locate Bootstrap Python =======================================
$py = $null
foreach ($candidate in @(
    "$repo\.venv\Scripts\python.exe",
    "$repo\venv\Scripts\python.exe",
    (Join-Path $env:UV_PYTHON_INSTALL_DIR 'python.exe')
)) {
    if (Test-Path -LiteralPath $candidate) { $py = $candidate; break }
}

if (-not $py) {
    $roots = @(
        $env:HERMES_RUNTIME_DIR,
        "$repo\..\tools",
        (Join-Path $env:HERMES_HOME 'tools')
    )
    foreach ($root in $roots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
        # Check subdirectories matching python-* or python
        foreach ($entry in @(Get-ChildItem -LiteralPath $root -Directory -Filter 'python*' -ErrorAction SilentlyContinue)) {
            $candidate = Join-Path $entry.FullName 'python.exe'
            if (Test-Path -LiteralPath $candidate) { $py = $candidate; break }
            # Some uv distributions place it under bin\ or install\
            $candBin = Join-Path $entry.FullName 'install\python.exe'
            if (Test-Path -LiteralPath $candBin) { $py = $candBin; break }
        }
        if ($py) { break }
    }
}

if (-not $py) { 
    throw "activate: no bootstrap Python found in $env:HERMES_HOME\tools or venv; run setup-hermes.ps1" 
}

# === 3. Query the PM Environment ======================================
$priorPath = $env:PYTHONPATH
$priorHome = $env:PYTHONHOME
try {
    $env:PYTHONPATH = $repo
    Remove-Item env:PYTHONHOME -ErrorAction SilentlyContinue
    $json = (& $py -m pm.environments) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'activate: could not read the installed environment' }
    $composed = $json | ConvertFrom-Json
} finally {
    if ($null -eq $priorPath) { Remove-Item env:PYTHONPATH -ErrorAction SilentlyContinue } else { $env:PYTHONPATH = $priorPath }
    if ($null -eq $priorHome) { Remove-Item env:PYTHONHOME -ErrorAction SilentlyContinue } else { $env:PYTHONHOME = $priorHome }
}

# Save previous environment state for clean deactivation
$global:_hermesKeys = @($composed.PSObject.Properties.Name)
$global:_hermesSaved = @{}
foreach ($key in $global:_hermesKeys) {
    $global:_hermesSaved[$key] = [pscustomobject]@{
        WasSet = (Test-Path "env:$key")
        Value = [Environment]::GetEnvironmentVariable($key)
    }
}

# Apply PM environment variables
foreach ($property in $composed.PSObject.Properties) {
    Set-Item -Path "env:$($property.Name)" -Value ([string]$property.Value)
}

# === 4. Configure hermes CLI Function & Worktree ======================
$global:_hermesWorktree = $repo
$branch = $null
try { $branch = & git -C $repo rev-parse --abbrev-ref HEAD 2>$null } catch { $branch = $null }
if ($branch -and $branch -ne 'HEAD') {
    $global:_hermesWorktreeName = $branch
} else {
    $global:_hermesWorktreeName = Split-Path -Leaf $repo
}

if (Test-Path function:prompt) {
    $global:_hermesSavedPrompt = (Get-Item function:prompt).ScriptBlock
} else {
    $global:_hermesSavedPrompt = $null
}

function global:_hermesWorktreeHere {
    $saved = $global:LASTEXITCODE
    $top = $null
    try { $top = & git rev-parse --show-toplevel 2>$null } catch { $top = $null }
    $global:LASTEXITCODE = $saved
    if (-not $top) { return $false }
    $here = [System.IO.Path]::GetFullPath($top).TrimEnd('\')
    $root = [System.IO.Path]::GetFullPath($global:_hermesWorktree).TrimEnd('\')
    return $here.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function global:hermes {
    if (-not (_hermesWorktreeHere)) {
        $here = (Get-Location).Path
        Write-Error "hermes: $here is outside $($global:_hermesWorktree); refusing (the installed command is hidden while this checkout is active)" -ErrorAction Continue
        $global:LASTEXITCODE = 1
        return
    }
    Push-Location -LiteralPath $global:_hermesWorktree
    try {
        $py = $env:PYTHON
        if (-not $py) {
            foreach ($candidate in @(
                '.venv\Scripts\python.exe', 'venv\Scripts\python.exe',
                (Join-Path $env:HERMES_HOME 'tools\python\python.exe')
            )) {
                if (Test-Path -LiteralPath $candidate) { $py = $candidate; break }
            }
        }
        if (-not $py) { $py = 'python' }
        & $py hermes @args
    } finally {
        Pop-Location
    }
}

function global:prompt {
    $prefix = ''
    if (_hermesWorktreeHere) { $prefix = "($($global:_hermesWorktreeName)) " }
    if ($global:_hermesSavedPrompt) {
        return $prefix + (& $global:_hermesSavedPrompt)
    }
    return "$prefix$($(Get-Location).Path)> "
}

function global:deactivate {
    foreach ($key in $global:_hermesKeys) {
        $saved = $global:_hermesSaved[$key]
        if ($saved.WasSet) { Set-Item -Path "env:$key" -Value $saved.Value }
        else { Remove-Item -Path "env:$key" -ErrorAction SilentlyContinue }
    }
    if ($global:_hermesSavedPrompt) {
        Set-Item -Path function:prompt -Value $global:_hermesSavedPrompt
    } else {
        Remove-Item function:prompt -ErrorAction SilentlyContinue
    }
    $global:_hermesKeys = $null
    $global:_hermesSaved = $null
    $global:_hermesWorktree = $null
    $global:_hermesWorktreeName = $null
    $global:_hermesSavedPrompt = $null
    Remove-Item function:deactivate, function:hermes, function:_hermesWorktreeHere -ErrorAction SilentlyContinue
    Write-Host "Hermes environment deactivated." -ForegroundColor Cyan
}

Write-Host "Hermes environment activated ($($global:_hermesWorktreeName)) on $driveRoot" -ForegroundColor Green