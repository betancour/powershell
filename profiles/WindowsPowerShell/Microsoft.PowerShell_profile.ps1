#Requires -Version 5.1
<#
.SYNOPSIS
    Windows PowerShell 5.1 profile. This file starts the configuration.

.DESCRIPTION
    powershell.exe reads this path as $PROFILE:

        Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

    Dot-source this file from there:

        . 'C:\path\to\repo\profiles\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

    It runs only for Windows PowerShell 5.1 (Desktop). The shared console
    profile then loads the configuration once per session.
#>

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    Write-Warning 'This profile starts Windows PowerShell 5.1. PowerShell 7 uses profiles\PowerShell\Microsoft.PowerShell_profile.ps1.'
    return
}

$consoleProfile = Join-Path (Split-Path -Parent $PSScriptRoot) 'CurrentUserCurrentHost.ps1'
if (-not (Test-Path -LiteralPath $consoleProfile -PathType Leaf)) {
    Write-Warning "Console profile was not found: $consoleProfile"
    return
}

. $consoleProfile
