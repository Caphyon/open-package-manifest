<#
  Tests for Format-OpmXmlAttributeValue.ps1 - locks the byte-faithful XML
  attribute escaping against the C++ StringToXML contract.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'Format-OpmXmlAttributeValue' {

    It 'returns empty string for empty input' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value '' }) | Should -BeExactly ''
    }

    It 'maps the five XML special characters to named entities' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value '&' }) | Should -BeExactly '&amp;'
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value '<' }) | Should -BeExactly '&lt;'
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value '>' }) | Should -BeExactly '&gt;'
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value '"' }) | Should -BeExactly '&quot;'
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value "'" }) | Should -BeExactly '&apos;'
    }

    It 'escapes ampersand first so existing entities are not double-decoded' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value '&amp;' }) | Should -BeExactly '&amp;amp;'
    }

    It 'maps TAB, LF and CR to decimal character references' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value ([string][char]9) })  | Should -BeExactly '&#9;'
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value ([string][char]10) }) | Should -BeExactly '&#10;'
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value ([string][char]13) }) | Should -BeExactly '&#13;'
    }

    It 'maps DEL (0x7F) to &#127;' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value ([string][char]127) }) | Should -BeExactly '&#127;'
    }

    It 'maps other C0 control characters to decimal references' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value ([string][char]1) }) | Should -BeExactly '&#1;'
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value ([string][char]31) }) | Should -BeExactly '&#31;'
    }

    It 'keeps ordinary BMP characters literal' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value 'Acme Corp 1.0' }) | Should -BeExactly 'Acme Corp 1.0'
    }

    It 'keeps backslash paths literal' {
        (InModuleScope OpenPackageManifest { Format-OpmXmlAttributeValue -Value 'icons\app.png' }) | Should -BeExactly 'icons\app.png'
    }

    It 'escapes the canonical mixed sample exactly' {
        $raw = 'Acme & Co "Reader" <v1> ' + [char]39 + 'X' + [char]39
        $expected = 'Acme &amp; Co &quot;Reader&quot; &lt;v1&gt; &apos;X&apos;'
        (InModuleScope OpenPackageManifest -Parameters @{ raw = $raw } { Format-OpmXmlAttributeValue -Value $raw }) | Should -BeExactly $expected
    }

    It 'keeps a valid surrogate pair (emoji) literal' {
        # U+1F600 grinning face = high D83D, low DE00
        $emoji = [string]::new([char[]]@([char]0xD83D, [char]0xDE00))
        (InModuleScope OpenPackageManifest -Parameters @{ emoji = $emoji } { Format-OpmXmlAttributeValue -Value $emoji }) | Should -BeExactly $emoji
    }
}
