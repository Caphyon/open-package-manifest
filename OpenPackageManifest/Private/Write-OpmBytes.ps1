<#
.SYNOPSIS
  Write text to disk as UTF-8 WITHOUT a BOM, preserving exact bytes.

.DESCRIPTION
  PacKit XML is UTF-8 with no byte-order-mark and CRLF line endings already baked
  into the string. This helper writes the content verbatim (no re-encoding of
  line endings, no BOM) using an atomic temp-file + overwrite so a partial write
  can never leave a corrupt fragment on disk. The destination directory is
  created if needed.
#>
function Write-OpmBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string] $Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $tmp = [System.IO.Path]::Combine($dir, ([System.IO.Path]::GetRandomFileName()))
    try {
        [System.IO.File]::WriteAllText($tmp, $Content, $utf8NoBom)
        # Copy with overwrite works on both .NET Framework (PS 5.1) and .NET Core (PS 7).
        [System.IO.File]::Copy($tmp, $fullPath, $true)
    }
    finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    return $fullPath
}
