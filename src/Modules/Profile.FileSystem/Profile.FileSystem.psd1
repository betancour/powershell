@{
    RootModule           = 'Profile.FileSystem.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '2822e0a6-ee0f-4ef6-9043-8a0bcf9cae2d'
    Author               = 'Yitzhak B. Solórzano'
    Description          = 'File helpers for the personal PowerShell profile.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Update-FileStamp')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('touch')
    PrivateData          = @{
        PSData = @{
            ProjectUri = 'https://github.com/betancour/powershell'
        }
    }
}
