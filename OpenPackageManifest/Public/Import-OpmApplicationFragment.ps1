<#
.SYNOPSIS
  Load a PacKit application fragment from a .packit metadata folder (or a file).

.DESCRIPTION
  Reads a fragment written by PacKit or by Export-OpmApplicationFragment and
  returns a 'PacKit.ApplicationFragment' object you can inspect, modify and
  re-save.

  Two ways to locate the fragment:
    -SourceFolder <dir>  (default) -> reads <dir>\.packit\<AppId>.xml when -AppId
                                      is given, otherwise the first *.xml in
                                      <dir>\.packit (sorted by name), matching
                                      PacKit's own fragment discovery.
    -LiteralPath <file>           -> reads exactly that file.

.EXAMPLE
  $app = Import-OpmApplicationFragment -SourceFolder 'C:\src\Acme'

.EXAMPLE
  Import-OpmApplicationFragment -LiteralPath '.\out\app.xml'
#>
function Import-OpmApplicationFragment {
    [CmdletBinding(DefaultParameterSetName = 'BySourceFolder')]
    [OutputType('PacKit.ApplicationFragment')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'BySourceFolder', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceFolder,

        [Parameter(ParameterSetName = 'BySourceFolder')]
        [string] $AppId,

        [Parameter(Mandatory, ParameterSetName = 'ByLiteralPath')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    if ($PSCmdlet.ParameterSetName -eq 'BySourceFolder') {
        $opmFolder = Join-Path $SourceFolder (Get-OpmSchema).OpmFolderName
        if (-not (Test-Path -LiteralPath $opmFolder)) {
            throw "No .packit folder found under '$SourceFolder' (expected '$opmFolder')."
        }

        if (-not [string]::IsNullOrEmpty($AppId)) {
            $parsed = [guid]::Empty
            if (-not [guid]::TryParse($AppId, [ref] $parsed)) {
                throw "AppId '$AppId' is not a valid GUID."
            }
            $file = Join-Path $opmFolder ($parsed.ToString('B').ToUpperInvariant() + '.xml')
        }
        else {
            $xmlFiles = @(Get-ChildItem -LiteralPath $opmFolder -Filter '*.xml' -File -ErrorAction SilentlyContinue | Sort-Object Name)
            if ($xmlFiles.Count -eq 0) {
                throw "No *.xml application fragment found in '$opmFolder'."
            }
            $file = $xmlFiles[0].FullName
        }
    }
    else {
        $file = $LiteralPath
    }

    if (-not (Test-Path -LiteralPath $file)) {
        throw "PacKit fragment file not found: '$file'."
    }

    $text = [System.IO.File]::ReadAllText($file)
    return ConvertFrom-OpmXmlString -Xml $text
}
