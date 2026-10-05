function Add-ProfileTypeName {
    param(
        $Object,
        [string] $TypeName
    )

    if ($Object.PSObject.TypeNames -notcontains $TypeName) {
        $Object.PSObject.TypeNames.Insert(0, $TypeName)
    }

    return $Object
}
