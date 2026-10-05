function Get-PreferredIPv4 {
    $preferred = $null
    $interfaces = @([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces())
    foreach ($adapter in $interfaces) {
        if ($adapter.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) {
            continue
        }

        if ($adapter.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback) {
            continue
        }

        $properties = $adapter.GetIPProperties()
        $hasGateway = @($properties.GatewayAddresses).Count -gt 0
        foreach ($unicast in @($properties.UnicastAddresses)) {
            if ($null -eq $unicast -or $null -eq $unicast.Address) {
                continue
            }

            if ($unicast.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
                continue
            }

            $ip = $unicast.Address.IPAddressToString
            if ($ip.StartsWith('169.254.')) {
                continue
            }

            if ($hasGateway) {
                return $ip
            }

            if ([string]::IsNullOrEmpty($preferred)) {
                $preferred = $ip
            }
        }
    }

    return $preferred
}
