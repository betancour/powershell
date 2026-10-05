#Requires -Version 5.1
<#
.SYNOPSIS
    All-hosts profile dispatcher.

.DESCRIPTION
    Dot-source this from $PROFILE.CurrentUserAllHosts for Windows PowerShell
    5.1 and PowerShell 7. It loads src/Start-Profile.ps1 once per session.

        . 'C:\path\to\repo\profiles\CurrentUserAllHosts.ps1'

    powershell.exe and pwsh.exe keep that profile in different documents
    folders. The console entry point is CurrentUserCurrentHost.ps1.
#>

if ($global:ProfileDispatcherLoaded) {
    return
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$startupPath = Join-Path (Join-Path $repoRoot 'src') 'Start-Profile.ps1'
if (-not (Test-Path -LiteralPath $startupPath -PathType Leaf)) {
    Write-Warning "Profile startup was not found: $startupPath"
    return
}

$global:ProfileDispatcherLoaded = $true
. $startupPath
