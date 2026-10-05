function Get-ProfileSettings {
    param([string] $SettingsPath)

    $defaults = @{
        ThemeConfig                = $null
        PathEntries                = @()
        EnableChocolateyCompletion = $true
        HostColor                  = @{
            ErrorForegroundColor   = 'Red'
            WarningForegroundColor = 'Yellow'
            VerboseForegroundColor = 'Green'
            DebugForegroundColor   = 'Magenta'
        }
    }

    if ([string]::IsNullOrWhiteSpace($SettingsPath) -or -not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return $defaults
    }

    try {
        $loaded = Import-PowerShellDataFile -LiteralPath $SettingsPath -ErrorAction Stop
    }
    catch {
        Write-Warning "Profile settings were not loaded: $($_.Exception.Message)"
        return $defaults
    }

    foreach ($key in @($defaults.Keys)) {
        if ($loaded.ContainsKey($key) -and $null -ne $loaded[$key]) {
            $defaults[$key] = $loaded[$key]
        }
    }

    return $defaults
}
