function Test-WorldWritableDirectory {
    param([Parameter(Mandatory)][string] $Path)

    try {
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        return $true
    }

    $writeRights = [System.Security.AccessControl.FileSystemRights]'Write,Modify,FullControl,WriteData,CreateFiles,AppendData'
    foreach ($ace in @($acl.Access)) {
        if ($ace.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            continue
        }

        $writes = [int] $ace.FileSystemRights -band [int] $writeRights
        if ($writes -eq 0) {
            continue
        }

        $identity = [string] $ace.IdentityReference.Value
        if ($identity -match '(?i)(^|\\)(Everyone|Users|Authenticated Users)$') {
            return $true
        }
    }

    return $false
}

function Add-ProfilePathEntry {
    param([Parameter(Mandatory)][string] $Entry)

    if ([string]::IsNullOrWhiteSpace($Entry)) {
        return
    }

    if (-not [System.IO.Path]::IsPathRooted($Entry)) {
        Write-Warning "PATH entry must be absolute and was ignored: $Entry"
        return
    }

    if ($Entry.StartsWith('\\') -or $Entry.StartsWith('//')) {
        Write-Warning "UNC PATH entry was ignored: $Entry"
        return
    }

    if (-not (Test-Path -LiteralPath $Entry -PathType Container)) {
        Write-Verbose "PATH entry does not exist and was ignored: $Entry"
        return
    }

    $full = [System.IO.Path]::GetFullPath($Entry)
    $root = [System.IO.Path]::GetPathRoot($full)
    if ([string]::Equals($full.TrimEnd('\'), $root.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "Refusing to add a drive root to PATH: $full"
        return
    }

    if (Test-WorldWritableDirectory -Path $full) {
        Write-Warning "PATH entry is world-writable and was ignored: $full"
        return
    }

    $separator = [string] [System.IO.Path]::PathSeparator
    $current = [Environment]::GetEnvironmentVariable('Path', 'Process')
    if ([string]::IsNullOrEmpty($current)) {
        $current = ''
    }

    $parts = @($current -split [regex]::Escape([string] $separator))
    foreach ($part in $parts) {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }

        $normalized = $part.Trim().TrimEnd('\')
        if ([string]::Equals($normalized, $full.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }

    $updated = if ([string]::IsNullOrEmpty($current)) { $full } else { $current.TrimEnd($separator) + $separator + $full }
    [Environment]::SetEnvironmentVariable('Path', $updated, 'Process')
}
