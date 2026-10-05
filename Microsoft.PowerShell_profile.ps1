#Requires -Version 5.1
<#
.SYNOPSIS
    Console startup profile for powershell.exe and pwsh.exe.

.DESCRIPTION
    This is the CurrentUserCurrentHost profile ($PROFILE) for ConsoleHost.
    Install it with:

        . 'C:\path\to\repo\Microsoft.PowerShell_profile.ps1'

    It hands off to profile.ps1. Host-specific console lines belong in this
    file. Shared startup stays in the dispatcher and main.ps1.
#>

$dispatcherPath = Join-Path $PSScriptRoot 'profile.ps1'
if (-not (Test-Path -LiteralPath $dispatcherPath -PathType Leaf)) {
    Write-Warning "Profile dispatcher was not found: $dispatcherPath"
    return
}

. $dispatcherPath
