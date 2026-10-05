@{
    # oh-my-posh theme. Ignored when the file is missing, is not an *.omp.json file,
    # or lives outside the user profile or a OneDrive root.
    ThemeConfig = 'C:\Users\betan\OneDrive\.posh_themes\config.omp.json'

    # Absolute directories appended to the process PATH.
    # Missing, relative, UNC, drive-root, and world-writable entries are skipped.
    PathEntries = @()

    # Register Chocolatey completion on first Tab, instead of importing it at startup.
    EnableChocolateyCompletion = $true

    # ConsoleHost message colors. Unknown names are ignored.
    # When this key is present, it replaces the default color map.
    HostColor = @{
        ErrorForegroundColor   = 'Red'
        WarningForegroundColor = 'Yellow'
        VerboseForegroundColor = 'Green'
        DebugForegroundColor   = 'Magenta'
    }
}
