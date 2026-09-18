<#
  Validates real Export-OpmApplicationFragment output against
  OpenPackageManifest\Schema\OpmModuleFragment.xsd, which documents exactly what this
  module can emit. Every fragment here is built through the public cmdlets
  only (New-/Set-/Add-/Export-OpmApplication*), never through the internal
  object factories, so this is also a smoke test of the public API surface.
#>

BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $repoRoot 'OpenPackageManifest\OpenPackageManifest.psd1') -Force
    $script:xsdPath = Join-Path $repoRoot 'OpenPackageManifest\Schema\OpmModuleFragment.xsd'

    # Validates an on-disk XML file against $script:xsdPath; returns the list of
    # validation messages (empty array = the document is schema-valid).
    function Test-XmlAgainstXsd {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] [string] $XmlPath,
            [Parameter(Mandatory)] [string] $XsdPath
        )

        $messages = New-Object System.Collections.Generic.List[string]
        $settings = New-Object System.Xml.XmlReaderSettings
        [void]$settings.Schemas.Add($null, $XsdPath)
        $settings.ValidationType = [System.Xml.ValidationType]::Schema
        # ValidationEventHandler invokes with (sender, args); read both via $args to avoid an unused param.
        $settings.add_ValidationEventHandler({ $messages.Add($args[1].Message) }.GetNewClosure())

        $reader = [System.Xml.XmlReader]::Create($XmlPath, $settings)
        try {
            while ($reader.Read()) {}
        }
        finally {
            $reader.Close()
        }

        return , $messages.ToArray()
    }
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'PacKit fragments vs OpmModuleFragment.xsd' {

    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-xsd-{0}" -f ([guid]::NewGuid()))
        New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    }

    AfterEach {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'validates a full fragment (app + package + scan result + assignment)' {
        # -- exact commands a caller would run --
        $app = New-OpmApplicationFragment -Name 'Acme Reader' -Vendor 'Acme Corporation' `
            -Description 'Reads PDFs' -IconPath 'icons\app.png' -OperatingSys 'Windows' -OperatingSysArchitecture '64-bit'

        Set-OpmApplication -Fragment $app -ReturnCodesJson '[0,3010]' -ScopeTagId '1' `
            -WinGetAppScannedAt 1737000000 -Unseen $false

        Set-OpmDetectionRule -Fragment $app -Format 'Manually configure detection rules' -Type 'MSI' `
            -MsiValue '{0A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}'

        $pkg = Add-OpmPackage -Fragment $app -Path 'app.msi' -InstallCmdLine '/qn' -Version '1.0.0' -PassThru

        Add-OpmWinGetScanResult -Fragment $app -PackageId $pkg.PackageId `
            -CatalogPackageId 'Acme.Reader' -MatchScore 0.95 -Vendor 'Acme' | Out-Null

        Add-OpmAssignment -Fragment $app -MsEntraGroupId ([guid]::NewGuid().ToString()) `
            -AssignmentType 'Required' -InclusionType 'included' | Out-Null

        Test-OpmApplicationFragment -Fragment $app | Should -BeTrue

        $target = Join-Path $script:work 'full.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        $fullXml = Get-Content -LiteralPath $target -Raw
        $fullXml | Should -Match 'ReturnCodesJson="\[0,3010\]"'
        $fullXml | Should -Match 'ScopeTagId="1"'

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -BeNullOrEmpty -Because ($messages -join '; ')
    }

    It 'validates a minimal fragment (no packages, no assignments)' {
        $app = New-OpmApplicationFragment -Name 'Empty'

        $target = Join-Path $script:work 'minimal.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -BeNullOrEmpty -Because ($messages -join '; ')
    }

    It 'validates a fragment with multiple packages and zero scan results' {
        $app = New-OpmApplicationFragment -Name 'Multi Package App'
        Add-OpmPackage -Fragment $app -Path 'setup.exe' -InstallCmdLine '/silent' | Out-Null
        Add-OpmPackage -Fragment $app -Path 'Deploy-Application.ps1' | Out-Null

        $target = Join-Path $script:work 'multi.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -BeNullOrEmpty -Because ($messages -join '; ')
    }

    It 'rejects a fragment whose AppId is not a braced UPPERCASE GUID' {
        $app = New-OpmApplicationFragment -Name 'Bad AppId'
        $target = Join-Path $script:work 'bad-appid.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        # Corrupt the on-disk AppId the way a hand-edited fragment might.
        (Get-Content -LiteralPath $target -Raw) -replace 'AppId="\{[^}]+\}"', 'AppId="not-a-guid"' |
            Set-Content -LiteralPath $target -NoNewline

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -Not -BeNullOrEmpty
    }

    It 'rejects duplicate app collection names' {
        $app = New-OpmApplicationFragment -Name 'Dup Collections'
        $target = Join-Path $script:work 'dup-collections.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        (Get-Content -LiteralPath $target -Raw) -replace 'Name="IntuneAssignments"', 'Name="Packages"' |
            Set-Content -LiteralPath $target -NoNewline

        $messages = Test-XmlAgainstXsd -XmlPath $target -XsdPath $script:xsdPath
        $messages | Should -Not -BeNullOrEmpty
    }

    It 'rejects assignment items that are shaped like packages' {
        $app = New-OpmApplicationFragment -Name 'Wrong Assignment Shape'
        Add-OpmAssignment -Fragment $app -MsEntraGroupId ([guid]::NewGuid().ToString()) -AssignmentType 'Required' -InclusionType 'included' | Out-Null
        $target = Join-Path $script:work 'bad-assignment-shape.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        (Get-Content -LiteralPath $target -Raw) `
            -replace 'MsEntraGroupId="\{[^"]+\}"', 'PackageId="{1B2C3D4E-5F60-7182-93A4-B5C6D7E8F900}"' `
            -replace 'AssignmentType="[^"]*"', '' `
            -replace 'InclusionType="[^"]*"', '' |
            Set-Content -LiteralPath $target -NoNewline

        { Import-OpmApplicationFragment -LiteralPath $target } | Should -Throw
    }

    It 'rejects package items missing package identity fields' {
        $app = New-OpmApplicationFragment -Name 'Missing Package Fields'
        Add-OpmPackage -Fragment $app -Path 'app.msi' | Out-Null
        $target = Join-Path $script:work 'bad-package-shape.xml'
        Export-OpmApplicationFragment -Fragment $app -LiteralPath $target | Out-Null

        (Get-Content -LiteralPath $target -Raw) -replace '\sPackageId="\{[^"]+\}"', '' |
            Set-Content -LiteralPath $target -NoNewline

        { Import-OpmApplicationFragment -LiteralPath $target } | Should -Throw
    }
}
