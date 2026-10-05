function Update-FileStamp {
    <#
    .SYNOPSIS
        Creates an empty file or refreshes its timestamps.
    .DESCRIPTION
        Behaves like touch. Existing directories are rejected. Missing parent
        directories are not created. Paths are taken literally, so wildcard
        characters in a file name are preserved.
    .PARAMETER LiteralPath
        File path or paths. Pipeline input may supply FullName.
    .PARAMETER PassThru
        Returns the FileInfo after the update.
    .EXAMPLE
        touch .\notes.txt
    .EXAMPLE
        'a.txt', 'b.txt' | Update-FileStamp -PassThru
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'FullName')]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        [switch] $PassThru
    )

    process {
        foreach ($item in $LiteralPath) {
            if ([string]::IsNullOrWhiteSpace($item)) {
                continue
            }

            try {
                $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($item)
            }
            catch {
                $PSCmdlet.WriteError($_)
                continue
            }

            if (-not $PSCmdlet.ShouldProcess($full, 'Update file timestamp')) {
                continue
            }

            if (Test-Path -LiteralPath $full) {
                $existing = Get-Item -LiteralPath $full -Force
                if ($existing.PSIsContainer) {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.IO.IOException]::new("Path is a directory: $full"),
                        'PathIsDirectory',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $full
                    )
                    $PSCmdlet.WriteError($errorRecord)
                    continue
                }
            }
            else {
                $parent = [System.IO.Path]::GetDirectoryName($full)
                if (-not [string]::IsNullOrEmpty($parent) -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.IO.DirectoryNotFoundException]::new("Directory not found: $parent"),
                        'ParentNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $full
                    )
                    $PSCmdlet.WriteError($errorRecord)
                    continue
                }
            }

            try {
                $stream = [System.IO.File]::Open(
                    $full,
                    [System.IO.FileMode]::OpenOrCreate,
                    [System.IO.FileAccess]::ReadWrite,
                    [System.IO.FileShare]::ReadWrite
                )
                $stream.Dispose()

                $now = Get-Date
                [System.IO.File]::SetLastWriteTime($full, $now)
                [System.IO.File]::SetLastAccessTime($full, $now)
            }
            catch {
                $PSCmdlet.WriteError($_)
                continue
            }

            if ($PassThru) {
                Get-Item -LiteralPath $full -Force
            }
        }
    }
}
