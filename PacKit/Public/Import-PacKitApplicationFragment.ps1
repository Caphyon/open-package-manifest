<#
.SYNOPSIS
  Load a PacKit application fragment from a .packit metadata folder (or a file).

.DESCRIPTION
  Reads a fragment written by PacKit or by Export-PacKitApplicationFragment and
  returns a 'PacKit.ApplicationFragment' object you can inspect, modify and
  re-save.

  Two ways to locate the fragment:
    -SourceFolder <dir>  (default) -> reads <dir>\.packit\<AppId>.xml when -AppId
                                      is given, otherwise the first *.xml in
                                      <dir>\.packit (sorted by name), matching
                                      PacKit's own fragment discovery.
    -LiteralPath <file>           -> reads exactly that file.

  Path-bearing attributes (IconPath, DetectionRule.ScriptPath, package Path and
  SourceFolder) are stored on disk relative to the .packit folder and are
  returned verbatim by default, so a load->save round-trip stays byte-identical.
  Pass -ResolvePaths to resolve any relative values to full, absolute paths
  (anchored at the .packit folder) on the returned object - useful when you need
  to consume the paths directly (e.g. to read the referenced installer file)
  rather than re-export the fragment.

.EXAMPLE
  $app = Import-PacKitApplicationFragment -SourceFolder 'C:\src\Acme'

.EXAMPLE
  Import-PacKitApplicationFragment -LiteralPath '.\out\app.xml'

.EXAMPLE
  $app = Import-PacKitApplicationFragment -SourceFolder 'C:\src\Acme' -ResolvePaths
  $app.Packages[0].Path # full, absolute path to the installer
#>
function Import-PacKitApplicationFragment {
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
        [string] $LiteralPath,

        [Parameter()]
        [switch] $ResolvePaths
    )

    if ($PSCmdlet.ParameterSetName -eq 'BySourceFolder') {
        $packitFolder = Join-Path $SourceFolder (Get-PacKitSchema).PackitFolderName
        if (-not (Test-Path -LiteralPath $packitFolder)) {
            throw "No .packit folder found under '$SourceFolder' (expected '$packitFolder')."
        }

        if (-not [string]::IsNullOrEmpty($AppId)) {
            $parsed = [guid]::Empty
            if (-not [guid]::TryParse($AppId, [ref] $parsed)) {
                throw "AppId '$AppId' is not a valid GUID."
            }
            $file = Join-Path $packitFolder ($parsed.ToString('B').ToUpperInvariant() + '.xml')
        }
        else {
            $xmlFiles = @(Get-ChildItem -LiteralPath $packitFolder -Filter '*.xml' -File -ErrorAction SilentlyContinue | Sort-Object Name)
            if ($xmlFiles.Count -eq 0) {
                throw "No *.xml application fragment found in '$packitFolder'."
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
    $app = ConvertFrom-PacKitXmlString -Xml $text

    if ($ResolvePaths) {
        $baseDir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($file))
        $app.IconPath = Get-PacKitAbsolutePath -BaseDirectory $baseDir -Path $app.IconPath
        $app.DetectionRule.ScriptPath = Get-PacKitAbsolutePath -BaseDirectory $baseDir -Path $app.DetectionRule.ScriptPath
        foreach ($pkg in @($app.Packages)) {
            $pkg.Path = Get-PacKitAbsolutePath -BaseDirectory $baseDir -Path $pkg.Path
            $pkg.SourceFolder = Get-PacKitAbsolutePath -BaseDirectory $baseDir -Path $pkg.SourceFolder
        }
    }

    return $app
}
