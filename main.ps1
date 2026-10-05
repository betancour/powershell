#Requires -Version 5.1
<#
.SYNOPSIS
    Personal PowerShell startup.

.DESCRIPTION
    Shared startup used by profile.ps1. The console entry point is
    Microsoft.PowerShell_profile.ps1. Both load this file once per session.

    uptime, df, proc, sysinfo, netinfo, and touch load their modules on first use.
    Execution policy is left alone. Set it once, outside this script, if you need to:

        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#>

if ($global:ProfileStartupLoaded) {
    return
}

$moduleRoot = Join-Path (Join-Path $PSScriptRoot 'src') 'Modules'
if (-not (Test-Path -LiteralPath $moduleRoot -PathType Container)) {
    Write-Warning "Profile modules were not found: $moduleRoot"
    return
}

$global:ProfileStartupLoaded = $true

$separator = [string] [System.IO.Path]::PathSeparator
$normalizedRoot = $moduleRoot.TrimEnd('\', '/')
$modulePathReady = $false
foreach ($entry in @($env:PSModulePath -split [regex]::Escape([string] $separator))) {
    if ([string]::IsNullOrWhiteSpace($entry)) {
        continue
    }

    $candidate = $entry.Trim().TrimEnd('\', '/')
    if ([string]::Equals($candidate, $normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $modulePathReady = $true
        break
    }
}

if (-not $modulePathReady) {
    if ([string]::IsNullOrEmpty($env:PSModulePath)) {
        $env:PSModulePath = $moduleRoot
    }
    else {
        $env:PSModulePath = $moduleRoot + $separator + $env:PSModulePath
    }
}

Import-Module -Name 'Profile.Core' -DisableNameChecking -ErrorAction Stop

$settingsPath = Join-Path (Join-Path $PSScriptRoot 'config') 'profile.settings.psd1'
$promptInit = Initialize-ProfileShell -SettingsPath $settingsPath

if ($global:ProfileUseChocolateyCompleter -and -not $global:ProfileChocolateyCompleterRegistered) {
    $global:ProfileChocolateyCompleterRegistered = $true
    Register-ArgumentCompleter -Native -CommandName 'choco' -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        $module = Get-Module -Name 'Profile.Core'
        if (-not $module) {
            return
        }

        $module.Invoke(
            {
                param($word)
                Complete-ChocolateyArgument -WordToComplete $word
            },
            $wordToComplete
        )
    }
}

if (-not [string]::IsNullOrWhiteSpace($promptInit)) {
    try {
        # Run in this scope. The profile is dot-sourced, so oh-my-posh can
        # replace the global prompt. The text is the short launcher returned
        # by a verified oh-my-posh.exe, not an inlined eval script.
        . ([scriptblock]::Create($promptInit))
    }
    catch {
        Write-Warning "oh-my-posh prompt was not applied: $($_.Exception.Message)"
    }
}
