<#
  Tests for OpmSchema.ps1 - locks the on-disk attribute order (the single
  source of truth consumed by emitter/parser/validator) against the contract.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'OpmSchema' {

    It 'app attribute order matches the contract (25 attributes)' {
        $names = InModuleScope OpenPackageManifest { (Get-OpmSchema).App | ForEach-Object { $_.Name } }
        $names | Should -Be @(
            'AppId', 'Name', 'Vendor', 'Description', 'IconPath', 'WinGetAppScannedAt', 'Unseen',
            'OperatingSys', 'OperatingSysArchitecture', 'ReturnCodesJson', 'ScopeTagId',
            'DetectionRuleFormat', 'DetectionRuleType', 'DetectionRuleMsiValue', 'DetectionMethodScript',
            'DetectionRuleFilePath', 'DetectionRuleFileName', 'DetectionRuleRegKey', 'DetectionRuleRegValue',
            'DetectionRuleFileDetectionType', 'DetectionRuleFileOperator', 'DetectionRuleFileValue',
            'DetectionRuleRegDetectionType', 'DetectionRuleRegOperator', 'DetectionRuleRegDetectionValue'
        )
    }

    It 'package attribute order matches the contract (16 attributes)' {
        $names = InModuleScope OpenPackageManifest { (Get-OpmSchema).Package | ForEach-Object { $_.Name } }
        $names | Should -Be @(
            'PackageId', 'PackageIntuneId', 'CatalogPackageId', 'CatalogUpdateCheckedAt', 'CatalogUpdateAvailable',
            'InstallCmdLine', 'UninstallCmdLine', 'Path', 'SourceFolder', 'Type', 'Version', 'ProductCode',
            'PackageArchitecture', 'IntuneDeployTime', 'IntuneEncryptionKey', 'IntuneEncryptionIV'
        )
    }

    It 'WinGetScanResult attribute order matches the contract' {
        $names = InModuleScope OpenPackageManifest { (Get-OpmSchema).WinGetScanResult | ForEach-Object { $_.Name } }
        $names | Should -Be @('WinGetCatalogPackageId', 'WinGetMatchScore', 'WinGetAppVendor')
    }

    It 'IntuneAssignment attribute order matches the contract' {
        $names = InModuleScope OpenPackageManifest { (Get-OpmSchema).Assignment | ForEach-Object { $_.Name } }
        $names | Should -Be @('MsEntraGroupId', 'AssignmentType', 'InclusionType')
    }

    It 'defines the .packit folder and its 7 managed subfolders' {
        $schema = InModuleScope OpenPackageManifest { Get-OpmSchema }
        $schema.OpmFolderName | Should -BeExactly '.packit'
        $schema.Subfolders | Should -Be @('icons', 'detection-scripts', 'psadt', 'intunewin', 'mecm', 'downloads', 'temp')
    }

    It 'FragmentVersion is 23.8' {
        (InModuleScope OpenPackageManifest { (Get-OpmSchema).FragmentVersion }) | Should -BeExactly '23.8'
    }

    It 'recognises the 8 PacKit package types' {
        $types = InModuleScope OpenPackageManifest { (Get-OpmSchema).PackageTypes }
        $types | Should -Be @('msi', 'exe', 'msix', 'msixbundle', 'appx', 'appxbundle', 'ps1', 'vbs')
    }

    It 'maps detection-rule attributes to the nested DetectionRule object' {
        $msi = InModuleScope OpenPackageManifest { (Get-OpmSchema).App | Where-Object { $_.Name -eq 'DetectionRuleMsiValue' } }
        $msi.Path | Should -BeExactly 'DetectionRule.MsiValue'
    }

    It 'maps PackageIntuneId attribute to the IntuneId property' {
        $p = InModuleScope OpenPackageManifest { (Get-OpmSchema).Package | Where-Object { $_.Name -eq 'PackageIntuneId' } }
        $p.Path | Should -BeExactly 'IntuneId'
    }
}
