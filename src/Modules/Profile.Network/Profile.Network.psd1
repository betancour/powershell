@{
    RootModule           = 'Profile.Network.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '6135b936-477e-4c41-86c3-fe3f9962d122'
    Author               = 'Yitzhak B. Solórzano'
    Description          = 'Network adapter objects for the personal PowerShell profile.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Get-NetworkInfo')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('netinfo')
    FormatsToProcess     = @('Formats/Profile.Network.format.ps1xml')
    PrivateData          = @{
        PSData = @{
            ProjectUri = 'https://github.com/betancour/powershell'
        }
    }
}
