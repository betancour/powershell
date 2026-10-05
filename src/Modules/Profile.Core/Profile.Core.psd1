@{
    RootModule           = 'Profile.Core.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '0a8281e2-a6db-4bb7-9fe3-9fc396c0db30'
    Author               = 'Personal'
    Description          = 'Startup helpers for the personal PowerShell profile. Heavy commands live in separate autoloaded modules.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Initialize-ProfileShell'
        'Enable-ChocolateyCompletion'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
}
