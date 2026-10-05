function Enable-ChocolateyCompletion {
    <#
    .SYNOPSIS
        Loads the Chocolatey profile once, after its path has been checked.
    .DESCRIPTION
        The startup script calls this on the first choco completion or the first
        refreshenv / Update-SessionEnvironment use. Importing it from the profile
        would slow every new shell.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($script:ChocolateyProfileLoaded) {
        return $true
    }

    $installRoot = $env:ChocolateyInstall
    if ([string]::IsNullOrWhiteSpace($installRoot)) {
        Write-Verbose 'ChocolateyInstall is not set.'
        return $false
    }

    if (-not (Test-Path -LiteralPath $installRoot -PathType Container)) {
        Write-Warning "ChocolateyInstall is not a directory: $installRoot"
        return $false
    }

    $rootFull = [System.IO.Path]::GetFullPath($installRoot)
    $modulePath = [System.IO.Path]::GetFullPath((Get-ChocolateyProfilePath -InstallRoot $rootFull))
    if (-not (Test-ChildPath -Path $modulePath -Root $rootFull)) {
        Write-Warning 'Refusing to load a Chocolatey profile outside ChocolateyInstall.'
        return $false
    }

    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        Write-Verbose "Chocolatey profile was not found: $modulePath"
        return $false
    }

    try {
        Import-Module -Name $modulePath -Global -DisableNameChecking -ErrorAction Stop
    }
    catch {
        Write-Warning "Chocolatey profile was not imported: $($_.Exception.Message)"
        return $false
    }

    $script:ChocolateyProfileLoaded = $true
    return $true
}
