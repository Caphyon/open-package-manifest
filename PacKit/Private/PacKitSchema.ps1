<#
.SYNOPSIS
  Single source of truth for the PacKit fragment schema.

.DESCRIPTION
  Returns the ordered attribute descriptors for every ITEM type in a PacKit
  application fragment, plus folder constants, the FRAGMENT version and the set
  of recognised package types. The emitter, parser and validator all read THIS
  definition, so the on-disk attribute order can never drift between them.

  Each attribute descriptor is a hashtable:
    Name    - the XML attribute name written/read on disk (authoritative order)
    Path    - the dotted property path on the PowerShell object that holds the value
    Type    - one of: String, Bool, TimeT, Double, Guid (controls value formatting)
    Default - the default the parser uses when the attribute is missing

  The C++ source of truth is tools/deployment/src/core/components/WorkspaceApps.cpp
  (WorkspaceApps::Serialize / Deserialize) and RepackagerTraits.h.
#>

function Get-PacKitSchema {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param()

    # --- Application ITEM attributes (exact order: WorkspaceApps.cpp:414-442) ---
    $app = @(
        @{ Name = 'AppId';                          Path = 'AppId';                          Type = 'Guid';   Default = '' }
        @{ Name = 'Name';                           Path = 'Name';                           Type = 'String'; Default = '' }
        @{ Name = 'Vendor';                         Path = 'Vendor';                         Type = 'String'; Default = '' }
        @{ Name = 'Description';                     Path = 'Description';                     Type = 'String'; Default = '' }
        @{ Name = 'IconPath';                        Path = 'IconPath';                        Type = 'String'; Default = '' }
        @{ Name = 'WinGetAppScannedAt';              Path = 'WinGetAppScannedAt';              Type = 'TimeT';  Default = 0 }
        @{ Name = 'Unseen';                          Path = 'Unseen';                          Type = 'Bool';   Default = $false }
        @{ Name = 'OperatingSys';                    Path = 'OperatingSys';                    Type = 'String'; Default = '' }
        @{ Name = 'OperatingSysArchitecture';        Path = 'OperatingSysArchitecture';        Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleFormat';             Path = 'DetectionRule.Format';            Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleType';               Path = 'DetectionRule.Type';              Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleMsiValue';           Path = 'DetectionRule.MsiValue';          Type = 'String'; Default = '' }
        @{ Name = 'DetectionMethodScript';           Path = 'DetectionRule.ScriptPath';        Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleFilePath';           Path = 'DetectionRule.FilePath';          Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleFileName';           Path = 'DetectionRule.FileName';          Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleRegKey';             Path = 'DetectionRule.RegKey';            Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleRegValue';           Path = 'DetectionRule.RegValue';          Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleFileDetectionType';  Path = 'DetectionRule.FileDetectionType'; Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleFileOperator';       Path = 'DetectionRule.FileOperator';      Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleFileValue';          Path = 'DetectionRule.FileValue';         Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleRegDetectionType';   Path = 'DetectionRule.RegDetectionType';  Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleRegOperator';        Path = 'DetectionRule.RegOperator';       Type = 'String'; Default = '' }
        @{ Name = 'DetectionRuleRegDetectionValue';  Path = 'DetectionRule.RegDetectionValue'; Type = 'String'; Default = '' }
    )

    # --- Package ITEM attributes (exact order: WorkspaceApps.cpp:457-473) ---
    $package = @(
        @{ Name = 'PackageId';              Path = 'PackageId';              Type = 'Guid';   Default = '' }
        @{ Name = 'PackageIntuneId';        Path = 'IntuneId';               Type = 'String'; Default = '' }
        @{ Name = 'CatalogPackageId';       Path = 'CatalogPackageId';       Type = 'String'; Default = '' }
        @{ Name = 'CatalogUpdateCheckedAt'; Path = 'CatalogUpdateCheckedAt'; Type = 'TimeT';  Default = 0 }
        @{ Name = 'CatalogUpdateAvailable'; Path = 'CatalogUpdateAvailable'; Type = 'Bool';   Default = $false }
        @{ Name = 'InstallCmdLine';         Path = 'InstallCmdLine';         Type = 'String'; Default = '' }
        @{ Name = 'UninstallCmdLine';       Path = 'UninstallCmdLine';       Type = 'String'; Default = '' }
        @{ Name = 'Path';                   Path = 'Path';                   Type = 'String'; Default = '' }
        @{ Name = 'SourceFolder';           Path = 'SourceFolder';           Type = 'String'; Default = '' }
        @{ Name = 'Type';                   Path = 'Type';                   Type = 'String'; Default = '' }
        @{ Name = 'Version';                Path = 'Version';                Type = 'String'; Default = '' }
        @{ Name = 'ProductCode';            Path = 'ProductCode';            Type = 'String'; Default = '' }
        @{ Name = 'PackageArchitecture';    Path = 'PackageArchitecture';    Type = 'String'; Default = '' }
        @{ Name = 'IntuneDeployTime';       Path = 'IntuneDeployTime';       Type = 'String'; Default = '' }
        @{ Name = 'IntuneEncryptionKey';    Path = 'IntuneEncryptionKey';    Type = 'String'; Default = '' }
        @{ Name = 'IntuneEncryptionIV';     Path = 'IntuneEncryptionIV';     Type = 'String'; Default = '' }
    )

    # --- WinGetScanResult ITEM attributes (exact order: WorkspaceApps.cpp:480-483) ---
    $winGetScanResult = @(
        @{ Name = 'WinGetCatalogPackageId'; Path = 'CatalogPackageId'; Type = 'String'; Default = '' }
        @{ Name = 'WinGetMatchScore';       Path = 'MatchScore';       Type = 'Double'; Default = 0.0 }
        @{ Name = 'WinGetAppVendor';        Path = 'Vendor';           Type = 'String'; Default = '' }
    )

    # --- IntuneAssignment ITEM attributes (exact order: WorkspaceApps.cpp:500-502) ---
    $assignment = @(
        @{ Name = 'MsEntraGroupId'; Path = 'MsEntraGroupId'; Type = 'String'; Default = '' }
        @{ Name = 'AssignmentType'; Path = 'AssignmentType'; Type = 'String'; Default = '' }
        @{ Name = 'InclusionType';  Path = 'InclusionType';  Type = 'String'; Default = '' }
    )

    return @{
        # FRAGMENT/PROJECT Version attribute value (VersionData::kVersion = APP_VERSION).
        FragmentVersion  = '23.8'

        # .packit folder + its managed subfolders (PackitPaths.h:45-54).
        PackitFolderName = '.packit'
        Subfolders       = @('icons', 'detection-scripts', 'psadt', 'intunewin', 'mecm', 'downloads', 'temp')

        # Recognised package types = lowercase file extension of the package Path
        # (DeploymentToolTraits.h:31-39). 'Type' is informational on load; PacKit
        # recomputes it from the Path extension at runtime.
        PackageTypes     = @('msi', 'exe', 'msix', 'msixbundle', 'appx', 'appxbundle', 'ps1', 'vbs')

        # Repackager component id for the apps component (used by the .pkproj writer).
        AppsComponentId  = 'caphyon.deployment.component.WorkspaceApps'

        # Ordered attribute descriptors per ITEM type.
        App              = $app
        Package          = $package
        WinGetScanResult = $winGetScanResult
        Assignment       = $assignment
    }
}
