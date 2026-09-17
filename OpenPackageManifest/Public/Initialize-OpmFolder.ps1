<#
.SYNOPSIS
  Create a .packit metadata folder (and its managed subfolders) under a source folder.

.DESCRIPTION
  Creates <SourceFolder>\.packit and the standard PacKit subfolders
  (icons, detection-scripts, psadt, intunewin, mecm, downloads, temp). This is
  the folder PacKit reads an application's fragment and resources from. The
  operation is idempotent. Pass -NoSubfolders to create only the .packit root.
  Returns the full path to the .packit folder.

.EXAMPLE
  $packit = Initialize-OpmFolder -SourceFolder 'C:\src\Acme'

.EXAMPLE
  'C:\src\Acme' | Initialize-OpmFolder
#>
function Initialize-OpmFolder {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceFolder,

        [Parameter()]
        [switch] $NoSubfolders
    )

    process {
        $schema = Get-OpmSchema
        $opmFolder = Join-Path $SourceFolder $schema.OpmFolderName

        if ($PSCmdlet.ShouldProcess($opmFolder, 'Create PacKit metadata folder')) {
            New-Item -ItemType Directory -Path $opmFolder -Force | Out-Null
            if (-not $NoSubfolders) {
                foreach ($sub in $schema.Subfolders) {
                    New-Item -ItemType Directory -Path (Join-Path $opmFolder $sub) -Force | Out-Null
                }
            }
        }

        return $opmFolder
    }
}
