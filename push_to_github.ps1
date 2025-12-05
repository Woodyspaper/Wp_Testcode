<#
push_to_github.ps1

Helper script to create a repository under a GitHub org and push the current local repository.
Requirements:
- `gh` CLI installed and authenticated (`gh auth login`).
- `git` installed.

Usage (run in the repo root):
  .\push_to_github.ps1 -Org 'Woodyspaper' -Repo 'Wp_Testcode' -Visibility 'private'

This script will:
 - verify gh auth status
 - create the repo under the given org (if not present)
 - add `origin` remote if missing
 - rename branch to `main` and push
#>

param(
    [string]$Org = 'Woodyspaper',
    [string]$Repo = 'Wp_Testcode',
    [ValidateSet('private','public')][string]$Visibility = 'private'
)

function ExitWithError([string]$msg, [int]$code = 1) {
    Write-Error $msg
    exit $code
}

Write-Host "Preparing to push repo '$Repo' to organization '$Org' (visibility=$Visibility)" -ForegroundColor Cyan

# Explicit paths for Git and GitHub CLI (in case they're not on PATH)
$gitExe = 'C:\Program Files\Git\cmd\git.exe'
$ghExe = 'C:\Program Files\GitHub CLI\gh.exe'

# Check git
if (-not (Test-Path $gitExe)) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        ExitWithError 'git not found on PATH or at expected location. Install Git and retry.' 2
    }
    $gitExe = 'git'
}

# Check gh
if (-not (Test-Path $ghExe)) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        ExitWithError 'gh (GitHub CLI) not found on PATH or at expected location. Install gh and retry.' 3
    }
    $ghExe = 'gh'
}

# Ensure we are inside a git repo
$root = (& $gitExe rev-parse --show-toplevel) 2>$null
if ($LASTEXITCODE -ne 0) {
    ExitWithError "Current directory is not inside a git repository. Run this script from the repo root." 4
}

Set-Location $root

# Verify gh authentication
try {
    & $ghExe auth status --hostname github.com > $null 2>&1
} catch {
    ExitWithError "gh is not authenticated. Run 'gh auth login' and follow the browser flow, then re-run this script." 5
}

# Create repository if it does not exist
$full = "$Org/$Repo"
$exists = $false
try {
    $r = & $ghExe repo view $full --json name -q .name 2>$null
    if ($LASTEXITCODE -eq 0) { $exists = $true }
} catch { $exists = $false }

if (-not $exists) {
    Write-Host "Creating repository $full..." -ForegroundColor Yellow
    & $ghExe repo create $full --$Visibility --confirm
    if ($LASTEXITCODE -ne 0) { ExitWithError "Failed to create repo $full via gh" 6 }
} else {
    Write-Host "Remote repository $full already exists." -ForegroundColor Green
}

# Add origin remote if missing or update to canonical URL
$remoteUrl = "https://github.com/$full.git"
$current = (& $gitExe remote get-url origin) 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Adding origin -> $remoteUrl" -ForegroundColor Yellow
    & $gitExe remote add origin $remoteUrl
    if ($LASTEXITCODE -ne 0) { ExitWithError 'Failed to add remote origin' 7 }
} else {
    Write-Host "Existing origin: $current" -ForegroundColor Green
    if ($current -ne $remoteUrl) {
        Write-Host "Updating origin URL to $remoteUrl" -ForegroundColor Yellow
        & $gitExe remote set-url origin $remoteUrl
        if ($LASTEXITCODE -ne 0) { ExitWithError 'Failed to update origin URL' 8 }
    }
}

# Ensure branch is main and push
Write-Host 'Switching/renaming current branch to main (if needed)' -ForegroundColor Cyan
try { & $gitExe branch --show-current } catch { }
& $gitExe branch -M main

Write-Host 'Pushing to origin main (this will create the remote branch)' -ForegroundColor Cyan
& $gitExe push -u origin main
if ($LASTEXITCODE -ne 0) { ExitWithError 'Push failed' 9 }

Write-Host "Push successful. Clone on the server with:\n\n  git clone https://github.com/$full.git" -ForegroundColor Green

exit 0
