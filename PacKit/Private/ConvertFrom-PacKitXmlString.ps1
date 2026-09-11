<#
.SYNOPSIS
  Parse a PacKit application-fragment XML string into typed objects.

.DESCRIPTION
  The inverse of ConvertTo-PacKitXmlString. Loads the fragment with
  System.Xml.XmlDocument (which, like PacKit's Expat reader, accepts any
  well-formed XML and auto-unescapes attribute values), then maps it back onto
  the PacKit object model using the same schema that drives emission. Attribute
  values are converted to their typed form (Bool/TimeT/Double) on the way in, so
  a load->save round-trip reproduces the original bytes.

  Accepts either a <FRAGMENT> root containing one <ITEM> (the externalized
  fragment file) or a bare <ITEM> root.
#>

# Convert an on-disk attribute string to its typed value per schema Type.
function ConvertFrom-PacKitAttributeText {
    [CmdletBinding()]
    param(
        [Parameter()] [AllowEmptyString()] [AllowNull()] [string] $Value,
        [Parameter(Mandatory)] [string] $Type
    )
    switch ($Type) {
        'Bool' {
            # PacKit reads only the literal lowercase "true" as true (== L"true").
            return [bool]($Value -ceq 'true')
        }
        'TimeT' {
            $n = [long]0
            [void][long]::TryParse($Value, [ref] $n)
            return $n
        }
        'Double' {
            $d = [double]0
            [void][double]::TryParse(
                $Value,
                [System.Globalization.NumberStyles]::Float,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref] $d)
            return $d
        }
        default {
            if ($null -eq $Value) { return '' }
            return [string]$Value
        }
    }
}

# Assign a value to a dotted property path (e.g. 'DetectionRule.Format').
function Set-PacKitValueByPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string] $Path,
        [Parameter()] [AllowNull()] $Value
    )
    $parts = $Path.Split('.')
    $current = $Object
    for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
        $current = $current.$($parts[$i])
    }
    $current.$($parts[-1]) = $Value
}

# Populate $Object from $XmlItem's attributes using the supplied schema descriptors.
function Set-PacKitObjectFromXmlItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] $XmlItem,
        [Parameter(Mandatory)] [object[]] $Descriptors
    )
    foreach ($d in $Descriptors) {
        # GetAttribute returns '' for an absent attribute, which maps to the default.
        $raw = $XmlItem.GetAttribute($d.Name)
        $typed = ConvertFrom-PacKitAttributeText -Value $raw -Type $d.Type
        Set-PacKitValueByPath -Object $Object -Path $d.Path -Value $typed
    }
}

function Assert-PacKitXmlItemHasAttributes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $XmlItem,
        [Parameter(Mandatory)] [string[]] $AttributeNames,
        [Parameter(Mandatory)] [string] $Context
    )
    foreach ($name in $AttributeNames) {
        if (-not $XmlItem.HasAttribute($name)) {
            throw "$Context is missing required attribute '$name'."
        }
    }
}

# Map a single app <ITEM> element into a PacKit.ApplicationFragment.
function ConvertFrom-PacKitAppItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $XmlItem
    )
    $schema = Get-PacKitSchema
    $app = New-PacKitApplicationFragmentObject
    Set-PacKitObjectFromXmlItem -Object $app -XmlItem $XmlItem -Descriptors $schema.App

    $appCollections = @($XmlItem.SelectNodes('COLLECTION'))
    if ($appCollections.Count -ne 2) {
        throw "PacKit fragment must contain exactly two app collections (Packages and IntuneAssignments), found $($appCollections.Count)."
    }
    $packagesCollectionCount = @($appCollections | Where-Object { $_.GetAttribute('Name') -eq 'Packages' }).Count
    $assignmentsCollectionCount = @($appCollections | Where-Object { $_.GetAttribute('Name') -eq 'IntuneAssignments' }).Count
    if (($packagesCollectionCount -ne 1) -or ($assignmentsCollectionCount -ne 1)) {
        throw 'PacKit fragment must contain exactly one Packages collection and one IntuneAssignments collection.'
    }

    # Packages
    $packages = @()
    $packagesNode = $XmlItem.SelectSingleNode("COLLECTION[@Name='Packages']")
    if ($packagesNode) {
        foreach ($pkgItem in $packagesNode.SelectNodes('ITEM')) {
            Assert-PacKitXmlItemHasAttributes -XmlItem $pkgItem -AttributeNames @('PackageId') -Context 'Packages ITEM'
            $pkg = New-PacKitPackageObject
            Set-PacKitObjectFromXmlItem -Object $pkg -XmlItem $pkgItem -Descriptors $schema.Package

            $scans = @()
            $scanNode = $pkgItem.SelectSingleNode("COLLECTION[@Name='WinGetScanResults']")
            $invalidPkgChildCollections = @($pkgItem.SelectNodes("COLLECTION[not(@Name='WinGetScanResults')]"))
            if ($invalidPkgChildCollections.Count -gt 0) {
                throw "Packages ITEM contains unsupported child collection '$($invalidPkgChildCollections[0].GetAttribute('Name'))'."
            }
            if ($scanNode) {
                foreach ($scanItem in $scanNode.SelectNodes('ITEM')) {
                    $scan = New-PacKitWinGetScanResultObject
                    Set-PacKitObjectFromXmlItem -Object $scan -XmlItem $scanItem -Descriptors $schema.WinGetScanResult
                    $scans += $scan
                }
            }
            $pkg.WinGetScanResults = @($scans)
            $packages += $pkg
        }
    }
    $app.Packages = @($packages)

    # Intune assignments
    $assignments = @()
    $assignmentsNode = $XmlItem.SelectSingleNode("COLLECTION[@Name='IntuneAssignments']")
    if ($assignmentsNode) {
        foreach ($asgItem in $assignmentsNode.SelectNodes('ITEM')) {
            Assert-PacKitXmlItemHasAttributes -XmlItem $asgItem -AttributeNames @('MsEntraGroupId', 'AssignmentType', 'InclusionType') -Context 'IntuneAssignments ITEM'
            if (@($asgItem.SelectNodes('COLLECTION')).Count -gt 0) {
                throw 'IntuneAssignments ITEM must not contain child collections.'
            }
            $asg = New-PacKitAssignmentObject
            Set-PacKitObjectFromXmlItem -Object $asg -XmlItem $asgItem -Descriptors $schema.Assignment
            $assignments += $asg
        }
    }
    $app.IntuneAssignments = @($assignments)

    return $app
}

function ConvertFrom-PacKitXmlString {
    [CmdletBinding()]
    [OutputType('PacKit.ApplicationFragment')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Xml
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $false
    try {
        $doc.LoadXml($Xml)
    }
    catch {
        throw "PacKit fragment is not well-formed XML: $($_.Exception.Message)"
    }

    $root = $doc.DocumentElement
    if ($null -eq $root) {
        throw 'PacKit fragment is empty.'
    }

    $appItem = $null
    switch ($root.LocalName) {
        'FRAGMENT' { $appItem = $root.SelectSingleNode('ITEM') }
        'ITEM' { $appItem = $root }
        default {
            throw "Unrecognised PacKit fragment root '<$($root.Name)>'. Expected <FRAGMENT> or <ITEM>."
        }
    }

    if ($null -eq $appItem) {
        throw 'PacKit fragment <FRAGMENT> contains no <ITEM> element.'
    }

    return ConvertFrom-PacKitAppItem -XmlItem $appItem
}
