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
    [OutputType('SystemReport')]
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
