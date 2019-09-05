# Add an element to a Path type string
Function Add-PathStringElement {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Element,

        [ValidateSet('Append', 'Prepend')]
        [String]$Action='Append',

        [Char]$PathSeparator=[IO.Path]::PathSeparator,
        [Char]$DirectorySeparator=[IO.Path]::DirectorySeparatorChar,

        [Switch]$NoRepair,
        [Switch]$SimpleAlgo
    )

    if (!$NoRepair) {
        $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
    }

    if (!$SimpleAlgo) {
        if ($Element.EndsWith($DirectorySeparator)) {
            $Element = $Element.TrimEnd($DirectorySeparator)
        }
        $Element += $DirectorySeparator
    }

    $RegExElement = [Regex]::Escape($Element)

    if (!$SimpleAlgo) {
        $RegExElement += '*'
    }

    $SingleElement = '^{0}$' -f $RegExElement
    if ($Path -notmatch $SingleElement) {
        $RegExPathSeparator = [Regex]::Escape($PathSeparator)
        $FirstElement       = '^{0}{1}' -f $RegExElement, $RegExPathSeparator
        $LastElement        = '{0}{1}$' -f $RegExPathSeparator, $RegExElement
        $MiddleElement      = '{0}{1}{2}' -f $RegExPathSeparator, $RegExElement, $RegExPathSeparator

        $Path = $Path -replace $FirstElement -replace $LastElement -replace $MiddleElement, $PathSeparator

        if (!$SimpleAlgo) {
            $Element = $PSBoundParameters.Item('Element')
        }

        switch ($Action) {
            'Append' {
                if ($Path.EndsWith($PathSeparator)) {
                    $Path = '{0}{1}' -f $Path, $Element
                } else {
                    $Path = '{0}{1}{2}' -f $Path, $PathSeparator, $Element
                }
            }

            'Prepend' {
                if ($Path.StartsWith($PathSeparator)) {
                    $Path = '{0}{1}' -f $Element, $Path
                } else {
                    $Path = '{0}{1}{2}' -f $Element, $PathSeparator, $Path
                }
            }
        }
    }

    return $Path
}

# Compare the properties of two objects
# Via: https://blogs.technet.microsoft.com/janesays/2017/04/25/compare-all-properties-of-two-objects-in-windows-powershell/
Function Compare-ObjectProperties {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [PSObject]$ReferenceObject,

        [Parameter(Mandatory)]
        [PSObject]$DifferenceObject,

        [String[]]$IgnoredProperties
    )

    $ObjProps = @()
    $ObjProps += $ReferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty Name
    $ObjProps += $DifferenceObject | Get-Member -MemberType Property, NoteProperty | Select-Object -ExpandProperty Name
    $ObjProps = $ObjProps | Sort-Object | Select-Object -Unique

    if ($IgnoredProperties) {
        $ObjProps = $ObjProps | Where-Object { $_ -notin $IgnoredProperties }
    }

    $ObjDiffs = @()
    foreach ($Property in $ObjProps) {
        $Diff = Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Property $Property

        if ($Diff) {
            $DiffProps = @{
                PropertyName=$Property
                RefValue=($Diff | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty $($Property))
                DiffValue=($Diff | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty $($Property))
            }

            $ObjDiffs += New-Object -TypeName PSObject -Property $DiffProps
        }
    }

    if ($ObjDiffs) {
        return ($ObjDiffs | Select-Object -Property PropertyName, RefValue, DiffValue)
    }
}

# Convert a string from Base64 form
Function ConvertFrom-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($String))
}

# Convert a string from URL encoded form
Function ConvertFrom-URLEncoded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    [Net.WebUtility]::UrlDecode($String)
}

# Convert a string to Base64 form
Function ConvertTo-Base64 {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

# Convert a text file to the given encoding
Function ConvertTo-TextEncoding {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseConsistentWhitespace', '')] # PSScriptAnalyzer bug
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [IO.FileInfo[]]$File,

        [ValidateSet('ASCII', 'UTF7', 'UTF8', 'UTF16', 'UTF16BE', 'UTF32', 'UTF32BE')]
        [String]$Encoding='UTF8',

        [Switch]$ByteOrderMark
    )

    Begin {
        switch ($Encoding) {
            ASCII       { $Encoder = New-Object -TypeName Text.ASCIIEncoding }
            UTF7        { $Encoder = New-Object -TypeName Text.UTF7Encoding }
            UTF8        { $Encoder = New-Object -TypeName Text.UTF8Encoding -ArgumentList $ByteOrderMark }
            UTF16       { $Encoder = New-Object -TypeName Text.UnicodeEncoding -ArgumentList @($false, $ByteOrderMark) }
            UTF16BE     { $Encoder = New-Object -TypeName Text.UnicodeEncoding -ArgumentList @($true, $ByteOrderMark) }
            UTF32       { $Encoder = New-Object -TypeName Text.UTF32Encoding -ArgumentList @($false, $ByteOrderMark) }
            UTF32BE     { $Encoder = New-Object -TypeName Text.UTF32Encoding -ArgumentList @($true, $ByteOrderMark) }
        }
    }

    Process {
        foreach ($TextFile in $File) {
            $Item = Get-Item -Path $TextFile
            $Content = Get-Content -Path $Item

            Write-Verbose -Message ('Converting: {0}' -f $Item.FullName)
            [IO.File]::WriteAllLines($Item.FullName, $Content, $Encoder)
        }
    }
}

# Convert a string to URL encoded form
Function ConvertTo-URLEncoded {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String
    )

    [Uri]::EscapeDataString($String)
}

# Beautify XML strings
# Via: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2016/12/31/how-to-pretty-print-xml-in-powershell-and-text-pipelines/
Function Format-Xml {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [String[]]$Xml
    )

    Begin {
        $Data = New-Object -TypeName Collections.ArrayList
    }

    Process {
        $null = $Data.Add($Xml -join [Environment]::NewLine)
    }

    End {
        $XmlDoc = New-Object -TypeName Xml.XmlDataDocument
        $XmlDoc.LoadXml($Data)

        $StringWriter = New-Object -TypeName IO.StringWriter
        $XmlTextWriter = New-Object -TypeName Xml.XmlTextWriter -ArgumentList $StringWriter
        $XmlTextWriter.Formatting = [Xml.Formatting]::Indented

        $XmlDoc.WriteContentTo($XmlTextWriter)
        $StringWriter.ToString()
    }
}

# Remove an element from a Path type string
Function Remove-PathStringElement {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Element,

        [Char]$PathSeparator=[IO.Path]::PathSeparator,
        [Char]$DirectorySeparator=[IO.Path]::DirectorySeparatorChar,

        [Switch]$NoRepair,
        [Switch]$SimpleAlgo
    )

    if (!$NoRepair) {
        $Path = Repair-PathString -String $Path -PathSeparator $PathSeparator
    }

    if (!$SimpleAlgo) {
        if ($Element.EndsWith($DirectorySeparator)) {
            $Element = $Element.TrimEnd($DirectorySeparator)
        }
        $Element += $DirectorySeparator
    }

    $RegExElement = [Regex]::Escape($Element)

    if (!$SimpleAlgo) {
        $RegExElement += '*'
    }

    $SingleElement = '^{0}$' -f $RegExElement
    if ($Path -match $SingleElement) {
        return [String]::Empty
    }

    $RegExPathSeparator = [Regex]::Escape($PathSeparator)
    $FirstElement       = '^{0}{1}' -f $RegExElement, $RegExPathSeparator
    $LastElement        = '{0}{1}$' -f $RegExPathSeparator, $RegExElement
    $MiddleElement      = '{0}{1}{2}' -f $RegExPathSeparator, $RegExElement, $RegExPathSeparator

    return $Path -replace $FirstElement -replace $LastElement -replace $MiddleElement, $PathSeparator
}

# Remove excess separators from a Path type string
Function Repair-PathString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$String,

        [Char]$PathSeparator=[IO.Path]::PathSeparator
    )

    $RegExPathSeparator = [Regex]::Escape($PathSeparator)
    $String -replace "^$RegExPathSeparator+" -replace "$RegExPathSeparator+$" -replace "$RegExPathSeparator{2,}", $PathSeparator
}

# Confirm a PowerShell command is available
Function Test-CommandAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name
    )

    foreach ($Command in $Name) {
        Write-Verbose -Message ('Checking command is available: {0}' -f $Command)
        if (!(Get-Command -Name $Command -ErrorAction Ignore)) {
            throw ('Required command not available: {0}' -f $Command)
        }
    }
}

# Confirm a PowerShell module is available
Function Test-ModuleAvailable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]$Name,

        [ValidateSet('Boolean', 'Exception')]
        [String]$Return='Exception'
    )

    foreach ($Module in $Name) {
        Write-Verbose -Message ('Checking module is available: {0}' -f $Module)
        if (Get-Module -Name $Module -ListAvailable) {
            if ($Return -eq 'Boolean') {
                return $true
            }
        } else {
            if ($Return -eq 'Boolean') {
                return $false
            } else {
                throw ('Required module not available: {0}' -f $Module)
            }
        }
    }
}

# Reload selected PowerShell profiles
Function Update-Profile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidDefaultValueSwitchParameter', '')]
    [CmdletBinding()]
    Param(
        [Switch]$AllUsersAllHosts,
        [Switch]$AllUsersCurrentHost,
        [Switch]$CurrentUserAllHosts,
        [Switch]$CurrentUserCurrentHost=$true
    )

    $ProfileTypes = @('AllUsersAllHosts', 'AllUsersCurrentHost', 'CurrentUserAllHosts', 'CurrentUserCurrentHost')
    foreach ($ProfileType in $ProfileTypes) {
        if (Get-Variable -Name $ProfileType -ValueOnly) {
            if (Test-Path -Path $profile.$ProfileType -PathType Leaf) {
                Write-Verbose -Message ('Sourcing {0} from: {1}' -f $ProfileType, $profile.$ProfileType)
                . $profile.$ProfileType
            } else {
                Write-Warning -Message ("Skipping {0} as it doesn't exist: {1}" -f $ProfileType, $profile.$ProfileType)
            }
        }
    }
}
