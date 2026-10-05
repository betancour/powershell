#Requires -Version 5.1
<#
.SYNOPSIS
    Console startup profile for powershell.exe and pwsh.exe.

.DESCRIPTION
    Dot-source this from $PROFILE (CurrentUserCurrentHost):

        . 'C:\path\to\repo\profiles\CurrentUserCurrentHost.ps1'

    Console-only lines belong in this file. Shared startup goes through
    CurrentUserAllHosts.ps1, which loads src/Start-Profile.ps1 once per session.
#>

$dispatcherPath = Join-Path $PSScriptRoot 'CurrentUserAllHosts.ps1'
if (-not (Test-Path -LiteralPath $dispatcherPath -PathType Leaf)) {
    Write-Warning "Profile dispatcher was not found: $dispatcherPath"
    return
}

. $dispatcherPath
