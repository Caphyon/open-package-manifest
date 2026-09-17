<#
.SYNOPSIS
  Save a PacKit application fragment to a .opm metadata folder (or a file).

.DESCRIPTION
  Serializes a 'PacKit.ApplicationFragment' to the exact PacKit on-disk format
  (UTF-8 no BOM, CRLF, byte-faithful) so the PacKit app can load it.

  Two ways to choose the destination:
    -SourceFolder <dir>  (default) -> writes <dir>\.opm\<AppId>.xml, creating
                                      the .opm folder if needed. This is the
                                      "instrument an application" target.
    -LiteralPath <file>           -> writes exactly that file.

  By default path-bearing attributes are written verbatim, guaranteeing a clean
  Import->Export round-trip. Pass -RelativizePaths to rewrite any ABSOLUTE
  IconPath / detection-script / package Path / SourceFolder relative to the
  .opm folder (matching how PacKit itself stores them); already-relative
  values are left untouched and the input object is never mutated.

.EXAMPLE
  $app | Export-OpmApplicationFragment -SourceFolder 'C:\src\Acme'

.EXAMPLE
  Export-OpmApplicationFragment -Fragment $app -LiteralPath '.\out\app.xml' -WhatIf
#>
function Export-OpmApplicationFragment {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'BySourceFolder')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment,

        [Parameter(Mandatory, ParameterSetName = 'BySourceFolder', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceFolder,

        [Parameter(Mandatory, ParameterSetName = 'ByLiteralPath')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter()]
        [switch] $RelativizePaths,

        [Parameter()]
        [switch] $PassThru
    )

    process {
        if (-not (Test-OpmGuid -Value $Fragment.AppId)) {
            throw "Fragment AppId '$($Fragment.AppId)' is not a valid PacKit GUID (expected braced UPPERCASE form). Use New-OpmApplicationFragment to create one."
        }
        if ([string]::IsNullOrEmpty($Fragment.Name)) {
            throw 'Fragment Name must not be empty. PacKit requires a non-empty application name.'
        }

        if ($PSCmdlet.ParameterSetName -eq 'BySourceFolder') {
            $opmFolder = Join-Path $SourceFolder (Get-OpmSchema).OpmFolderName
            $target = Join-Path $opmFolder ($Fragment.AppId + '.xml')
        }
        else {
            $target = $LiteralPath
        }

        $toEmit = $Fragment
        if ($RelativizePaths) {
            $baseDir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($target))
            # Deep-clone via round-trip so the caller's object is never mutated.
            $toEmit = ConvertFrom-OpmXmlString -Xml (ConvertTo-OpmXmlString -Fragment $Fragment)
            $toEmit.IconPath = Get-OpmRelativePath -BaseDirectory $baseDir -Path $toEmit.IconPath
            $toEmit.DetectionRule.ScriptPath = Get-OpmRelativePath -BaseDirectory $baseDir -Path $toEmit.DetectionRule.ScriptPath
            foreach ($pkg in @($toEmit.Packages)) {
                $pkg.Path = Get-OpmRelativePath -BaseDirectory $baseDir -Path $pkg.Path
                $pkg.SourceFolder = Get-OpmRelativePath -BaseDirectory $baseDir -Path $pkg.SourceFolder
            }
        }

        $xml = ConvertTo-OpmXmlString -Fragment $toEmit

        if ($PSCmdlet.ShouldProcess($target, 'Write PacKit application fragment')) {
            $written = Write-OpmBytes -Path $target -Content $xml
            if ($PassThru) { return $Fragment }
            return $written
        }
    }
}
