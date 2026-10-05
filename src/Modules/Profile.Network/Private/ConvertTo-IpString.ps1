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
