#######################################################################################
# Name: MonitorNetworkShare.ps1
# Description: Monitor a Network Share and writes result to WMI on remote server
#
# Dependances: Powershell 2.0 must be installed
# Parameters : remote server name, and share name
#
# Compatiblity : Windows Xp, Vista, 7, Windows server 2003, 2003 R2, 2008, 2008 R2
#
# Usage : 
#                1. MonitorNetworkShare.ps1 "REMOTESERVER" "REMOTESHARE" 
#                2. MonitorNetworkShare.ps1 "REMOTESERVER" "REMOTESHARE" "REMOTE"
#                3. MonitorNetworkShare.ps1 "REMOTESERVER" "REMOTESHARE" "LOCAL"
# EXAMPLE : MonitorNetworkShare.ps1 "W2003SBS" "ADMIN$" "LOCAL"
#
# 1 and 3 will write to local server WMI, 2 will write to remote server WMI being checked
#
# Version: 1.0
# Author: Marc-Andre Tanguay @ N-able Technologies
#######################################################################################

# Version History

# 1.0 - Initial Release (October 2st, 2012)


# 1.)	 \\lptshome01\home$
# 2.)	The same server where the nearest probe resides.

Param(
  [string]$remoteserver,
  [string]$remoteshare,
  [string]$writetype
)

if ($writetype)
{
    $writetype=$writetype.toupper()
}
else
{
    $writetype="LOCAL"
}


$ns=[wmiclass]'__namespace'
if ($writetype -eq "REMOTE")
{
    $ns.path="\\"+$remoteserver+"\ROOT\cimv2:__NAMESPACE"
}
$ns.Methods
$sc=$ns.CreateInstance()
$sc.Name='nable'
$sc.Put()
$file="c:\temp\file1.txt"

$ImageFiles = "\\" + $remoteserver + "\" + $remoteshare
$ValidPath = Test-Path $ImageFiles -PathType Container 
Test-Path $ImageFiles -PathType Container
$ImageFiles 
If ($ValidPath -eq $True) {Write-Host "Path is OK"}
Else {Write-Host "Mistake in ImageFiles variable"}

if ($writetype -eq "REMOTE")
{
    $computername=$remoteserver
}
else
{
    $computername=HOSTNAME 
}
 
if ((get-wmiobject -computername $computername -namespace "root/cimv2/nable" -list -EV namespaceError) | ? {$_.name -match "NetworkShareValid"})
{
    ##  Deletes the old Instances of the Class NetworkShareValid
   
    $dbcount = New-Object system.Collections.ArrayList
    ## checking for the Class in root/nable namespace
    $testfolder=Get-WMIObject -computername $computername -namespace root/cimv2/nable -query "Select * From NetworkShareValid"
    $rr=0;
    Get-WMIObject -computername $computername -namespace root/cimv2/nable -query "Select * From NetworkShareValid" | foreach {$dbcount.Insert($rr, $_);$rr++ }

    $dbcnt=$dbcount.count
    if($dbcount.count -ge '1')
    {
        $testfolder | Remove-WMIObject
    }  

}
else
{


    if( ![string]::IsNullOrEmpty( $namespaceError[0] ) )
    {
    	add-content $file "ERROR accessing namespace: $namespaceError[0]"
    	RETURN
    }

    try 
    {
    

    $classpath="\\" + $computername + "\root\cimv2\nable"
        $newClass = New-Object System.Management.ManagementClass  ($classpath, [String]::Empty, $null); 
        $newClass["__CLASS"] = "NetworkShareValid"; 

        $newClass.Qualifiers.Add("Static", $true)

        $newClass.Properties.Add("LastCheckDate", [System.Management.CimType]::String, $false)
        $newClass.Properties.Add("ShareOK", [System.Management.CimType]::UInt32, $false)
        $newClass.Properties.Add("ServerFrom", [System.Management.CimType]::String, $false)
        $newClass.Properties.Add("ServerTo", [System.Management.CimType]::String, $false)
        $newClass.Properties.Add("ShareName", [System.Management.CimType]::String, $false)


        $newClass.Properties["LastCheckDate"].Qualifiers.Add("key", $true)
        $newClass.Properties["ShareOK"].Qualifiers.Add("key", $true)
        $newClass.Properties["ServerFrom"].Qualifiers.Add("key", $true)
        $newClass.Properties["ServerTo"].Qualifiers.Add("key", $true)
        $newClass.Properties["ShareName"].Qualifiers.Add("key", $true)

        $newClass.Put()
    }
    catch
    {
        add-content $file "ERROR creating WMI class: $_"
    }
    
}
try 
{
    if ($writetype -eq "REMOTE")
    {
        $remotepath = "\\" + $remoteserver + "\root\cimv2\nable:NetworkShareValid"
        $wmicls = ([wmiclass]$remotepath).CreateInstance()
    }
    else
    {
        $wmicls = ([wmiclass]"\\.\root\cimv2\nable:NetworkShareValid").CreateInstance()
    }

    $wmicls.LastCheckDate= get-date
    if($ValidPath -eq $True)
    {
        $wmicls.ShareOK= 1
    }
    else
    {
        $wmicls.ShareOK= 0
    }
    $wmicls.ServerFrom=hostname
    $wmicls.ServerTo=$remoteserver
    $wmicls.ShareName=$remoteshare

    $wmicls.Put() 
}
catch
{
    add-content $file "ERROR creating a new instance: $_"
}

