# PS Module to create vCD catalogs from supplied parameters
# Requires that you are already connected to the vCD API
# (Connect-CIServer) prior to running the command.
# 
# If you do not specify a storage profile then the catalog
# will be created on the first storage found in the first
# VDC created for the organisation.
#
# Requires 'Invoke-vCloud' module from PSGet (Install-Module Invoke-vCloud)
#
# Copyright 2018 Jon Waite, All Rights Reserved
# Released under MIT License - see https://opensource.org/licenses/MIT

Function CatalogToXML(
    [Parameter(Mandatory=$true)][string]$catName,
    [string]$catDesc
)
{
    # Create properly formed xml of type application/vnd.vmware.admin.catalog+xml:
    [xml]$newcatalog = New-Object System.Xml.XmlDocument
    $dec = $newcatalog.CreateXmlDeclaration("1.0","UTF-8",$null)
    $newcatalog.AppendChild($dec) | Out-Null
    $root = $newcatalog.CreateNode("element","AdminCatalog",$null)
    $desc = $newcatalog.CreateNode("element","Description",$null)
    $root.setAttribute("xmlns","http://www.vmware.com/vcloud/v1.5")
    $root.SetAttribute("name",$catName)
    $desc.innerText = $catDesc
    $root.AppendChild($desc) | Out-Null
    $newcatalog.AppendChild($root) | Out-Null
    return ($newcatalog.InnerXml)
}

Function New-Catalog(
    [Parameter(Mandatory=$true)][string]$vCDHost,
    [Parameter(Mandatory=$true)][string]$OrgName,
    [Parameter(Mandatory=$true)][string]$CatalogName,
    [string]$CatalogDescription
)
{
<#
.SYNOPSIS
Creates a new catalog in the specified vCloud Organization
.DESCRIPTION
New-Catalog provides an easy to use method for creating new Catalogs
within vCloud Director. It should work with any supported version of
the vCD API.
.PARAMETER vCDHost
A mandatory parameter which provides the cloud endpoint to be used.
.PARAMETER OrgName
A mandatory parameter containing the vCloud Organization Name for
which the catalog should be created.
.PARAMETER CatalogName
A mandatory parameter containing the name of the new catalog.
.PARAMETER CatalogDescription
An optional description of the new catalog.
.OUTPUTS
None
.EXAMPLE
New-Catalog vCDHost www.mycloud.com -Org MyOrg -CatalogName 'Test' -CatalogDescription 'My Test Catalog'
.NOTES
You must either have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session to use New-Catalog.
If you are not connected as a 'System' level administrator you will only
be able to create catalogs in your currently logged in Organization.
#>
    $mySessionID = ($Global:DefaultCIServers | Where-Object { $_.Name -eq $vCDHost }).SessionID
    if (!$mySessionID) {                    # If we didn't find an existing PowerCLI session for our URI
        Write-Error ("No vCloud session found for this URI, connect first using Connect-CIServer.")
        Return
    }

    $org = Get-Org -Name $OrgName
    if (!$org) {
        Write-Error ("Could not match $OrgName to a vCD Organization, exiting.")
        Return
    }

    $XMLcat = CatalogToXML -catName $CatalogName -catDesc $CatalogDescription

    $return = Invoke-vCloud -URI ($org.href + '/catalogs') -vCloudToken $mySessionID -ContentType 'application/vnd.vmware.admin.catalog+xml' -Method POST -Body $XMLcat

}

# Export function from module:
Export-ModuleMember -Function New-Catalog