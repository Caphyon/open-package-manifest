<#
  Tests for Import-PacKitApplicationFragment - discovers and loads a fragment
  from a .packit folder or a literal path.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
    $script:goldenFragmentPath = Join-Path $PSScriptRoot 'fixtures\golden-fragment.xml'
    $script:appId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'Import-PacKitApplicationFragment' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-imp-{0}" -f ([guid]::NewGuid()))
        $script:packit = Join-Path $script:work '.packit'
        New-Item -ItemType Directory -Path $script:packit -Force | Out-Null
        Copy-Item -LiteralPath $script:goldenFragmentPath -Destination (Join-Path $script:packit ($script:appId + '.xml'))
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'loads by -SourceFolder and -AppId' {
        $app = Import-PacKitApplicationFragment -SourceFolder $script:work -AppId $script:appId
        $app.AppId | Should -BeExactly $script:appId
        $app.Vendor | Should -BeExactly 'Acme Corporation'
        $app.Packages.Count | Should -Be 1
    }

    It 'discovers the first *.xml when no -AppId is given' {
        $app = Import-PacKitApplicationFragment -SourceFolder $script:work
        $app.AppId | Should -BeExactly $script:appId
    }

    It 'normalises a lowercase -AppId before locating the file' {
        $app = Import-PacKitApplicationFragment -SourceFolder $script:work -AppId '0a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d'
        $app.AppId | Should -BeExactly $script:appId
    }

    It 'loads an exact -LiteralPath' {
        $app = Import-PacKitApplicationFragment -LiteralPath $script:goldenFragmentPath
        $app.Name | Should -BeExactly ('Acme & Co "Reader" <v1> ' + [char]39 + 'X' + [char]39)
    }

    It 'throws when there is no .packit folder' {
        $empty = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-none-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        try {
            { Import-PacKitApplicationFragment -SourceFolder $empty } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when the literal file is missing' {
        { Import-PacKitApplicationFragment -LiteralPath (Join-Path $script:work 'missing.xml') } | Should -Throw
    }
}
