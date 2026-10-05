function Set-ProfileHostColor {
    param($HostColor)

    if ($Host.Name -ne 'ConsoleHost') {
        return
    }

    if ($null -eq $HostColor) {
        return
    }

    $allowed = @([Enum]::GetNames([System.ConsoleColor]))
    $privateData = $Host.PrivateData
    if ($null -eq $privateData) {
        return
    }

    foreach ($propertyName in @($HostColor.Keys)) {
        $colorName = [string] $HostColor[$propertyName]
        $match = $allowed | Where-Object { $_ -eq $colorName } | Select-Object -First 1
        if (-not $match) {
            Write-Verbose "Unknown console color '$colorName' for $propertyName."
            continue
        }

        if (-not ($privateData.PSObject.Properties.Name -contains $propertyName)) {
            continue
        }

        try {
            $privateData.$propertyName = $match
        }
        catch {
            Write-Verbose "Host color $propertyName was not applied: $($_.Exception.Message)"
        }
    }
}
