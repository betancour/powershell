#Requires -Version 5.1
<#
.SYNOPSIS
    PowerShell 7 profile. This file starts the configuration.

.DESCRIPTION
    pwsh.exe reads this path as $PROFILE:

        Documents\PowerShell\Microsoft.PowerShell_profile.ps1

    Dot-source this file from there:

        . 'C:\path\to\repo\profiles\PowerShell\Microsoft.PowerShell_profile.ps1'

    It runs only for PowerShell 7 (Core). The shared console profile then
    loads the configuration once per session.
#>

if ($PSVersionTable.PSEdition -ne 'Core') {
    Write-Warning 'This profile starts PowerShell 7. Windows PowerShell 5.1 uses profiles\WindowsPowerShell\Microsoft.PowerShell_profile.ps1.'
    return
}

$consoleProfile = Join-Path (Split-Path -Parent $PSScriptRoot) 'CurrentUserCurrentHost.ps1'
if (-not (Test-Path -LiteralPath $consoleProfile -PathType Leaf)) {
    Write-Warning "Console profile was not found: $consoleProfile"
    return
}

. $consoleProfile
