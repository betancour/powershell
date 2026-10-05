function Add-ProfileTypeName {
    param(
        $Object,
        [string] $TypeName
    )

    if ($Object.PSObject.TypeNames -notcontains $TypeName) {
        [void] $Object.PSObject.TypeNames.Insert(0, $TypeName)
    }
}
