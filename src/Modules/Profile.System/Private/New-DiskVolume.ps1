function New-DiskVolume {
    param($Disk)

    if ($null -eq $Disk -or $null -eq $Disk.Size -or [int64] $Disk.Size -le 0 -or $null -eq $Disk.FreeSpace) {
        return $null
    }

    $size = [int64] $Disk.Size
    $free = [int64] $Disk.FreeSpace
    if ($free -gt $size) {
        $free = $size
    }

    $used = $size - $free
    $volume = [DiskVolume]::new()
    $volume.DeviceId = [string] $Disk.DeviceID
    $volume.VolumeName = [string] $Disk.VolumeName
    $volume.FileSystem = [string] $Disk.FileSystem
    $volume.SizeBytes = $size
    $volume.FreeBytes = $free
    $volume.UsedBytes = $used
    $volume.TotalGB = ConvertTo-Gigabytes -Bytes $size
    $volume.FreeGB = ConvertTo-Gigabytes -Bytes $free
    $volume.UsedGB = ConvertTo-Gigabytes -Bytes $used
    $volume.PercentUsed = [math]::Round((100.0 * $used) / $size, 1)
    $volume.PercentFree = [math]::Round((100.0 * $free) / $size, 1)
    Add-ProfileTypeName -Object $volume -TypeName 'Profile.DiskVolume'
    return $volume
}
