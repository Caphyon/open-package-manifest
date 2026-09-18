<#
.SYNOPSIS
  Escape a string for use as a PacKit XML attribute value.

.DESCRIPTION
  Reproduces, byte-for-byte, the escaping performed by the C++ PacKit writer
  (platform/util/strings/StringXML.cpp StringToXMLBase with aContent = false,
  used by XmlWriter::WriteAttributePair). This is deliberately NOT the same as
  .NET's XmlWriter escaping, so the module hand-rolls it to stay byte-faithful.

  Rules (per UTF-16 code unit):
    &  -> &amp;     <  -> &lt;     >  -> &gt;     "  -> &quot;     '  -> &apos;
    code < 0x20 (incl. TAB/LF/CR) -> &#<decimal>;   (e.g. TAB->&#9; LF->&#10; CR->&#13;)
    code == 0x7F (DEL)            -> &#127;
    0x20..0xD7FF and 0xE000..0xFFFD -> literal
    valid surrogate pair         -> literal (both units)
    lone/broken surrogate, 0xFFFE/0xFFFF, anything else -> &#<decimal>;
#>

function Format-OpmXmlAttributeValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return ''
    }

    $sb = [System.Text.StringBuilder]::new($Value.Length + 16)
    $len = $Value.Length

    for ($i = 0; $i -lt $len; $i++) {
        $code = [int]$Value[$i]

        if ($code -eq 38) {            # &
            [void]$sb.Append('&amp;')
        }
        elseif ($code -eq 60) {        # <
            [void]$sb.Append('&lt;')
        }
        elseif ($code -eq 62) {        # >
            [void]$sb.Append('&gt;')
        }
        elseif ($code -eq 34) {        # "
            [void]$sb.Append('&quot;')
        }
        elseif ($code -eq 39) {        # '
            [void]$sb.Append('&apos;')
        }
        elseif ($code -lt 0x20 -or $code -eq 0x7F) {
            # All C0 control characters (incl. TAB/LF/CR) and DEL -> decimal char ref.
            [void]$sb.Append('&#').Append($code).Append(';')
        }
        elseif (($code -ge 0x20 -and $code -le 0xD7FF) -or ($code -ge 0xE000 -and $code -le 0xFFFD)) {
            [void]$sb.Append([char]$code)
        }
        elseif ($code -ge 0xD800 -and $code -le 0xDBFF) {
            # High surrogate: keep a valid pair literal, else encode the broken unit.
            if (($i + 1) -lt $len) {
                $next = [int]$Value[$i + 1]
                if ($next -ge 0xDC00 -and $next -le 0xDFFF) {
                    [void]$sb.Append([char]$code).Append([char]$next)
                    $i++
                    continue
                }
            }
            [void]$sb.Append('&#').Append($code).Append(';')
        }
        else {
            # Lone low surrogate, 0xFFFE, 0xFFFF, etc.
            [void]$sb.Append('&#').Append($code).Append(';')
        }
    }

    return $sb.ToString()
}

<#
.SYNOPSIS
  Test whether a string contains only characters that are valid in XML 1.0.

.DESCRIPTION
  The byte-faithful escaper mirrors PacKit's C++ writer, which emits decimal
  character references (e.g. &#1;) for characters that are not valid in XML 1.0.
  Such references are NOT well-formed XML and a standard parser (including
  PacKit's Expat reader) would reject the fragment before it could be loaded.
  XML 1.0 permits TAB (0x09), LF (0x0A), CR (0x0D), 0x20-0xD7FF, 0xE000-0xFFFD,
  and supplementary characters 0x10000-0x10FFFF (encoded in UTF-16 as a valid
  high+low surrogate PAIR). Everything else is invalid: the other C0 controls,
  0xFFFE, 0xFFFF, and lone/broken surrogate code units. Returns $true when the
  text is safe to serialize, $false when it contains an XML-invalid character.
#>
function Test-OpmXmlSafeText {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Value
    )

    if ([string]::IsNullOrEmpty($Value)) { return $true }

    for ($i = 0; $i -lt $Value.Length; $i++) {
        $code = [int]$Value[$i]

        if ($code -eq 0x09 -or $code -eq 0x0A -or $code -eq 0x0D) {
            continue   # TAB / LF / CR
        }
        if ($code -ge 0x20 -and $code -le 0xD7FF) {
            continue   # BMP before the surrogate range
        }
        if ($code -ge 0xE000 -and $code -le 0xFFFD) {
            continue   # BMP after the surrogate range (excludes 0xFFFE / 0xFFFF)
        }
        if ($code -ge 0xD800 -and $code -le 0xDBFF) {
            # High surrogate: valid only when followed by a low surrogate.
            if (($i + 1) -lt $Value.Length) {
                $next = [int]$Value[$i + 1]
                if ($next -ge 0xDC00 -and $next -le 0xDFFF) {
                    $i++   # consume the valid pair
                    continue
                }
            }
            return $false   # lone / broken high surrogate
        }

        # Other C0 controls, 0xFFFE, 0xFFFF, or a lone low surrogate.
        return $false
    }

    return $true
}
