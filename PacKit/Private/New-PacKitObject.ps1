<#
.SYNOPSIS
  Typed PSCustomObject factories for the PacKit fragment object model.

.DESCRIPTION
  Each factory returns a fresh object initialised to schema defaults and tagged
  with a PSTypeName so callers (and Format.ps1xml, if added later) can recognise
  it. Property names match the schema 'Path' values so the emitter/parser map
  cleanly. IDs are NOT generated here (factories stay deterministic); the public
  cmdlets own GUID assignment.

  Object model:
    PacKit.ApplicationFragment
      .AppId .Name .Vendor .Description .IconPath
      .WinGetAppScannedAt .Unseen .OperatingSys .OperatingSysArchitecture
      .DetectionRule  -> PacKit.DetectionRule
      .Packages       -> PacKit.Package[]
      .IntuneAssignments -> PacKit.Assignment[]
    PacKit.Package
      ... .WinGetScanResults -> PacKit.WinGetScanResult[]
#>

function New-PacKitDetectionRuleObject {
    [CmdletBinding()]
    [OutputType('PacKit.DetectionRule')]
    param()

    $obj = [PSCustomObject][ordered]@{
        Format            = ''
        Type              = ''
        MsiValue          = ''
        ScriptPath        = ''
        FilePath          = ''
        FileName          = ''
        RegKey            = ''
        RegValue          = ''
        FileDetectionType = ''
        FileOperator      = ''
        FileValue         = ''
        RegDetectionType  = ''
        RegOperator       = ''
        RegDetectionValue = ''
    }
    $obj.PSObject.TypeNames.Insert(0, 'PacKit.DetectionRule')
    return $obj
}

function New-PacKitWinGetScanResultObject {
    [CmdletBinding()]
    [OutputType('PacKit.WinGetScanResult')]
    param()

    $obj = [PSCustomObject][ordered]@{
        CatalogPackageId = ''
        MatchScore       = [double]0.0
        Vendor           = ''
    }
    $obj.PSObject.TypeNames.Insert(0, 'PacKit.WinGetScanResult')
    return $obj
}

function New-PacKitAssignmentObject {
    [CmdletBinding()]
    [OutputType('PacKit.Assignment')]
    param()

    $obj = [PSCustomObject][ordered]@{
        MsEntraGroupId = ''
        AssignmentType = ''
        InclusionType  = ''
    }
    $obj.PSObject.TypeNames.Insert(0, 'PacKit.Assignment')
    return $obj
}

function New-PacKitPackageObject {
    [CmdletBinding()]
    [OutputType('PacKit.Package')]
    param()

    $obj = [PSCustomObject][ordered]@{
        PackageId              = ''
        IntuneId               = ''
        CatalogPackageId       = ''
        CatalogUpdateCheckedAt = [long]0
        CatalogUpdateAvailable = $false
        InstallCmdLine         = ''
        UninstallCmdLine       = ''
        Path                   = ''
        SourceFolder           = ''
        Type                   = ''
        Version                = ''
        ProductCode            = ''
        PackageArchitecture    = ''
        IntuneDeployTime       = ''
        IntuneEncryptionKey    = ''
        IntuneEncryptionIV     = ''
        WinGetScanResults      = @()
    }
    $obj.PSObject.TypeNames.Insert(0, 'PacKit.Package')
    return $obj
}

function New-PacKitApplicationFragmentObject {
    [CmdletBinding()]
    [OutputType('PacKit.ApplicationFragment')]
    param()

    $obj = [PSCustomObject][ordered]@{
        AppId                    = ''
        Name                     = ''
        Vendor                   = ''
        Description              = ''
        IconPath                 = ''
        WinGetAppScannedAt       = [long]0
        Unseen                   = $false
        OperatingSys             = ''
        OperatingSysArchitecture = ''
        ReturnCodesJson          = ''
        ScopeTagId               = ''
        DetectionRule            = (New-PacKitDetectionRuleObject)
        Packages                 = @()
        IntuneAssignments        = @()
    }
    $obj.PSObject.TypeNames.Insert(0, 'PacKit.ApplicationFragment')
    return $obj
}
