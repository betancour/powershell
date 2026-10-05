Set-StrictMode -Version 1.0

$script:ChocolateyProfileLoaded = $false
$script:CommandStubsInstalled = $false

function Test-ChildPath {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Root
    )

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        $fullRoot = [System.IO.Path]::GetFullPath($Root)
    }
    catch {
        return $false
    }

    $prefix = $fullRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    return $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ProfileSettings {
    param([string] $SettingsPath)

    $defaults = @{
        ThemeConfig                 = $null
        PathEntries                 = @()
        EnableChocolateyCompletion  = $true
        HostColor                   = @{
            ErrorForegroundColor   = 'Red'
            WarningForegroundColor = 'Yellow'
            VerboseForegroundColor = 'Green'
            DebugForegroundColor   = 'Magenta'
        }
    }

    if ([string]::IsNullOrWhiteSpace($SettingsPath) -or -not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return $defaults
    }

    try {
        $loaded = Import-PowerShellDataFile -LiteralPath $SettingsPath -ErrorAction Stop
    }
    catch {
        Write-Warning "Profile settings were not loaded: $($_.Exception.Message)"
        return $defaults
    }

    foreach ($key in @($defaults.Keys)) {
        if ($loaded.ContainsKey($key) -and $null -ne $loaded[$key]) {
            $defaults[$key] = $loaded[$key]
        }
    }

    return $defaults
}

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

function Set-ProfileHostColor {
    param($HostColor)

    if ($Host.Name -ne 'ConsoleHost') {
        return
    }

    if ($null -eq $HostColor) {
        return
    }

    $allowed = @([Enum]::GetNames([System.ConsoleColor]))
    $privateData = $Host.PrivateData
    if ($null -eq $privateData) {
        return
    }

    foreach ($propertyName in @($HostColor.Keys)) {
        $colorName = [string] $HostColor[$propertyName]
        $match = $allowed | Where-Object { $_ -eq $colorName } | Select-Object -First 1
        if (-not $match) {
            Write-Verbose "Unknown console color '$colorName' for $propertyName."
            continue
        }

        if (-not ($privateData.PSObject.Properties.Name -contains $propertyName)) {
            continue
        }

        try {
            $privateData.$propertyName = $match
        }
        catch {
            Write-Verbose "Host color $propertyName was not applied: $($_.Exception.Message)"
        }
    }
}

function Set-ProfileHistoryGuard {
    if ($Host.Name -ne 'ConsoleHost') {
        return
    }

    # Do not call Get-Command here. That autoloads PSReadLine and spends the
    # startup time this profile is trying to avoid. PowerShell 7 already loads
    # it for an interactive console. Windows PowerShell 5.1 usually loads it
    # on first use, so the guard waits until then.
    if (-not (Get-Module -Name PSReadLine)) {
        return
    }

    $command = Get-Command -Name 'Set-PSReadLineOption' -ErrorAction SilentlyContinue
    if (-not $command -or -not $command.Parameters.ContainsKey('AddToHistoryHandler')) {
        return
    }

    # The pattern lives inside the handler. A scriptblock looks up variables
    # when it runs, so a pattern stored in this function would already be gone.
    Set-PSReadLineOption -AddToHistoryHandler {
        param([string] $Line)

        if ([string]::IsNullOrWhiteSpace($Line)) {
            return $false
        }

        $secretParameter = '(?i)((^|\s)--?(password|passwd|pwd|secret|token|apikey|api-key|access-key|private-key)\b)|((password|passwd|pwd|secret|token|apikey|api_key|api-key|access_key|private_key|authorization)\s*[:=])'
        $bearer = '(?i)\bbearer\s+[A-Za-z0-9\-\._~\+/]+=*'
        $privateKey = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
        return $Line -notmatch $secretParameter -and $Line -notmatch $bearer -and $Line -notmatch $privateKey
    }
}

function Set-FallbackPrompt {
    if ($Host.Name -ne 'ConsoleHost') {
        return
    }

    $identity = $env:USERNAME
    if ([string]::IsNullOrWhiteSpace($identity)) {
        $identity = $env:USER
    }

    try {
        $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($windowsIdentity -and -not [string]::IsNullOrWhiteSpace($windowsIdentity.Name)) {
            $identity = $windowsIdentity.Name
        }
    }
    catch {
        # WindowsIdentity is not available on every runtime. Keep the environment name.
    }

    if ([string]::IsNullOrWhiteSpace($identity)) {
        $identity = 'user'
    }

    $global:ProfilePromptIdentity = $identity
    function global:prompt {
        $identity = $global:ProfilePromptIdentity
        Write-Host "[$identity] " -NoNewline -ForegroundColor Cyan
        Write-Host "$((Get-Location).Path) " -NoNewline -ForegroundColor Green
        '> '
    }
}

function Install-ChocolateyCommandStub {
    param([Parameter(Mandatory)][string] $Name)

    if (Test-Path -LiteralPath "Function:\global:$Name") {
        return
    }

    $stub = {
        $commandName = $MyInvocation.MyCommand.Name
        Remove-Item -LiteralPath "Function:\global:$commandName" -Force -ErrorAction SilentlyContinue

        $loaded = Enable-ChocolateyCompletion
        if (-not $loaded) {
            Install-ChocolateyCommandStub -Name $commandName
            Write-Error "Chocolatey profile was not loaded, so '$commandName' is unavailable."
            return
        }

        $resolved = Get-Command -Name $commandName -ErrorAction SilentlyContinue
        if ($resolved) {
            & $resolved @args
            return
        }

        Write-Error "Chocolatey did not define '$commandName'."
    }

    Set-Item -Path "Function:\global:$Name" -Value $stub
}

function Get-ChocolateyProfilePath {
    param([Parameter(Mandatory)][string] $InstallRoot)

    Join-Path (Join-Path $InstallRoot 'helpers') 'chocolateyProfile.psm1'
}

function Register-ChocolateyLazyCompletion {
    if ($script:CommandStubsInstalled) {
        return
    }

    $installRoot = $env:ChocolateyInstall
    if ([string]::IsNullOrWhiteSpace($installRoot)) {
        return
    }

    $modulePath = Get-ChocolateyProfilePath -InstallRoot $installRoot
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        return
    }

    Install-ChocolateyCommandStub -Name 'refreshenv'
    Install-ChocolateyCommandStub -Name 'Update-SessionEnvironment'
    # The completer must be registered from the profile scope. Registering it
    # from this module does not attach it to the interactive session.
    $global:ProfileUseChocolateyCompleter = $true
    $script:CommandStubsInstalled = $true
}

function Complete-ChocolateyArgument {
    param([string] $WordToComplete)

    if ($global:ProfileChocolateyCompleterReady) {
        return
    }

    $loaded = Enable-ChocolateyCompletion
    # One attempt per session. A broken install should not warn on every Tab.
    $global:ProfileChocolateyCompleterReady = $true
    if (-not $loaded) {
        return
    }

    if ([string]::IsNullOrEmpty($WordToComplete)) {
        $WordToComplete = ''
    }

    $commands = @(
        'apikey', 'cache', 'config', 'feature', 'help', 'info', 'install',
        'list', 'outdated', 'pin', 'search', 'source', 'uninstall', 'upgrade'
    )

    foreach ($command in $commands) {
        if ($command.StartsWith($WordToComplete, [System.StringComparison]::OrdinalIgnoreCase)) {
            [System.Management.Automation.CompletionResult]::new(
                $command,
                $command,
                [System.Management.Automation.CompletionResultType]::ParameterValue,
                $command
            )
        }
    }
}

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

function Initialize-ProfileShell {
    <#
    .SYNOPSIS
        Applies the cheap, safe part of the personal profile.
    .DESCRIPTION
        Sets host colors, a secret-aware history filter, optional PATH entries,
        a fallback prompt, and lazy Chocolatey completion. Returns the oh-my-posh
        launcher text so the profile script can run it in the global scope.
        Execution policy is not changed.
    .OUTPUTS
        System.String. Empty when oh-my-posh is not started.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $SettingsPath
    )

    $settings = Get-ProfileSettings -SettingsPath $SettingsPath

    try {
        Set-ProfileHostColor -HostColor $settings.HostColor
    }
    catch {
        Write-Warning "Host colors were not applied: $($_.Exception.Message)"
    }

    try {
        Set-ProfileHistoryGuard
    }
    catch {
        Write-Warning "History filter was not applied: $($_.Exception.Message)"
    }

    foreach ($entry in @($settings.PathEntries)) {
        try {
            Add-ProfilePathEntry -Entry ([string] $entry)
        }
        catch {
            Write-Warning "PATH entry '$entry' was not applied: $($_.Exception.Message)"
        }
    }

    try {
        Set-FallbackPrompt
    }
    catch {
        Write-Warning "Fallback prompt was not installed: $($_.Exception.Message)"
    }

    if ($settings.EnableChocolateyCompletion) {
        try {
            Register-ChocolateyLazyCompletion
        }
        catch {
            Write-Warning "Chocolatey completion was not registered: $($_.Exception.Message)"
        }
    }

    try {
        return (Get-OhMyPoshLaunchScript -ConfigPath ([string] $settings.ThemeConfig))
    }
    catch {
        Write-Warning "oh-my-posh was not initialized: $($_.Exception.Message)"
        return $null
    }
}
