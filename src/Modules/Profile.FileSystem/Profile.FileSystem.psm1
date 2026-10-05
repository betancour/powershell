Set-StrictMode -Version 1.0

. (Join-Path (Join-Path $PSScriptRoot 'Public') 'Update-FileStamp.ps1')

Set-Alias -Name touch -Value Update-FileStamp
