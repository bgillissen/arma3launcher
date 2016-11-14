# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# File:			updater.ps1
# Version:		V0.1
# Author:		Ben 2016
# Contributers:	None
#
# Arma3 Server Updater for TFU
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
If ( -NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") ){   
	#"No Administrative rights, it will display a popup window asking user for Admin rights"
	$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $arguments
	exit
}

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
set-Location $scriptDir

$Script:modList = ( #name, workshop id, pathname (used in server .cfg)
					("CBA_A3", "450814997", "cba"),
					("task_force_radio", "620019431", "tfar"),
					("ace", "463939057", "ace"),
					("ACE3 RHS compatibility files", "698224854", "acerhs"),
					("ACEX", "708250744", "acex"),
					("Arma Enhanced Movement", "333310405", "AEM"),
					("Advanced Rappelling", "713709341", "AR"),
					("Advanced Urban Rappelling", "730310357", "AUR"),
					("Advanced Sling Loading", "615007497", "ASL"),
					("Advanced Towing", "639837898", "AT"),
					("Static Line Jump", "727184590", "SLJ"),
					("Cup Terrains - Core", "583496184", "cupCore"),
					("Cup Terrains - Maps", "583544987", "cupMaps"),
					("Kunduz, Afghanistan", "421620913", "kunduz"),
					("Project OPFOR", "735566597", "projectOPFOR")
				)
				
Write-Host ""
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host "			 TaskForceUnicorn Arma3 Updater by Ben"
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host ""


Function New-SymLink ($link, $target)
{
    if (test-path -pathtype container $target){
        $command = "cmd /c mklink /d"
    } else {
        $command = "cmd /c mklink"
    }
    invoke-expression "$command $link $target"
}

# Parsing main config-file
Get-Content "common.cfg" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,' = '); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
$Script:steamPath = $h.Get_Item("steam")
$Script:steamExe = "$steamPath\steamcmd.exe"
$Script:steamLogin = $h.Get_Item("steamLogin")
$Script:a3Path = $h.Get_Item("path")
$Script:modPath = $h.Get_Item("mods")

#building steamcmd commandline				
$workshopItems = ""
foreach($mod in $modList ){
	if ( $mod[1] ){
		$id = $mod[1]
		$workshopItems += "+workshop_download_item 107410 $id "
	}
}
$Script:cmdArgs = "+login $steamLogin +force_install_dir $a3Path $workshopItems +`"app_update 233780 -beta`" validate +quit"

#launching steamcmd
Start-Process -FilePath $steamExe  -NoNewWindow -Wait -ArgumentList $cmdArgs

#creating symlinks, if needed
foreach($mod in $modList ){
	if ( $mod[1] ){
		$id = $mod[1]
		$folder = $mod[2]
		$link = "$modPath\!$folder"
		$target = "$steamPath\steamapps\workshop\content\107410\$id"
		if ( !(test-path $link) -and (test-path $target) ){ New-SymLink $link $target }
	}
}

Read-Host 'Press enter to exit'