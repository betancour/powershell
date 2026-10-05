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
