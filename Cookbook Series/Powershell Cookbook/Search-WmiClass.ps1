##############################################################################
##
## Search-WmiNamespace.ps1
##
## From Windows PowerShell Cookbook (O'Reilly)
## by Lee Holmes (http://www.leeholmes.com/guide)
##
## Search the WMI classes installed on the system for the provided match text.
##
## ie:
##
##  PS >Search-WmiNamespace Registry
##  PS >Search-WmiNamespace Process ClassName,PropertyName
##  PS >Search-WmiNamespace CPU -Detailed
##
##############################################################################

param(
    [string] $pattern = $(throw "Please specify a search pattern."),
    [switch] $detailed,
    [switch] $full,

    ## Supports any or all of the following match options:
    ## ClassName, ClassDescription, PropertyName, PropertyDescription
    [string[]] $matchOptions = ("ClassName","ClassDescription")
)

## Helper function to create a new object that represents 
## a Wmi match from this script
function New-WmiMatch
{
    param( $matchType, $className, $propertyName, $line )

    $wmiMatch = New-Object PsObject
    $wmiMatch | Add-Member NoteProperty MatchType $matchType
    $wmiMatch | Add-Member NoteProperty ClassName $className
    $wmiMatch | Add-Member NoteProperty PropertyName $propertyName
    $wmiMatch | Add-Member NoteProperty Line $line

    $wmiMatch
}

## If they've specified the -detailed or -full options, update
## the match options to provide them an appropriate amount of detail
if($detailed)
{
    $matchOptions = "ClassName","ClassDescription","PropertyName"
}

if($full)
{
    $matchOptions = 
        "ClassName","ClassDescription","PropertyName","PropertyDescription"
}

## Verify that they specified only valid match options
foreach($matchOption in $matchOptions)
{
    $fullMatchOptions =
        "ClassName","ClassDescription","PropertyName","PropertyDescription"

    if($fullMatchOptions -notcontains $matchOption)
    {
        $error = "Cannot convert value {0} to a match option. " +
                 "Specify one of the following values and try again. " +
                 "The possible values are ""{1}""."
        $ofs = ", "
        throw ($error -f $matchOption, ([string] $fullMatchOptions))
    }
}

## Go through all of the available classes on the computer
foreach($class in Get-WmiObject -List)
{
    ## Provide explicit get options, so that we get back descriptios
    ## as well
    $managementOptions = New-Object System.Management.ObjectGetOptions
    $managementOptions.UseAmendedQualifiers = $true
    $managementClass = 
        New-Object Management.ManagementClass $class.Name,$managementOptions
    
    ## If they want us to match on class names, check if their text
    ## matches the class name
    if($matchOptions -contains "ClassName")
    {
        if($managementClass.Name -match $pattern)
        {
            New-WmiMatch "ClassName" `
                $managementClass.Name $null $managementClass.__PATH
        }
    }

    ## If they want us to match on class descriptions, check if their text
    ## matches the class description
    if($matchOptions -contains "ClassDescription")
    {
        $description = 
            $managementClass.PsBase.Qualifiers | 
                foreach { if($_.Name -eq "Description") { $_.Value } }
        if($description -match $pattern)
        {
            New-WmiMatch "ClassDescription" `
                $managementClass.Name $null $description
        }
    }

    ## Go through the properties of the class
    foreach($property in $managementClass.PsBase.Properties)
    {
        ## If they want us to match on property names, check if their text
        ## matches the property name
        if($matchOptions -contains "PropertyName")
        {
            if($property.Name -match $pattern)
            {
                New-WmiMatch "PropertyName" `
                    $managementClass.Name $property.Name $property.Name
            }
        }

        ## If they want us to match on property descriptions, check if 
        ## their text matches the property name
        if($matchOptions -contains "PropertyDescription")
        {
            $propertyDescription = 
                $property.Qualifiers | 
                    foreach { if($_.Name -eq "Description") { $_.Value } }
            if($propertyDescription -match $pattern)
            {
                New-WmiMatch "PropertyDescription" `
                    $managementClass.Name $property.Name $propertyDescription
            }
        }
    }
}