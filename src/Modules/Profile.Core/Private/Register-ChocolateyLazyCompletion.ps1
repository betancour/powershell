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
