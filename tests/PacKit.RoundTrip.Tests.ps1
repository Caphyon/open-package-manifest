<#
  Tests for the load->save round-trip - the prime directive: a fragment that is
  imported and re-exported must be byte-identical, and authoring then exporting
  must be idempotent.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
    . (Join-Path $PSScriptRoot '_CanonicalFragment.ps1')
    $script:goldenFragmentPath = Join-Path $PSScriptRoot 'fixtures\golden-fragment.xml'
    $script:goldenFragmentBytes = [System.IO.File]::ReadAllBytes($script:goldenFragmentPath)
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'PacKit fragment round-trip' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-rt-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Import then Export is byte-identical to the original' {
        $app = Import-PacKitApplicationFragment -LiteralPath $script:goldenFragmentPath
        $out = Join-Path $script:work 'roundtrip.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $out | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($out)
        ($bytes -join ',') | Should -BeExactly ($script:goldenFragmentBytes -join ',')
    }

    It 'New -> Export -> Import -> Export is byte-stable (idempotent)' {
        $app = New-CanonicalPacKitFragment
        $out1 = Join-Path $script:work 'first.xml'
        $out2 = Join-Path $script:work 'second.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $out1 | Out-Null
        $reloaded = Import-PacKitApplicationFragment -LiteralPath $out1
        Export-PacKitApplicationFragment -Fragment $reloaded -LiteralPath $out2 | Out-Null
        $b1 = [System.IO.File]::ReadAllBytes($out1)
        $b2 = [System.IO.File]::ReadAllBytes($out2)
        ($b2 -join ',') | Should -BeExactly ($b1 -join ',')
    }

    It 'preserves all five XML special characters through a round-trip' {
        $raw = 'A & B < C > D " E ' + [char]39 + 'F' + [char]39
        $app = New-PacKitApplicationFragment -Name $raw -AppId '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'
        $out = Join-Path $script:work 'special.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $out | Out-Null

        # The on-disk text must contain the escaped entities...
        $text = [System.IO.File]::ReadAllText($out)
        $text | Should -Match ([regex]::Escape('A &amp; B &lt; C &gt; D &quot; E &apos;F&apos;'))

        # ...and re-importing must recover the raw string exactly.
        $reloaded = Import-PacKitApplicationFragment -LiteralPath $out
        $reloaded.Name | Should -BeExactly $raw
    }

    It 'round-trips a fragment with empty collections (golden-empty shape)' {
        $app = New-MinimalPacKitFragment
        $out = Join-Path $script:work 'min.xml'
        Export-PacKitApplicationFragment -Fragment $app -LiteralPath $out | Out-Null
        $reloaded = Import-PacKitApplicationFragment -LiteralPath $out
        $reloaded.Name | Should -BeExactly 'Minimal'
        $reloaded.Packages.Count | Should -Be 0
        $reloaded.IntuneAssignments.Count | Should -Be 0
    }
}
