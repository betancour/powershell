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
