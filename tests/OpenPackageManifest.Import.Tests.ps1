<#
  Tests for Import-OpmApplicationFragment - discovers and loads a fragment
  from a .packit folder or a literal path.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
    $script:goldenFragmentPath = Join-Path $PSScriptRoot 'fixtures\golden-fragment.xml'
    $script:appId = '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'Import-OpmApplicationFragment' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-imp-{0}" -f ([guid]::NewGuid()))
        $script:opmFolder = Join-Path $script:work '.packit'
        New-Item -ItemType Directory -Path $script:opmFolder -Force | Out-Null
        Copy-Item -LiteralPath $script:goldenFragmentPath -Destination (Join-Path $script:opmFolder ($script:appId + '.xml'))
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'loads by -SourceFolder and -AppId' {
        $app = Import-OpmApplicationFragment -SourceFolder $script:work -AppId $script:appId
        $app.AppId | Should -BeExactly $script:appId
        $app.Vendor | Should -BeExactly 'Acme Corporation'
        $app.Packages.Count | Should -Be 1
    }

    It 'discovers the first *.xml when no -AppId is given' {
        $app = Import-OpmApplicationFragment -SourceFolder $script:work
        $app.AppId | Should -BeExactly $script:appId
    }

    It 'normalises a lowercase -AppId before locating the file' {
        $app = Import-OpmApplicationFragment -SourceFolder $script:work -AppId '0a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d'
        $app.AppId | Should -BeExactly $script:appId
    }

    It 'loads an exact -LiteralPath' {
        $app = Import-OpmApplicationFragment -LiteralPath $script:goldenFragmentPath
        $app.Name | Should -BeExactly ('Acme & Co "Reader" <v1> ' + [char]39 + 'X' + [char]39)
    }

    It 'throws when there is no .packit folder' {
        $empty = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-none-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        try {
            { Import-OpmApplicationFragment -SourceFolder $empty } | Should -Throw
        }
        finally {
            Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when the literal file is missing' {
        { Import-OpmApplicationFragment -LiteralPath (Join-Path $script:work 'missing.xml') } | Should -Throw
    }

    It 'returns relative package paths verbatim by default' {
        $app = Import-OpmApplicationFragment -SourceFolder $script:work -AppId $script:appId
        $app.Packages[0].Path | Should -BeExactly 'app.msi'
    }

    It 'resolves relative package paths to full paths with -ResolvePaths' {
        $app = Import-OpmApplicationFragment -SourceFolder $script:work -AppId $script:appId -ResolvePaths
        $app.Packages[0].Path | Should -BeExactly (Join-Path $script:opmFolder 'app.msi')
        [System.IO.Path]::IsPathRooted($app.Packages[0].Path) | Should -BeTrue
    }

    It 'leaves already-absolute paths untouched with -ResolvePaths' {
        $app = Import-OpmApplicationFragment -LiteralPath $script:goldenFragmentPath -ResolvePaths
        $app.Packages[0].SourceFolder | Should -BeExactly ''
    }
}
