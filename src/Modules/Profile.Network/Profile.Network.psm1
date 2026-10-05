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

function Add-ProfileTypeName {
    param(
        $Object,
        [string] $TypeName
    )

    if ($Object.PSObject.TypeNames -notcontains $TypeName) {
        $Object.PSObject.TypeNames.Insert(0, $TypeName)
    }

    return $Object
}

function ConvertTo-IpString {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Net.IPAddress]) {
        return $Value.IPAddressToString
    }

    $addressProperty = $Value.PSObject.Properties['Address']
    if ($null -ne $addressProperty -and $addressProperty.Value -is [System.Net.IPAddress]) {
        return $addressProperty.Value.IPAddressToString
    }

    return $null
}

function Get-IpList {
    param($Values)

    $result = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($Values)) {
        $text = ConvertTo-IpString -Value $value
        if ([string]::IsNullOrWhiteSpace($text) -or $result.Contains($text)) {
            continue
        }

        $result.Add($text)
    }

    # The comma keeps the array as one object when the function returns.
    return , $result.ToArray()
}

function Get-UnicastText {
    param($Addresses, [System.Net.Sockets.AddressFamily] $Family)

    $values = New-Object System.Collections.Generic.List[string]
    foreach ($address in @($Addresses)) {
        if ($null -eq $address) {
            continue
        }

        $ip = $address.PSObject.Properties['Address']
        if ($null -eq $ip -or $ip.Value -isnot [System.Net.IPAddress]) {
            continue
        }

        if ($ip.Value.AddressFamily -ne $Family) {
            continue
        }

        if (-not $values.Contains($ip.Value.IPAddressToString)) {
            $values.Add($ip.Value.IPAddressToString)
        }
    }

    return , $values.ToArray()
}

function Get-NetworkInfo {
    <#
    .SYNOPSIS
        Returns one object per network adapter.
    .DESCRIPTION
        Reads the local IP stack through .NET. Up adapters are returned unless
        -All is set. Loopback adapters are omitted.
    .PARAMETER All
        Include adapters that are not currently up.
    .EXAMPLE
        netinfo
    .EXAMPLE
        Get-NetworkInfo -All | Select-Object Name, IPv4Address, DnsServer
    #>
    [CmdletBinding()]
    [OutputType([NetworkAdapterInfo])]
    param(
        [switch] $All
    )

    $interfaces = @([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces())
    foreach ($adapter in $interfaces) {
        if (-not $All -and $adapter.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) {
            continue
        }

        if ($adapter.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback) {
            continue
        }

        $properties = $adapter.GetIPProperties()
        $dhcp = $false
        try {
            $ipv4Properties = $properties.GetIPv4Properties()
            if ($null -ne $ipv4Properties) {
                $dhcp = [bool] $ipv4Properties.IsDhcpEnabled
            }
        }
        catch {
            $dhcp = $false
        }

        $info = [NetworkAdapterInfo]::new()
        $info.Name = [string] $adapter.Name
        $info.Description = [string] $adapter.Description
        $info.Status = [string] $adapter.OperationalStatus
        $info.MacAddress = [string] $adapter.GetPhysicalAddress()
        $info.IPv4Address = Get-UnicastText -Addresses $properties.UnicastAddresses -Family InterNetwork
        $info.IPv6Address = Get-UnicastText -Addresses $properties.UnicastAddresses -Family InterNetworkV6
        $info.Gateway = Get-IpList -Values $properties.GatewayAddresses
        $info.DnsServer = Get-IpList -Values $properties.DnsAddresses
        $info.DhcpEnabled = $dhcp

        Add-ProfileTypeName -Object $info -TypeName 'Profile.NetworkAdapterInfo'
    }
}

Set-Alias -Name netinfo -Value Get-NetworkInfo
