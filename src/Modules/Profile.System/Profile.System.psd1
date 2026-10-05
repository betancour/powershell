@{
    RootModule           = 'Profile.System.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a620844e-3a9e-47b0-be3b-9da4ad84e379'
    Author               = 'Personal'
    Description          = 'System, disk, and process objects for the personal PowerShell profile.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Get-SystemUptime'
        'Get-DiskUsage'
        'Get-ProcessDetail'
        'Get-SystemReport'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('uptime', 'df', 'proc', 'sysinfo')
    FormatsToProcess     = @('Profile.System.Format.ps1xml')
}
