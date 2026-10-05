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
    [OutputType('NetworkAdapterInfo')]
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
