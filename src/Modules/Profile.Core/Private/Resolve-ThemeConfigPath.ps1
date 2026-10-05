function Resolve-ThemeConfigPath {
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Verbose "Theme config was not found: $Path"
        return $null
    }

    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full -notmatch '\.omp\.json$') {
        Write-Warning "Theme config must end with .omp.json and was ignored: $full"
        return $null
    }

    $homeRoot = $env:HOME
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE) -and -not [string]::IsNullOrWhiteSpace($homeRoot)) {
        $sameRoot = [string]::Equals(
            $homeRoot.TrimEnd('\', '/'),
            $env:USERPROFILE.TrimEnd('\', '/'),
            [System.StringComparison]::OrdinalIgnoreCase
        )
        if (-not $sameRoot -and -not (Test-ChildPath -Path $homeRoot -Root $env:USERPROFILE)) {
            # Ignore a HOME that points outside the Windows user profile.
            $homeRoot = $null
        }
    }

    $roots = @(
        $env:USERPROFILE
        $homeRoot
        $env:OneDrive
        $env:OneDriveConsumer
        $env:OneDriveCommercial
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($root in $roots) {
        if (Test-ChildPath -Path $full -Root $root) {
            return $full
        }
    }

    Write-Warning "Theme config is outside the user profile and was ignored: $full"
    return $null
}
