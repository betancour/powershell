function Initialize-ProfileShell {
    <#
    .SYNOPSIS
        Applies the cheap, safe part of the personal profile.
    .DESCRIPTION
        Sets host colors, a secret-aware history filter, optional PATH entries,
        a fallback prompt, and lazy Chocolatey completion. Returns the oh-my-posh
        launcher text so the profile script can run it in the global scope.
        Execution policy is not changed.
    .OUTPUTS
        System.String. Empty when oh-my-posh is not started.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $SettingsPath
    )

    $settings = Get-ProfileSettings -SettingsPath $SettingsPath

    try {
        Set-ProfileHostColor -HostColor $settings.HostColor
    }
    catch {
        Write-Warning "Host colors were not applied: $($_.Exception.Message)"
    }

    try {
        Set-ProfileHistoryGuard
    }
    catch {
        Write-Warning "History filter was not applied: $($_.Exception.Message)"
    }

    foreach ($entry in @($settings.PathEntries)) {
        try {
            Add-ProfilePathEntry -Entry ([string] $entry)
        }
        catch {
            Write-Warning "PATH entry '$entry' was not applied: $($_.Exception.Message)"
        }
    }

    try {
        Set-FallbackPrompt
    }
    catch {
        Write-Warning "Fallback prompt was not installed: $($_.Exception.Message)"
    }

    if ($settings.EnableChocolateyCompletion) {
        try {
            Register-ChocolateyLazyCompletion
        }
        catch {
            Write-Warning "Chocolatey completion was not registered: $($_.Exception.Message)"
        }
    }

    try {
        return (Get-OhMyPoshLaunchScript -ConfigPath ([string] $settings.ThemeConfig))
    }
    catch {
        Write-Warning "oh-my-posh was not initialized: $($_.Exception.Message)"
        return $null
    }
}
