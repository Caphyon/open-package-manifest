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
  $packit = Initialize-PacKitFolder -SourceFolder 'C:\src\Acme'

.EXAMPLE
  'C:\src\Acme' | Initialize-PacKitFolder
#>
function Initialize-PacKitFolder {
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
        $schema = Get-PacKitSchema
        $packitFolder = Join-Path $SourceFolder $schema.PackitFolderName

        if ($PSCmdlet.ShouldProcess($packitFolder, 'Create PacKit metadata folder')) {
            New-Item -ItemType Directory -Path $packitFolder -Force | Out-Null
            if (-not $NoSubfolders) {
                foreach ($sub in $schema.Subfolders) {
                    New-Item -ItemType Directory -Path (Join-Path $packitFolder $sub) -Force | Out-Null
                }
            }
        }

        return $packitFolder
    }
}
