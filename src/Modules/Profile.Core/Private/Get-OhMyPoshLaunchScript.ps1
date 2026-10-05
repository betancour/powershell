function Get-OhMyPoshExecutable {
    $candidates = @(Get-Command -Name 'oh-my-posh' -CommandType Application -ErrorAction SilentlyContinue)
    foreach ($candidate in $candidates) {
        $source = [string] $candidate.Source
        if ([string]::IsNullOrWhiteSpace($source)) {
            continue
        }

        if (-not $source.EndsWith('oh-my-posh.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            continue
        }

        return [System.IO.Path]::GetFullPath($source)
    }

    return $null
}

function Get-OhMyPoshLaunchScript {
    param([string] $ConfigPath)

    if ($Host.Name -ne 'ConsoleHost') {
        return $null
    }

    $executable = Get-OhMyPoshExecutable
    if (-not $executable) {
        Write-Verbose 'oh-my-posh.exe was not found on PATH.'
        return $null
    }

    $theme = Resolve-ThemeConfigPath -Path $ConfigPath
    if (-not $theme) {
        return $null
    }

    $previousEncoding = $OutputEncoding
    $previousNativePreference = $null
    $hasNativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    if ($hasNativePreference) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $output = & $executable init pwsh --config $theme
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "oh-my-posh init exited with code $LASTEXITCODE. The fallback prompt was kept."
            return $null
        }
    }
    catch {
        Write-Warning "oh-my-posh init failed: $($_.Exception.Message)"
        return $null
    }
    finally {
        $OutputEncoding = $previousEncoding
        if ($hasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }

    $text = if ($null -eq $output) {
        ''
    }
    elseif ($output -is [System.Array]) {
        $output -join "`n"
    }
    else {
        [string] $output
    }

    $text = $text.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-Warning 'oh-my-posh init returned an empty script. The fallback prompt was kept.'
        return $null
    }

    # The official launcher is a short session script plus a call into oh-my-posh's
    # own cached init file. Refuse anything large enough to be an inlined eval.
    if ($text.Length -gt 16384) {
        Write-Warning 'oh-my-posh init returned an unexpectedly large script. The fallback prompt was kept.'
        return $null
    }

    if ($text -notmatch 'POSH_SESSION_ID') {
        Write-Warning 'oh-my-posh init did not return a session launcher. The fallback prompt was kept.'
        return $null
    }

    return $text
}
