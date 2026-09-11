<#
.SYNOPSIS
  Update application-level fields on a PacKit application fragment (in place).

.DESCRIPTION
  Only the parameters you supply are changed; everything else is left untouched.
  The fragment is modified in place; use -PassThru to emit it for pipeline
  chaining.

.EXAMPLE
  Set-PacKitApplication -Fragment $app -Vendor 'Acme Corporation' -OperatingSysArchitecture 'x64'
#>
function Set-PacKitApplication {
    [CmdletBinding()]
    [OutputType('PacKit.ApplicationFragment')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter()] [string] $Name,
        [Parameter()] [string] $Vendor,
        [Parameter()] [string] $Description,
        [Parameter()] [string] $IconPath,
        [Parameter()] [string] $OperatingSys,
        [Parameter()] [string] $OperatingSysArchitecture,
        [Parameter()] [long]   $WinGetAppScannedAt,
        [Parameter()] [bool]   $Unseen,
        [Parameter()] [string] $ReturnCodesJson,
        [Parameter()] [string] $ScopeTagId,

        [Parameter()] [switch] $PassThru
    )

    process {
        if ($PSBoundParameters.ContainsKey('Name') -and [string]::IsNullOrEmpty($Name)) {
            throw 'Name must not be empty.'
        }

        foreach ($prop in @('Name', 'Vendor', 'Description', 'IconPath', 'OperatingSys',
                'OperatingSysArchitecture', 'WinGetAppScannedAt', 'Unseen', 'ReturnCodesJson', 'ScopeTagId')) {
            if ($PSBoundParameters.ContainsKey($prop)) {
                $Fragment.$prop = $PSBoundParameters[$prop]
            }
        }

        if ($PassThru) { return $Fragment }
    }
}
