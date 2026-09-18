<#
  Tests for Add-OpmAssignment and Remove-OpmAssignment.
#>

BeforeAll {
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'OpenPackageManifest\OpenPackageManifest.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module OpenPackageManifest -Force -ErrorAction SilentlyContinue
}

Describe 'Add-OpmAssignment' {

    It 'appends an assignment with the supplied fields' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}' -AssignmentType 'Required' -InclusionType 'Include' | Out-Null
        $app.IntuneAssignments.Count | Should -Be 1
        $app.IntuneAssignments[0].MsEntraGroupId | Should -BeExactly '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
        $app.IntuneAssignments[0].AssignmentType | Should -BeExactly 'Required'
        $app.IntuneAssignments[0].InclusionType | Should -BeExactly 'Include'
    }

    It 'returns the assignment with -PassThru' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $asg = Add-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}' -AssignmentType 'Available' -PassThru
        $asg.PSObject.TypeNames[0] | Should -BeExactly 'PacKit.Assignment'
        $asg.AssignmentType | Should -BeExactly 'Available'
    }

    It 'normalises a lowercase MsEntraGroupId to braced UPPERCASE' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        $asg = Add-OpmAssignment -Fragment $app -MsEntraGroupId '2c3d4e5f-6071-8293-a4b5-c6d7e8f90011' -AssignmentType 'Required' -PassThru
        $asg.MsEntraGroupId | Should -BeExactly '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
    }

    It 'throws on a non-GUID MsEntraGroupId' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        { Add-OpmAssignment -Fragment $app -MsEntraGroupId 'not-a-guid' -AssignmentType 'Required' } | Should -Throw
    }

    It 'serialises the assignment under IntuneAssignments on export' {
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ("opm-asg-{0}" -f ([guid]::NewGuid()))
        try {
            $app = New-OpmApplicationFragment -Name 'Acme'
            Add-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}' -AssignmentType 'Required' -InclusionType 'Include' | Out-Null
            $file = Join-Path $work 'app.xml'
            Export-OpmApplicationFragment -Fragment $app -LiteralPath $file | Out-Null
            $doc = [xml][System.IO.File]::ReadAllText($file)
            $asgNode = $doc.SelectSingleNode("//COLLECTION[@Name='IntuneAssignments']/ITEM")
            $asgNode.MsEntraGroupId | Should -BeExactly '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
        }
        finally {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Remove-OpmAssignment' {

    It 'removes the assignment with the matching Entra group id' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}' -AssignmentType 'Required' | Out-Null
        Add-OpmAssignment -Fragment $app -MsEntraGroupId '{3D4E5F60-7182-93A4-B5C6-D7E8F9001122}' -AssignmentType 'Available' | Out-Null
        Remove-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}'
        $app.IntuneAssignments.Count | Should -Be 1
        $app.IntuneAssignments[0].MsEntraGroupId | Should -BeExactly '{3D4E5F60-7182-93A4-B5C6-D7E8F9001122}'
    }

    It 'removes when given a lowercase/unbraced Entra group id' {
        $app = New-OpmApplicationFragment -Name 'Acme'
        Add-OpmAssignment -Fragment $app -MsEntraGroupId '{2C3D4E5F-6071-8293-A4B5-C6D7E8F90011}' -AssignmentType 'Required' | Out-Null
        Remove-OpmAssignment -Fragment $app -MsEntraGroupId '2c3d4e5f-6071-8293-a4b5-c6d7e8f90011'
        $app.IntuneAssignments.Count | Should -Be 0
    }
}
