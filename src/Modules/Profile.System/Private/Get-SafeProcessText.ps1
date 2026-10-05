function Get-SafeProcessText {
    param(
        $Process,
        [string] $PropertyName
    )

    try {
        $value = $Process.$PropertyName
        if ($null -eq $value) {
            return ''
        }

        return [string] $value
    }
    catch {
        return ''
    }
}
