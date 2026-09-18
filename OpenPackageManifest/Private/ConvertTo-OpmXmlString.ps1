<#
.SYNOPSIS
  Serialize a PacKit application fragment to its exact on-disk XML string.

.DESCRIPTION
  Reproduces, byte-for-byte, the output of the C++ PacKit writer for a single
  externalized application fragment:
    - declaration: <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    - CRLF line endings, 2-space indent per depth
    - <FRAGMENT Version="23.8"> root with one inline <ITEM> (the app)
    - item properties as XML attributes in the exact schema order
    - every defined attribute emitted even when empty
    - COLLECTION elements always rendered as an open+close pair (even empty)
    - leaf ITEMs self-closed (<ITEM .../>)
    - attribute values escaped via Format-OpmXmlAttributeValue (NOT .NET defaults)

  The structure is built into a small element tree, then rendered, so the byte
  format lives in exactly one place (Write-OpmElementNode) and the attribute
  order lives in exactly one place (Get-OpmSchema).
#>

# Resolve a dotted property path (e.g. 'DetectionRule.Format') against an object.
function Get-OpmValueByPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string] $Path
    )
    $current = $Object
    foreach ($part in $Path.Split('.')) {
        if ($null -eq $current) { return $null }
        $current = $current.$part
    }
    return $current
}

# Format a raw value as its on-disk attribute text according to its schema Type.
function Get-OpmAttributeText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [AllowNull()] $Value,
        [Parameter(Mandatory)] [string] $Type
    )
    switch ($Type) {
        'Bool' {
            if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
            # tolerate string forms
            if ("$Value" -eq 'true') { return 'true' } else { return 'false' }
        }
        'TimeT' {
            if ($null -eq $Value -or "$Value" -eq '') { return '0' }
            return [string]([long]$Value)
        }
        'Double' {
            if ($null -eq $Value -or "$Value" -eq '') { $Value = 0.0 }
            return ([double]$Value).ToString('F6', [System.Globalization.CultureInfo]::InvariantCulture)
        }
        default {
            # String, Guid
            if ($null -eq $Value) { return '' }
            return [string]$Value
        }
    }
}

# Build the ordered attribute list (Name/Value pairs) for one item from a schema set.
function Get-OpmItemAttributes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [object[]] $Descriptors
    )
    $attrs = @(foreach ($d in $Descriptors) {
            $raw = Get-OpmValueByPath -Object $Object -Path $d.Path
            @{ Name = $d.Name; Value = (Get-OpmAttributeText -Value $raw -Type $d.Type) }
        })
    return , $attrs
}

# Build the element tree for a fragment file: <FRAGMENT><ITEM ...>...</ITEM></FRAGMENT>.
function ConvertTo-OpmElementTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Fragment
    )
    $schema = Get-OpmSchema

    # Packages collection
    $packageItems = @(foreach ($pkg in @($Fragment.Packages)) {
            $scanItems = @(foreach ($scan in @($pkg.WinGetScanResults)) {
                    @{
                        Name       = 'ITEM'
                        Attributes = (Get-OpmItemAttributes -Object $scan -Descriptors $schema.WinGetScanResult)
                        Children   = @()
                        ForceOpen  = $false
                    }
                })
            $scanCollection = @{
                Name       = 'COLLECTION'
                Attributes = @(@{ Name = 'Name'; Value = 'WinGetScanResults' })
                Children   = $scanItems
                ForceOpen  = $true
            }
            @{
                Name       = 'ITEM'
                Attributes = (Get-OpmItemAttributes -Object $pkg -Descriptors $schema.Package)
                Children   = @($scanCollection)
                ForceOpen  = $false
            }
        })
    $packagesCollection = @{
        Name       = 'COLLECTION'
        Attributes = @(@{ Name = 'Name'; Value = 'Packages' })
        Children   = $packageItems
        ForceOpen  = $true
    }

    # IntuneAssignments collection
    $assignmentItems = @(foreach ($asg in @($Fragment.IntuneAssignments)) {
            @{
                Name       = 'ITEM'
                Attributes = (Get-OpmItemAttributes -Object $asg -Descriptors $schema.Assignment)
                Children   = @()
                ForceOpen  = $false
            }
        })
    $assignmentsCollection = @{
        Name       = 'COLLECTION'
        Attributes = @(@{ Name = 'Name'; Value = 'IntuneAssignments' })
        Children   = $assignmentItems
        ForceOpen  = $true
    }

    $appItem = @{
        Name       = 'ITEM'
        Attributes = (Get-OpmItemAttributes -Object $Fragment -Descriptors $schema.App)
        Children   = @($packagesCollection, $assignmentsCollection)
        ForceOpen  = $false
    }

    return @{
        Name       = 'FRAGMENT'
        Attributes = @(@{ Name = 'Version'; Value = $schema.FragmentVersion })
        Children   = @($appItem)
        ForceOpen  = $false
    }
}

# Recursively render an element node into the StringBuilder (CRLF, 2-space indent).
function Write-OpmElementNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $Node,
        [Parameter(Mandatory)] [int] $Depth,
        [Parameter(Mandatory)] [System.Text.StringBuilder] $Builder
    )
    $eol = [string][char]13 + [string][char]10
    $indent = '  ' * $Depth

    $open = $indent + '<' + $Node.Name
    foreach ($attr in @($Node.Attributes)) {
        $open += ' ' + $attr.Name + '="' + (Format-OpmXmlAttributeValue -Value ([string]$attr.Value)) + '"'
    }

    $children = @($Node.Children)
    $hasChildren = ($children.Count -gt 0)
    $forceOpen = [bool]$Node.ForceOpen

    if ($hasChildren -or $forceOpen) {
        [void]$Builder.Append($open).Append('>').Append($eol)
        foreach ($child in $children) {
            Write-OpmElementNode -Node $child -Depth ($Depth + 1) -Builder $Builder
        }
        [void]$Builder.Append($indent).Append('</').Append($Node.Name).Append('>').Append($eol)
    }
    else {
        [void]$Builder.Append($open).Append('/>').Append($eol)
    }
}

function ConvertTo-OpmXmlString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $Fragment
    )
    process {
        $eol = [string][char]13 + [string][char]10
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>').Append($eol)
        $tree = ConvertTo-OpmElementTree -Fragment $Fragment
        Write-OpmElementNode -Node $tree -Depth 0 -Builder $sb
        return $sb.ToString()
    }
}
