<#
.SYNOPSIS
  Add an Intune (Microsoft Entra) group assignment to a PacKit fragment.

.DESCRIPTION
  Appends an assignment to the fragment's IntuneAssignments collection. The
  -MsEntraGroupId is the Entra group object id. -AssignmentType is typically
  'Required', 'Available' or 'Uninstall'; -InclusionType is 'Include' or
  'Exclude'. The fragment is modified in place.

.EXAMPLE
  Add-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D...}' -AssignmentType 'Required' -InclusionType 'Include'
#>
function Add-OpmAssignment {
    [CmdletBinding()]
    [OutputType('PacKit.Assignment')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MsEntraGroupId,

        [Parameter()] [string] $AssignmentType = '',
        [Parameter()] [string] $InclusionType = '',

        [Parameter()] [switch] $PassThru
    )

    process {
        $parsed = [guid]::Empty
        if (-not [guid]::TryParse($MsEntraGroupId, [ref] $parsed)) {
            throw "MsEntraGroupId '$MsEntraGroupId' is not a valid GUID. Entra group ids are GUIDs; provide one like {2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}."
        }

        $asg = New-OpmAssignmentObject
        $asg.MsEntraGroupId = $parsed.ToString('B').ToUpperInvariant()
        $asg.AssignmentType = $AssignmentType
        $asg.InclusionType = $InclusionType

        $Fragment.IntuneAssignments = @($Fragment.IntuneAssignments) + $asg

        if ($PassThru) { return $asg }
    }
}
