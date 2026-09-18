<#
.SYNOPSIS
  Create a new in-memory PacKit application fragment.

.DESCRIPTION
  Returns a 'PacKit.ApplicationFragment' object initialised with the supplied
  application-level fields. The AppId is generated as a braced UPPERCASE GUID
  (PacKit-compatible) unless one is supplied, in which case it is validated and
  normalised to the braced UPPERCASE form. Packages, the detection rule and
  Intune assignments start empty; add them with the Add-PacKit* / Set-PacKit*
  cmdlets, then persist with Export-OpmApplicationFragment.

.EXAMPLE
  $app = New-OpmApplicationFragment -Name 'Acme Reader' -Vendor 'Acme Corporation'

.EXAMPLE
  New-OpmApplicationFragment -Name 'Reader' -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
#>
function New-OpmApplicationFragment {
    [CmdletBinding()]
    [OutputType('PacKit.ApplicationFragment')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [string] $Vendor = '',

        [Parameter()]
        [string] $Description = '',

        [Parameter()]
        [string] $AppId,

        [Parameter()]
        [string] $IconPath = '',

        [Parameter()]
        [string] $OperatingSys = '',

        [Parameter()]
        [ValidateSet('', '32-bit', '64-bit')]
        [string] $OperatingSysArchitecture = ''
    )

    if ($PSBoundParameters.ContainsKey('AppId') -and -not [string]::IsNullOrEmpty($AppId)) {
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse($AppId, [ref] $parsed)) {
            throw "AppId '$AppId' is not a valid GUID. Provide a GUID such as {0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}."
        }
        $AppId = $parsed.ToString('B').ToUpperInvariant()
    }
    else {
        $AppId = New-OpmGuid
    }

    $app = New-OpmApplicationFragmentObject
    $app.AppId = $AppId
    $app.Name = $Name
    $app.Vendor = $Vendor
    $app.Description = $Description
    $app.IconPath = $IconPath
    $app.OperatingSys = $OperatingSys
    $app.OperatingSysArchitecture = $OperatingSysArchitecture

    return $app
}
