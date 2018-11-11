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
    [string]$catDesc,
    [string]$orgName,
    [string]$sprof
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
    
    # Attempt to match Storage Profile specified (if any) and use that for catalog creation XML:
    if ($sprof) {
        $sprofhref = ""
        $vdcs = Get-OrgVdc -Org $orgName
        foreach($vdc in $vdcs){
            $sprofs = $vdc.ExtensionData.VdcStorageProfiles.VdcStorageProfile
            foreach($vdcsprof in $sprofs){
                if ($vdcsprof.Name -eq $sprof) {
                    $sprofhref = $vdcsprof.href
                }
            } # each VDC Storage Profile in this VDC
        } # each VDC in this Org
        if ($sprofhref) {
            # Found/matched this storage profile, add specification to the catalog creation XML:
            Write-Host ("Matched Storage Profile '$sprof' in this Org, catalog will be created in this Storage Profile.")
            $catsp = $newcatalog.CreateNode("element","CatalogStorageProfiles",$null)
            $sprofelem = $newcatalog.CreateNode("element","VdcStorageProfile",$null)
            $sprofelem.setAttribute("href",$sprofhref)
            #$sprofelem.setAttribute("href","https://chcdev.cloud.concepts.co.nz/api/vdcStorageProfile/d0897343-0d09-4090-89bc-e0819d2281be")
            $catsp.AppendChild($sprofelem) | Out-Null
            $root.AppendChild($catsp) | Out-Null
        } else {
            Write-Warning ("Could not match Storage Profile '$sprof' in this Org, default storage will be used.")
        }
    }
    $newcatalog.AppendChild($root) | Out-Null
    return ($newcatalog.InnerXml)
}

Function New-Catalog(
    [Parameter(Mandatory=$true)][string]$vCDHost,
    [Parameter(Mandatory=$true)][string]$OrgName,
    [Parameter(Mandatory=$true)][string]$CatalogName,
    [string]$CatalogDescription,
    [string]$StorageProfile
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
.PARAMETER StorageProfile
An optional storage profile on which the new catalog should be created,
if not specified any available storage profile will be used.
.OUTPUTS
None
.EXAMPLE
New-Catalog vCDHost www.mycloud.com -Org MyOrg -CatalogName 'Test'
    -CatalogDescription 'My Test Catalog'
.NOTES
You must either have an existing PowerCLI connection to vCloud Director
(Connect-CIServer) in your current PowerShell session to use New-Catalog.
If you are not connected as a 'System' level administrator you will only
be able to create catalogs in your currently logged in Organization.
#>
    $mySessionID = ($Global:DefaultCIServers | Where-Object { $_.Name -eq $vCDHost }).SessionID
    if (!$mySessionID) {            # If we didn't find an existing PowerCLI session for our URI
        Write-Error ("No vCloud session found for this URI, connect first using Connect-CIServer.")
        Return
    }

    $org = Get-Org -Name $OrgName
    if (!$org) {
        Write-Error ("Could not match $OrgName to a vCD Organization, exiting.")
        Return
    }

    # Construct 'body' XML representing the new catalog to be created:
    $XMLcat = CatalogToXML -catName $CatalogName -catDesc $CatalogDescription -OrgName $OrgName -sprof $StorageProfile
    
    # Call VCD API to create catalog:
    Invoke-vCloud -URI ($org.href + '/catalogs') -vCloudToken $mySessionID -ContentType 'application/vnd.vmware.admin.catalog+xml' -Method POST -Body $XMLcat | Out-Null
}

# Export function from module:
Export-ModuleMember -Function New-Catalog