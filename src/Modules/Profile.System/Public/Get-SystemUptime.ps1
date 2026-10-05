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
    [OutputType('SystemUptime')]
    param()

    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $uptime = [SystemUptime]::new()
    $uptime.LastBoot = [datetime] $operatingSystem.LastBootUpTime
    $uptime.Elapsed = (Get-Date) - $uptime.LastBoot
    Add-ProfileTypeName -Object $uptime -TypeName 'Profile.SystemUptime'
    $uptime
}
