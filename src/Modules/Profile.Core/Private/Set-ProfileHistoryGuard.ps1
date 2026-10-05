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
