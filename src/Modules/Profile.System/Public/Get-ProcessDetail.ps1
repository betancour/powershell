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
    [OutputType('ProcessDetail')]
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
