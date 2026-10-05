function Get-DiskUsage {
    <#
    .SYNOPSIS
        Returns free and used space for logical disks.
    .DESCRIPTION
        Local fixed disks are returned by default. Network disks are queried
        only when requested, because a disconnected mapping can stall the call.
        Sizes are bytes on the object and gigabytes in the default table.
    .PARAMETER DriveType
        Local, Removable, Network, Optical, or a combination.
    .EXAMPLE
        df
    .EXAMPLE
        Get-DiskUsage -DriveType Local, Removable
    #>
    [CmdletBinding()]
    [OutputType('DiskVolume')]
    param(
        [ValidateCount(1, 4)]
        [ValidateSet('Local', 'Removable', 'Network', 'Optical')]
        [string[]] $DriveType = @('Local')
    )

    $typeNumber = @{
        Removable = 2
        Local     = 3
        Network   = 4
        Optical   = 5
    }

    $clauses = foreach ($name in $DriveType) {
        'DriveType={0}' -f $typeNumber[$name]
    }
    $filter = $clauses -join ' OR '
    $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter $filter -ErrorAction Stop)

    foreach ($disk in $disks) {
        $volume = New-DiskVolume -Disk $disk
        if ($null -ne $volume) {
            $volume
        }
    }
}
