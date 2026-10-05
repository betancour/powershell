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

# Formatters stay in this file. SystemReport.ToDisplayString calls them, and a
# class method must see those commands in the same module file on Windows PowerShell 5.1.

$private = @(
    'Add-ProfileTypeName.ps1'
    'ConvertTo-Gigabytes.ps1'
    'Get-ProcessNumbers.ps1'
    'Get-SafeProcessText.ps1'
    'Get-PreferredIPv4.ps1'
    'New-DiskVolume.ps1'
)

foreach ($name in $private) {
    . (Join-Path (Join-Path $PSScriptRoot 'Private') $name)
}

$public = @(
    'Get-SystemUptime.ps1'
    'Get-DiskUsage.ps1'
    'Get-ProcessDetail.ps1'
    'Get-SystemReport.ps1'
)

foreach ($name in $public) {
    . (Join-Path (Join-Path $PSScriptRoot 'Public') $name)
}

Set-Alias -Name uptime -Value Get-SystemUptime
Set-Alias -Name df -Value Get-DiskUsage
Set-Alias -Name proc -Value Get-ProcessDetail
Set-Alias -Name sysinfo -Value Get-SystemReport
