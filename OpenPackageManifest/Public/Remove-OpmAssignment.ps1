<#
.SYNOPSIS
  Remove an Intune assignment from a PacKit fragment by Entra group id.

.DESCRIPTION
  Removes every assignment whose MsEntraGroupId matches from the fragment's
  IntuneAssignments collection. The fragment is modified in place.

.EXAMPLE
  Remove-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
#>
function Remove-OpmAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MsEntraGroupId,

        [Parameter()] [switch] $PassThru
    )

    process {
        $target = ConvertTo-OpmCanonicalGuid -Value $MsEntraGroupId
        $before = @($Fragment.IntuneAssignments).Count
        $Fragment.IntuneAssignments = @($Fragment.IntuneAssignments | Where-Object { $_.MsEntraGroupId -ne $target })
        $after = @($Fragment.IntuneAssignments).Count

        if ($after -eq $before) {
            Write-Verbose "No assignment with MsEntraGroupId '$MsEntraGroupId' was found; nothing removed."
        }

        if ($PassThru) { return $Fragment }
    }
}
