<#
  Tests for ConvertTo-OpmXmlString / Write-OpmBytes - the byte-fidelity
  crux. The emitter output MUST be byte-identical to the hand-built golden
  fixtures, which encode the C++ PacKit writer's exact format.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force

    $script:fixturesDir = Join-Path $PSScriptRoot 'fixtures'
    $script:goldenFragmentPath = Join-Path $script:fixturesDir 'golden-fragment.xml'
    $script:goldenEmptyPath = Join-Path $script:fixturesDir 'golden-empty.xml'
    $script:goldenFragmentText = [System.IO.File]::ReadAllText($script:goldenFragmentPath)
    $script:goldenEmptyText = [System.IO.File]::ReadAllText($script:goldenEmptyPath)
    $script:goldenFragmentBytes = [System.IO.File]::ReadAllBytes($script:goldenFragmentPath)

    # Build the canonical sample fragment object and emit it (inside module scope).
    $script:actualFragmentText = InModuleScope OpenPackageManifest {
        $app = New-OpmApplicationFragmentObject
        $app.AppId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $app.Name = "Acme & Co `"Reader`" <v1> 'X'"
        $app.Vendor = 'Acme Corporation'
        $app.Description = 'Reads PDFs'
        $app.IconPath = 'icons\app.png'
        $app.OperatingSys = 'Windows'
        $app.OperatingSysArchitecture = 'x64'

        $pkg = New-OpmPackageObject
        $pkg.PackageId = '{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}'
        $pkg.InstallCmdLine = '/qn'
        $pkg.Path = 'app.msi'
        $pkg.Type = 'msi'
        $pkg.Version = '1.0.0'

        $scan = New-OpmWinGetScanResultObject
        $scan.CatalogPackageId = 'Acme.Reader'
        $scan.MatchScore = 0.95
        $scan.Vendor = 'Acme'
        $pkg.WinGetScanResults = @($scan)

        $app.Packages = @($pkg)

        $asg = New-OpmAssignmentObject
        $asg.MsEntraGroupId = '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
        $asg.AssignmentType = 'Required'
        $asg.InclusionType = 'Include'
        $app.IntuneAssignments = @($asg)

        ConvertTo-OpmXmlString -Fragment $app
    }

    # Build the minimal fragment object and emit it.
    $script:actualEmptyText = InModuleScope OpenPackageManifest {
        $app = New-OpmApplicationFragmentObject
        $app.AppId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $app.Name = 'Minimal'
        ConvertTo-OpmXmlString -Fragment $app
    }
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-OpmXmlString' {

    It 'starts with the exact XML declaration followed by CRLF' {
        $expected = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + [char]13 + [char]10
        $script:actualFragmentText.Substring(0, $expected.Length) | Should -BeExactly $expected
    }

    It 'uses CRLF line endings (every LF preceded by CR)' {
        $lfCount = ([regex]::Matches($script:actualFragmentText, [char]10)).Count
        $crlfCount = ([regex]::Matches($script:actualFragmentText, ([char]13 + [char]10))).Count
        $crlfCount | Should -Be $lfCount
    }

    It 'is character-for-character identical to golden-fragment.xml' {
        $script:actualFragmentText | Should -BeExactly $script:goldenFragmentText
    }

    It 'is byte-for-byte identical to golden-fragment.xml (UTF-8, no BOM)' {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $actualBytes = $utf8NoBom.GetBytes($script:actualFragmentText)
        ($actualBytes -join ',') | Should -BeExactly ($script:goldenFragmentBytes -join ',')
        $actualBytes[0] | Should -Not -Be 0xEF   # no BOM
    }

    It 'escapes the five XML special characters in attribute values' {
        $script:actualFragmentText | Should -Match ([regex]::Escape('Name="Acme &amp; Co &quot;Reader&quot; &lt;v1&gt; &apos;X&apos;"'))
    }

    It 'formats the WinGet match score with six decimals' {
        $script:actualFragmentText | Should -Match ([regex]::Escape('WinGetMatchScore="0.950000"'))
    }

    It 'renders empty COLLECTIONs as an open+close pair (golden-empty)' {
        $script:actualEmptyText | Should -BeExactly $script:goldenEmptyText
        $script:actualEmptyText | Should -Match ([regex]::Escape('<COLLECTION Name="Packages">' + [char]13 + [char]10))
    }

    It 'self-closes leaf ITEMs (assignment)' {
        $script:actualFragmentText | Should -Match ([regex]::Escape('AssignmentType="Required" InclusionType="Include"/>'))
    }

    It 'emits every defined attribute even when empty (DetectionRule fields)' {
        $script:actualFragmentText | Should -Match ([regex]::Escape('DetectionRuleFormat="" DetectionRuleType=""'))
    }
}

Describe 'Write-OpmBytes' {

    It 'writes UTF-8 without a BOM and preserves exact bytes' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-wb-{0}.xml" -f ([guid]::NewGuid()))
        try {
            InModuleScope OpenPackageManifest -Parameters @{ p = $tmp; c = $script:actualFragmentText } {
                param($p, $c)
                Write-OpmBytes -Path $p -Content $c | Out-Null
            }
            $written = [System.IO.File]::ReadAllBytes($tmp)
            ($written -join ',') | Should -BeExactly ($script:goldenFragmentBytes -join ',')
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates the destination directory if missing' {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-wbdir-{0}" -f ([guid]::NewGuid()))
        $target = Join-Path $dir 'sub\frag.xml'
        try {
            InModuleScope OpenPackageManifest -Parameters @{ p = $target } {
                param($p)
                Write-OpmBytes -Path $p -Content 'x' | Out-Null
            }
            Test-Path -LiteralPath $target | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
