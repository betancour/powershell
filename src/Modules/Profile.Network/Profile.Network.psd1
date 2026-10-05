@{
    RootModule           = 'Profile.Network.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '6135b936-477e-4c41-86c3-fe3f9962d122'
    Author               = 'Personal'
    Description          = 'Network adapter objects for the personal PowerShell profile.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-NetworkInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('netinfo')
    FormatsToProcess     = @('Profile.Network.Format.ps1xml')
}
