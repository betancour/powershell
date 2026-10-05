Set-StrictMode -Version 1.0

# Shared by the dot-sourced functions. $script: in those files is this module.
$script:ChocolateyProfileLoaded = $false
$script:CommandStubsInstalled = $false

$private = @(
    'Test-ChildPath.ps1'
    'Get-ProfileSettings.ps1'
    'Resolve-ThemeConfigPath.ps1'
    'Get-OhMyPoshLaunchScript.ps1'
    'Add-ProfilePathEntry.ps1'
    'Set-ProfileHostColor.ps1'
    'Set-ProfileHistoryGuard.ps1'
    'Set-FallbackPrompt.ps1'
    'Register-ChocolateyLazyCompletion.ps1'
)

foreach ($name in $private) {
    . (Join-Path (Join-Path $PSScriptRoot 'Private') $name)
}

$public = @(
    'Enable-ChocolateyCompletion.ps1'
    'Initialize-ProfileShell.ps1'
)

foreach ($name in $public) {
    . (Join-Path (Join-Path $PSScriptRoot 'Public') $name)
}
