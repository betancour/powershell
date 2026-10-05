function ConvertTo-Gigabytes {
    param([Parameter(Mandatory)][double] $Bytes)

    return [math]::Round($Bytes / 1GB, 2)
}
