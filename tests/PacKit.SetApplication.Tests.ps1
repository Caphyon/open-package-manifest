<#
  Tests for Set-PacKitApplication and Set-PacKitDetectionRule.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'Set-PacKitApplication' {

    It 'updates only the supplied fields' {
        $app = New-PacKitApplicationFragment -Name 'Original' -Vendor 'OldVendor'
        Set-PacKitApplication -Fragment $app -Vendor 'NewVendor' -OperatingSysArchitecture 'x64'
        $app.Name | Should -BeExactly 'Original'   # untouched
        $app.Vendor | Should -BeExactly 'NewVendor'
        $app.OperatingSysArchitecture | Should -BeExactly 'x64'
    }

    It 'sets typed numeric and boolean fields' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        Set-PacKitApplication -Fragment $app -WinGetAppScannedAt 1700000000 -Unseen $true
        $app.WinGetAppScannedAt | Should -Be 1700000000
        $app.Unseen | Should -BeTrue
    }

    It 'rejects an empty Name' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        { Set-PacKitApplication -Fragment $app -Name '' } | Should -Throw
    }

    It 'emits nothing by default and the fragment with -PassThru' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        (Set-PacKitApplication -Fragment $app -Vendor 'X') | Should -BeNullOrEmpty
        $result = Set-PacKitApplication -Fragment $app -Vendor 'Y' -PassThru
        $result.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.ApplicationFragment'
    }

    It 'is pipeline-chainable with -PassThru' {
        $app = New-PacKitApplicationFragment -Name 'Acme' |
            Set-PacKitApplication -Vendor 'Acme Corporation' -PassThru
        $app.Vendor | Should -BeExactly 'Acme Corporation'
    }
}

Describe 'Set-PacKitDetectionRule' {

    It 'sets detection-rule fields on the nested object' {
        $app = New-PacKitApplicationFragment -Name 'Acme'
        Set-PacKitDetectionRule -Fragment $app -Type 'MSI' -MsiValue '{PRODUCT-CODE}'
        $app.DetectionRule.Type | Should -BeExactly 'MSI'
        $app.DetectionRule.MsiValue | Should -BeExactly '{PRODUCT-CODE}'
    }

    It 'surfaces detection-rule fields as DetectionRule* attributes on export' {
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("packit-dr-{0}" -f ([guid]::NewGuid()))
        try {
            $app = New-PacKitApplicationFragment -Name 'Acme'
            Set-PacKitDetectionRule -Fragment $app -Type 'File' -FilePath 'C:\Program Files\Acme' -FileName 'acme.exe'
            $file = Join-Path $work 'app.xml'
            Export-PacKitApplicationFragment -Fragment $app -LiteralPath $file | Out-Null
            $text = [System.IO.File]::ReadAllText($file)
            $text | Should -Match ([regex]::Escape('DetectionRuleType="File"'))
            $text | Should -Match ([regex]::Escape('DetectionRuleFileName="acme.exe"'))
        }
        finally {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
