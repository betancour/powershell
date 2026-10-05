#Requires -Version 5.1
<#
.SYNOPSIS
    All-hosts profile dispatcher.

.DESCRIPTION
    Loads the shared startup in main.ps1 once per session. Dot-source this
    file from any host profile, or install it as $PROFILE.CurrentUserAllHosts
    for both Windows PowerShell 5.1 and PowerShell 7:

        . 'C:\path\to\repo\profile.ps1'

    powershell.exe and pwsh.exe keep that file in different documents folders.
    The console host entry is Microsoft.PowerShell_profile.ps1.
#>

if ($global:ProfileDispatcherLoaded) {
    return
}

$startupPath = Join-Path $PSScriptRoot 'main.ps1'
if (-not (Test-Path -LiteralPath $startupPath -PathType Leaf)) {
    Write-Warning "Profile startup was not found: $startupPath"
    return
}

$global:ProfileDispatcherLoaded = $true
. $startupPath
