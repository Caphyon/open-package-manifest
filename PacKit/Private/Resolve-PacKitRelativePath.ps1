<#
.SYNOPSIS
  Relative/absolute path helpers anchored at the .packit folder.

.DESCRIPTION
  PacKit stores path-bearing attributes (IconPath, DetectionMethodScript,
  package Path/SourceFolder) relative to the .packit folder that contains the
  fragment, and resolves them back to absolute on load. These helpers mirror
  FilePath::ToRelative / ToAbsolute and work on Windows PowerShell 5.1
  (System.IO.Path.GetRelativePath is .NET Core only, so we use System.Uri).
#>

function Get-PacKitRelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $BaseDirectory,
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string] $Path
    )

    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    # Leave already-relative values untouched.
    if (-not [System.IO.Path]::IsPathRooted($Path)) { return $Path }

    $baseFull = [System.IO.Path]::GetFullPath($BaseDirectory)
    if (-not $baseFull.EndsWith('\')) { $baseFull += '\' }
    $pathFull = [System.IO.Path]::GetFullPath($Path)

    # Target IS the base directory itself -> "." (matches C++ FilePath::ToRelative).
    if ($baseFull.TrimEnd('\') -ieq $pathFull.TrimEnd('\')) {
        return '.'
    }

    $baseUri = New-Object System.Uri($baseFull)
    $pathUri = New-Object System.Uri($pathFull)
    $relativeUri = $baseUri.MakeRelativeUri($pathUri)

    # When base and target share no common root (different drive, or a different
    # UNC host), MakeRelativeUri yields an ABSOLUTE uri (e.g. file://srv2/share/...).
    # Mirror C++ FilePath::ToRelative and keep the original absolute path rather than
    # corrupting it into 'file:\\srv2\share\...'.
    if ($relativeUri.IsAbsoluteUri) {
        return $pathFull
    }

    $relative = [System.Uri]::UnescapeDataString($relativeUri.ToString())

    # A different drive can also come back as a rooted relative string (e.g. 'D:/x');
    # keep that absolute too.
    if ($relative -match '^[A-Za-z]:') { return $pathFull }
    return $relative.Replace('/', '\')
}

function Get-PacKitAbsolutePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $BaseDirectory,
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string] $Path
    )

    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }

    return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BaseDirectory, $Path))
}
