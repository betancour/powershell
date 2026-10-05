Set-StrictMode -Version 1.0

class ProcessSnapshot {
    [int] $Id
    [string] $Name
    [double] $CpuSeconds
    [double] $MemoryMB
}

class ProcessDetail {
    [int] $Id
    [string] $Name
    [double] $CpuSeconds
    [double] $MemoryMB
    [int] $ThreadCount
    [string] $Path
    [string] $Description
}

class DiskVolume {
    [string] $DeviceId
    [string] $VolumeName
    [string] $FileSystem
    [int64] $SizeBytes
    [int64] $UsedBytes
    [int64] $FreeBytes
    [double] $TotalGB
    [double] $UsedGB
    [double] $FreeGB
    [double] $PercentUsed
    [double] $PercentFree
}

class SystemUptime {
    [datetime] $LastBoot
    [timespan] $Elapsed

    [string] ToString() {
        return 'Uptime: {0} Days, {1} Hours, {2} Minutes, {3} Seconds' -f $this.Elapsed.Days, $this.Elapsed.Hours, $this.Elapsed.Minutes, $this.Elapsed.Seconds
    }
}

class SystemReport {
    [string] $ProductName
    [string] $DisplayVersion
    [string] $Build
    [string] $Architecture
    [string] $HostName
    [string] $CpuName
    [int] $LogicalProcessors
    [double] $CpuPercent
    [bool] $HasCpuSample
    [double] $MemoryTotalGB
    [double] $MemoryUsedGB
    [double] $MemoryFreeGB
    [string] $IPv4
    [int] $ProcessCount
    [int] $InteractiveSessions
    [bool] $HasInteractiveSessions
    [timespan] $Uptime
    [string] $SystemDrive
    [double] $DriveTotalGB
    [double] $DriveUsedPercent
    [bool] $HasDriveSample
    [ProcessSnapshot[]] $TopProcesses

    [string] ToDisplayString() {
        return (Format-SystemReportText -Report $this)
    }
}

function Add-ProfileTypeName {
    param(
        $Object,
        [string] $TypeName
    )

    if ($Object.PSObject.TypeNames -notcontains $TypeName) {
        [void] $Object.PSObject.TypeNames.Insert(0, $TypeName)
    }
}

function ConvertTo-Gigabytes {
    param([Parameter(Mandatory)][double] $Bytes)

    return [math]::Round($Bytes / 1GB, 2)
}

function Get-ProcessNumbers {
    param($Process)

    $cpuSeconds = 0.0
    try {
        if ($null -ne $Process.TotalProcessorTime) {
            $cpuSeconds = [math]::Round($Process.TotalProcessorTime.TotalSeconds, 2)
        }
    }
    catch {
        $cpuSeconds = 0.0
    }

    $memoryBytes = [int64] 0
    try {
        $memoryBytes = [int64] $Process.WorkingSet64
    }
    catch {
        $memoryBytes = 0
    }

    $threadCount = 0
    try {
        $threadCount = @($Process.Threads).Count
    }
    catch {
        $threadCount = 0
    }

    return [pscustomobject]@{
        CpuSeconds  = $cpuSeconds
        MemoryBytes = $memoryBytes
        MemoryMB    = [math]::Round($memoryBytes / 1MB, 2)
        ThreadCount = $threadCount
    }
}

function Get-SafeProcessText {
    param(
        $Process,
        [string] $PropertyName
    )

    try {
        $value = $Process.$PropertyName
        if ($null -eq $value) {
            return ''
        }

        return [string] $value
    }
    catch {
        return ''
    }
}

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

function Format-BoxRule {
    param([int] $Width)

    if ($Width -lt 2) {
        $Width = 2
    }

    return '+' + ('-' * ($Width - 2)) + '+'
}

function Format-BoxLine {
    param(
        [string] $Text,
        [int] $Width
    )

    $inner = $Width - 4
    if ($inner -lt 1) {
        $inner = 1
    }

    if ($null -eq $Text) {
        $Text = ''
    }

    if ($Text.Length -gt $inner) {
        $Text = $Text.Substring(0, $inner)
    }

    return '| ' + $Text.PadRight($inner) + ' |'
}

function Format-FitText {
    param(
        [string] $Text,
        [int] $Width
    )

    if ($null -eq $Text) {
        $Text = ''
    }

    if ($Width -le 0) {
        return ''
    }

    if ($Text.Length -gt $Width) {
        return $Text.Substring(0, $Width)
    }

    return $Text
}

function Format-SystemReportText {
    param([Parameter(Mandatory)] $Report)

    $width = 100
    try {
        $windowWidth = [int] $Host.UI.RawUI.WindowSize.Width
        if ($windowWidth -ge 80) {
            $width = [Math]::Min($windowWidth - 1, 120)
        }
    }
    catch {
        $width = 100
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add((Format-BoxRule -Width $width))

    $identity = New-Object System.Collections.Generic.List[string]
    $identity.Add($(if ([string]::IsNullOrWhiteSpace($Report.ProductName)) { 'Windows' } else { $Report.ProductName }))
    if (-not [string]::IsNullOrWhiteSpace($Report.DisplayVersion)) {
        $identity.Add([string] $Report.DisplayVersion)
    }
    if (-not [string]::IsNullOrWhiteSpace($Report.Build)) {
        $identity.Add('Build ' + [string] $Report.Build)
    }
    if (-not [string]::IsNullOrWhiteSpace($Report.Architecture)) {
        $identity.Add([string] $Report.Architecture)
    }
    $lines.Add((Format-BoxLine -Text ($identity -join '   ') -Width $width))

    $cpuName = if ([string]::IsNullOrWhiteSpace($Report.CpuName)) { 'n/a' } else { $Report.CpuName }
    $hostLine = 'Host {0}    CPU {1}    {2} logical' -f $Report.HostName, $cpuName, $Report.LogicalProcessors
    $lines.Add((Format-BoxLine -Text $hostLine -Width $width))

    $uptime = $Report.Uptime
    $uptimeText = '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    $ipv4 = if ([string]::IsNullOrWhiteSpace($Report.IPv4)) { 'n/a' } else { $Report.IPv4 }
    $lines.Add((Format-BoxLine -Text ('Uptime {0}    IPv4 {1}' -f $uptimeText, $ipv4) -Width $width))

    $cpuNow = if ($Report.HasCpuSample) { '{0:N1}%' -f $Report.CpuPercent } else { 'n/a' }
    $memoryLine = 'Memory {0:N2} / {1:N2} GB    CPU now {2}' -f $Report.MemoryUsedGB, $Report.MemoryTotalGB, $cpuNow
    $lines.Add((Format-BoxLine -Text $memoryLine -Width $width))

    $driveText = if ($Report.HasDriveSample) {
        '{0} {1:N1}% of {2:N2} GB' -f $Report.SystemDrive, $Report.DriveUsedPercent, $Report.DriveTotalGB
    }
    else {
        '{0} n/a' -f $Report.SystemDrive
    }
    $sessions = if ($Report.HasInteractiveSessions) { [string] $Report.InteractiveSessions } else { 'n/a' }
    $usageLine = '{0}    Processes {1}    Sessions {2}' -f $driveText, $Report.ProcessCount, $sessions
    $lines.Add((Format-BoxLine -Text $usageLine -Width $width))
    $lines.Add((Format-BoxRule -Width $width))
    $lines.Add((Format-BoxLine -Text 'Top processes by working set' -Width $width))

    $inner = $width - 4
    $pidWidth = 8
    $cpuWidth = 8
    $memWidth = 10
    $nameWidth = $inner - ($pidWidth + $cpuWidth + $memWidth + 6)
    if ($nameWidth -lt 8) {
        $nameWidth = 8
    }

    $header = '{0}  {1}  {2}  {3}' -f @(
        (Format-FitText -Text 'Name' -Width $nameWidth).PadRight($nameWidth)
        (Format-FitText -Text 'CPU(s)' -Width $cpuWidth).PadLeft($cpuWidth)
        (Format-FitText -Text 'Mem(MB)' -Width $memWidth).PadLeft($memWidth)
        (Format-FitText -Text 'PID' -Width $pidWidth).PadLeft($pidWidth)
    )
    $lines.Add((Format-BoxLine -Text $header -Width $width))

    $top = @($Report.TopProcesses)
    if ($top.Count -eq 0) {
        $lines.Add((Format-BoxLine -Text 'No process data' -Width $width))
    }
    else {
        foreach ($process in $top) {
            $row = '{0}  {1}  {2}  {3}' -f @(
                (Format-FitText -Text $process.Name -Width $nameWidth).PadRight($nameWidth)
                (Format-FitText -Text ('{0:N2}' -f $process.CpuSeconds) -Width $cpuWidth).PadLeft($cpuWidth)
                (Format-FitText -Text ('{0:N1}' -f $process.MemoryMB) -Width $memWidth).PadLeft($memWidth)
                (Format-FitText -Text ([string] $process.Id) -Width $pidWidth).PadLeft($pidWidth)
            )
            $lines.Add((Format-BoxLine -Text $row -Width $width))
        }
    }

    $lines.Add((Format-BoxRule -Width $width))
    return ($lines -join "`n")
}

function Get-SystemUptime {
    <#
    .SYNOPSIS
        Returns the time since the operating system last booted.
    .DESCRIPTION
        The result is an object. Its default display matches the previous
        uptime sentence, and Elapsed is a TimeSpan for scripts.
    .EXAMPLE
        uptime
    .EXAMPLE
        (Get-SystemUptime).Elapsed.TotalHours
    #>
    [CmdletBinding()]
    [OutputType([SystemUptime])]
    param()

    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $uptime = [SystemUptime]::new()
    $uptime.LastBoot = [datetime] $operatingSystem.LastBootUpTime
    $uptime.Elapsed = (Get-Date) - $uptime.LastBoot
    Add-ProfileTypeName -Object $uptime -TypeName 'Profile.SystemUptime'
    $uptime
}

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
    [OutputType([DiskVolume])]
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

function Get-ProcessDetail {
    <#
    .SYNOPSIS
        Returns process objects with CPU time and working-set memory.
    .DESCRIPTION
        CPU is cumulative processor seconds, not a live percentage.
        File path and description are omitted unless -IncludeFileInfo is set,
        because reading them touches every image and can be slow or denied.
    .PARAMETER Name
        One or more process names. Wildcards are allowed.
    .PARAMETER Top
        Return only this many processes after sorting.
    .PARAMETER OrderBy
        Sort key used with -Top. Memory is the default when -Top is set.
    .PARAMETER IncludeFileInfo
        Adds Path and Description. Access-denied values are left empty.
    .EXAMPLE
        proc -Top 10
    .EXAMPLE
        Get-ProcessDetail -Name explorer -IncludeFileInfo
    #>
    [CmdletBinding()]
    [OutputType([ProcessDetail])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Name,

        [ValidateRange(1, 500)]
        [int] $Top,

        [ValidateSet('Memory', 'CpuTime', 'Name', 'Id')]
        [string] $OrderBy = 'Memory',

        [switch] $IncludeFileInfo
    )

    $query = @{ ErrorAction = 'SilentlyContinue' }
    if ($Name) {
        $query.Name = $Name
    }

    $processes = @(Get-Process @query)
    $shouldSort = $PSBoundParameters.ContainsKey('Top') -or $PSBoundParameters.ContainsKey('OrderBy')
    if ($shouldSort) {
        switch ($OrderBy) {
            'CpuTime' { $processes = @($processes | Sort-Object { try { $_.CPU } catch { 0 } } -Descending) }
            'Name' { $processes = @($processes | Sort-Object Name) }
            'Id' { $processes = @($processes | Sort-Object Id) }
            default { $processes = @($processes | Sort-Object WorkingSet64 -Descending) }
        }
    }

    if ($PSBoundParameters.ContainsKey('Top')) {
        $processes = @($processes | Select-Object -First $Top)
    }

    foreach ($process in $processes) {
        $numbers = Get-ProcessNumbers -Process $process
        $detail = [ProcessDetail]::new()
        $detail.Id = [int] $process.Id
        $detail.Name = [string] $process.Name
        $detail.CpuSeconds = $numbers.CpuSeconds
        $detail.MemoryMB = $numbers.MemoryMB
        $detail.ThreadCount = $numbers.ThreadCount
        if ($IncludeFileInfo) {
            $detail.Path = Get-SafeProcessText -Process $process -PropertyName 'Path'
            $detail.Description = Get-SafeProcessText -Process $process -PropertyName 'Description'
        }
        else {
            $detail.Path = ''
            $detail.Description = ''
        }

        Add-ProfileTypeName -Object $detail -TypeName 'Profile.ProcessDetail'
        $detail
    }
}

function Get-SystemReport {
    <#
    .SYNOPSIS
        Returns a snapshot of the local machine.
    .DESCRIPTION
        The default view is a text report. The object itself stays pipeable.
        CPU now is a formatted performance counter. Process CPU in the table
        is cumulative processor seconds. Windows release comes from the
        current-version registry key, so it does not need a hardcoded build map.
    .PARAMETER Top
        How many processes to include, ordered by working set. Use 0 to skip
        the process list.
    .EXAMPLE
        sysinfo
    .EXAMPLE
        (Get-SystemReport).MemoryUsedGB
    #>
    [CmdletBinding()]
    [OutputType([SystemReport])]
    param(
        [ValidateRange(0, 50)]
        [int] $Top = 10
    )

    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $report = [SystemReport]::new()
    $report.ProductName = [string] $operatingSystem.Caption
    $report.Architecture = [string] $operatingSystem.OSArchitecture
    $report.Build = [string] $operatingSystem.BuildNumber
    $report.DisplayVersion = ''
    $report.TopProcesses = [ProcessSnapshot[]]::new(0)
    $report.Uptime = (Get-Date) - [datetime] $operatingSystem.LastBootUpTime

    $totalKilobytes = [int64] $operatingSystem.TotalVisibleMemorySize
    $freeKilobytes = [int64] $operatingSystem.FreePhysicalMemory
    if ($freeKilobytes -gt $totalKilobytes) {
        $freeKilobytes = $totalKilobytes
    }

    $usedKilobytes = $totalKilobytes - $freeKilobytes
    $report.MemoryTotalGB = [math]::Round(($totalKilobytes * 1KB) / 1GB, 2)
    $report.MemoryFreeGB = [math]::Round(($freeKilobytes * 1KB) / 1GB, 2)
    $report.MemoryUsedGB = [math]::Round(($usedKilobytes * 1KB) / 1GB, 2)

    try {
        $version = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        if ($version.CurrentBuild) {
            $report.Build = [string] $version.CurrentBuild
        }
        if ($null -ne $version.UBR -and -not [string]::IsNullOrEmpty($report.Build)) {
            $report.Build = '{0}.{1}' -f $report.Build, $version.UBR
        }
        if ($version.DisplayVersion) {
            $report.DisplayVersion = [string] $version.DisplayVersion
        }
    }
    catch {
        Write-Verbose "Windows version registry key was not read: $($_.Exception.Message)"
    }

    $report.HostName = [string] $env:COMPUTERNAME
    $report.CpuName = ''
    $report.LogicalProcessors = 0
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($computer.Name) {
            $report.HostName = [string] $computer.Name
        }
    }
    catch {
        Write-Verbose "Computer system data was not read: $($_.Exception.Message)"
    }

    try {
        $processors = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)
        $names = New-Object System.Collections.Generic.List[string]
        $logical = 0
        foreach ($processor in $processors) {
            $name = [string] $processor.Name
            if (-not [string]::IsNullOrWhiteSpace($name) -and -not $names.Contains($name.Trim())) {
                $names.Add($name.Trim())
            }
            $logical += [int] $processor.NumberOfLogicalProcessors
        }
        $report.CpuName = $names -join ' / '
        $report.LogicalProcessors = $logical
    }
    catch {
        Write-Verbose "Processor data was not read: $($_.Exception.Message)"
    }

    $report.HasCpuSample = $false
    $report.CpuPercent = 0
    try {
        $sample = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name = '_Total'" -ErrorAction Stop
        if ($null -ne $sample.PercentProcessorTime) {
            $report.CpuPercent = [math]::Round([double] $sample.PercentProcessorTime, 1)
            $report.HasCpuSample = $true
        }
    }
    catch {
        Write-Verbose "CPU sample was not read: $($_.Exception.Message)"
    }

    $report.IPv4 = [string] (Get-PreferredIPv4)

    $report.SystemDrive = 'C:'
    if ($env:SystemDrive -match '^[A-Za-z]:$') {
        $report.SystemDrive = $env:SystemDrive.ToUpperInvariant()
    }

    $report.HasDriveSample = $false
    $report.DriveTotalGB = 0
    $report.DriveUsedPercent = 0
    try {
        $driveFilter = "DeviceID = '{0}'" -f $report.SystemDrive
        $drive = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter $driveFilter -ErrorAction Stop) | Select-Object -First 1
        if ($drive -and $null -ne $drive.Size -and [int64] $drive.Size -gt 0 -and $null -ne $drive.FreeSpace) {
            $size = [int64] $drive.Size
            $free = [int64] $drive.FreeSpace
            if ($free -gt $size) {
                $free = $size
            }
            $report.DriveTotalGB = ConvertTo-Gigabytes -Bytes $size
            $report.DriveUsedPercent = [math]::Round((100.0 * ($size - $free)) / $size, 1)
            $report.HasDriveSample = $true
        }
    }
    catch {
        Write-Verbose "System drive data was not read: $($_.Exception.Message)"
    }

    $processes = @(Get-Process -ErrorAction SilentlyContinue)
    $report.ProcessCount = $processes.Count
    if ($Top -gt 0 -and $processes.Count -gt 0) {
        $busiest = @($processes | Sort-Object WorkingSet64 -Descending | Select-Object -First $Top)
        $snapshots = New-Object System.Collections.Generic.List[ProcessSnapshot]
        foreach ($process in $busiest) {
            $numbers = Get-ProcessNumbers -Process $process
            $snapshot = [ProcessSnapshot]::new()
            $snapshot.Id = [int] $process.Id
            $snapshot.Name = [string] $process.Name
            $snapshot.CpuSeconds = $numbers.CpuSeconds
            $snapshot.MemoryMB = $numbers.MemoryMB
            Add-ProfileTypeName -Object $snapshot -TypeName 'Profile.ProcessSnapshot'
            $snapshots.Add($snapshot)
        }
        $report.TopProcesses = $snapshots.ToArray()
    }

    $report.HasInteractiveSessions = $false
    $report.InteractiveSessions = 0
    try {
        $explorers = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop)
        $sessions = New-Object 'System.Collections.Generic.HashSet[int]'
        foreach ($explorer in $explorers) {
            [void] $sessions.Add([int] $explorer.SessionId)
        }
        $report.InteractiveSessions = $sessions.Count
        $report.HasInteractiveSessions = $true
    }
    catch {
        Write-Verbose "Interactive sessions were not read: $($_.Exception.Message)"
    }

    Add-ProfileTypeName -Object $report -TypeName 'Profile.SystemReport'
    $report
}

Set-Alias -Name uptime -Value Get-SystemUptime
Set-Alias -Name df -Value Get-DiskUsage
Set-Alias -Name proc -Value Get-ProcessDetail
Set-Alias -Name sysinfo -Value Get-SystemReport
