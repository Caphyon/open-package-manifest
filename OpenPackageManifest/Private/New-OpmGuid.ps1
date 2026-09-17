<#
.SYNOPSIS
  Generate and validate PacKit-compatible GUID strings.

.DESCRIPTION
  PacKit stores ids (AppId, GroupId, PackageId) as braced, UPPERCASE GUIDs, e.g.
  {0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}. They are produced by
  StringUtil::ToString(GUID) ("{%08X-%04X-%04X-...}") and validated on load via
  CLSIDFromString, which requires the braces. .NET's Guid.ToString('B') yields
  the braced form; we upper-case it to match PacKit byte-for-byte.
#>

function New-OpmGuid {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return [guid]::NewGuid().ToString('B').ToUpperInvariant()
}

function Test-OpmGuid {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return $false
    }

    # Braced, UPPERCASE, 38 chars: {8-4-4-4-12}. -cmatch = case-sensitive.
    return [bool]($Value -cmatch '^\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}$')
}

<#
.SYNOPSIS
  Normalise a GUID-like string to PacKit's canonical braced UPPERCASE form.

.DESCRIPTION
  Returns the braced UPPERCASE form ({XXXXXXXX-...}) when the input parses as a
  GUID (any case, braced or not), so id lookups and stored ids stay consistent.
  Non-GUID and empty values are returned unchanged, so callers that match
  non-GUID ids still work. This is non-throwing; cmdlets that must reject bad
  input (e.g. Add-OpmAssignment) validate separately.
#>
function ConvertTo-OpmCanonicalGuid {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Value
    )

    if ([string]::IsNullOrEmpty($Value)) { return $Value }

    $parsed = [guid]::Empty
    if ([guid]::TryParse($Value, [ref] $parsed)) {
        return $parsed.ToString('B').ToUpperInvariant()
    }
    return $Value
}
