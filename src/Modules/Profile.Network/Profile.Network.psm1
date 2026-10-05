Set-StrictMode -Version 1.0

class NetworkAdapterInfo {
    [string] $Name
    [string] $Description
    [string] $Status
    [string] $MacAddress
    [string[]] $IPv4Address
    [string[]] $IPv6Address
    [string[]] $Gateway
    [string[]] $DnsServer
    [bool] $DhcpEnabled
}

foreach ($name in @(
        'Add-ProfileTypeName.ps1'
        'ConvertTo-IpString.ps1'
    )) {
    . (Join-Path (Join-Path $PSScriptRoot 'Private') $name)
}

. (Join-Path (Join-Path $PSScriptRoot 'Public') 'Get-NetworkInfo.ps1')

Set-Alias -Name netinfo -Value Get-NetworkInfo
