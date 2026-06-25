<#
  Tests for PacKitSchema.ps1 - locks the on-disk attribute order (the single
  source of truth consumed by emitter/parser/validator) against the contract.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'PacKit\PacKit.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module PacKit -Force -ErrorAction SilentlyContinue
}

Describe 'PacKitSchema' {

    It 'app attribute order matches the contract (23 attributes)' {
        $names = InModuleScope PacKit { (Get-PacKitSchema).App | ForEach-Object { $_.Name } }
        $names | Should -Be @(
            'AppId', 'Name', 'Vendor', 'Description', 'IconPath', 'WinGetAppScannedAt', 'Unseen',
            'OperatingSys', 'OperatingSysArchitecture',
            'DetectionRuleFormat', 'DetectionRuleType', 'DetectionRuleMsiValue', 'DetectionMethodScript',
            'DetectionRuleFilePath', 'DetectionRuleFileName', 'DetectionRuleRegKey', 'DetectionRuleRegValue',
            'DetectionRuleFileDetectionType', 'DetectionRuleFileOperator', 'DetectionRuleFileValue',
            'DetectionRuleRegDetectionType', 'DetectionRuleRegOperator', 'DetectionRuleRegDetectionValue'
        )
    }

    It 'package attribute order matches the contract (16 attributes)' {
        $names = InModuleScope PacKit { (Get-PacKitSchema).Package | ForEach-Object { $_.Name } }
        $names | Should -Be @(
            'PackageId', 'PackageIntuneId', 'CatalogPackageId', 'CatalogUpdateCheckedAt', 'CatalogUpdateAvailable',
            'InstallCmdLine', 'UninstallCmdLine', 'Path', 'SourceFolder', 'Type', 'Version', 'ProductCode',
            'PackageArchitecture', 'IntuneDeployTime', 'IntuneEncryptionKey', 'IntuneEncryptionIV'
        )
    }

    It 'WinGetScanResult attribute order matches the contract' {
        $names = InModuleScope PacKit { (Get-PacKitSchema).WinGetScanResult | ForEach-Object { $_.Name } }
        $names | Should -Be @('WinGetCatalogPackageId', 'WinGetMatchScore', 'WinGetAppVendor')
    }

    It 'IntuneAssignment attribute order matches the contract' {
        $names = InModuleScope PacKit { (Get-PacKitSchema).Assignment | ForEach-Object { $_.Name } }
        $names | Should -Be @('MsEntraGroupId', 'AssignmentType', 'InclusionType')
    }

    It 'defines the .packit folder and its 7 managed subfolders' {
        $schema = InModuleScope PacKit { Get-PacKitSchema }
        $schema.PackitFolderName | Should -BeExactly '.packit'
        $schema.Subfolders | Should -Be @('icons', 'detection-scripts', 'psadt', 'intunewin', 'mecm', 'downloads', 'temp')
    }

    It 'FragmentVersion is 23.8' {
        (InModuleScope PacKit { (Get-PacKitSchema).FragmentVersion }) | Should -BeExactly '23.8'
    }

    It 'recognises the 8 PacKit package types' {
        $types = InModuleScope PacKit { (Get-PacKitSchema).PackageTypes }
        $types | Should -Be @('msi', 'exe', 'msix', 'msixbundle', 'appx', 'appxbundle', 'ps1', 'vbs')
    }

    It 'maps detection-rule attributes to the nested DetectionRule object' {
        $msi = InModuleScope PacKit { (Get-PacKitSchema).App | Where-Object { $_.Name -eq 'DetectionRuleMsiValue' } }
        $msi.Path | Should -BeExactly 'DetectionRule.MsiValue'
    }

    It 'maps PackageIntuneId attribute to the IntuneId property' {
        $p = InModuleScope PacKit { (Get-PacKitSchema).Package | Where-Object { $_.Name -eq 'PackageIntuneId' } }
        $p.Path | Should -BeExactly 'IntuneId'
    }
}
