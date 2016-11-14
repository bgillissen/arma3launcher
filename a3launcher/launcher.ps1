# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# File:			launcher.ps1
# Version:		V0.1
# Author:		Ben 2016
# Contributers:	None
#
# Arma3 Server (re)starter for TFU
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

Write-Host ""
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host "			 TaskForceUnicorn Arma3 Launcher by Ben"
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host ""
Write-Host "Initializing..."

$Script:srvWait = 90
$Script:hlWait = 90
$Script:loopWait = 5
$Script:killWait = 10
$script:crashWait = 5
$Script:crashTry = 5
$Script:A3Run = $false
$Script:BECRun = $false
$Script:A3HLRun = @($null,$false,$false, $false)
$Script:a3hlID = @($null,$null,$null,$null)
$Script:keyCount = 0

# Parsing main config-file
Get-Content "common.cfg" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,' = '); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
$Script:pidPath = $h.Get_Item("pid")
$Script:a3Path = $h.Get_Item("path")
$script:a3Exe = "$a3Path\arma3server.exe"
$Script:profilePath = $h.Get_Item("profile")
$Script:modPath = $h.Get_Item("mods")
$Script:becPath = $h.Get_Item("bec")
$Script:becExe = "$becPath\Bec.exe"

# Parsing given config-file
Get-Content "$args" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,' = '); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
$script:srvName = $h.Get_Item("srv")
$Script:pidFilename = $h.Get_Item("pid")
$Script:pidFile = "$pidPath\$pidFilename"
$Script:profileName = $h.Get_Item("name")
$Script:port = $h.Get_Item("port")
$Script:cfg = $h.Get_Item("cfg")
$Script:config = $h.Get_Item("config")
$Script:param = $h.Get_Item("param")
$Script:mods = $h.Get_Item("mods")
$Script:cltMods = $h.Get_Item("cltMods")
$Script:srvMods = $h.Get_Item("srvMods")
$Script:cpKeys = ($h.Get_Item("cpkeys") -eq "true")
$Script:hlCount = $h.Get_Item("hlcount")
$Script:hlConnect = $h.Get_Item("hlconnect")
$Script:hlPassword = $h.Get_Item("hlpassword")
$Script:hlParam = $h.Get_Item("hlparam")
$Script:usebec = ($h.Get_Item("usebec") -eq "true")
$Script:beconfig = $h.Get_Item("beconfig")
$Script:becPid = "$pidPath\BEC_$pidFilename"
$Script:extraKeys = "$profilePath\Users\$profileName\extrakeys"
$Script:globalKeys = "$profilePath\globalkeys"

if ( $hlCount -gt 0 ){
	$Script:hlPid = @($null, "$pidPath\hl1_$pidFilename", "$pidPath\hl2_$pidFilename", "$pidPath\hl3_$pidFilename")
}

$host.ui.RawUI.WindowTitle = "TFU Launcher: $srvName"

Function initFailed($msg){
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - $($msg), exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	Read-Host 'Press enter to exit'
	exit
}

#Prerun checks
if ( !(Test-Path $a3Path -PathType container) ){
	initFailed "Invalid value in common.cfg, path setting : $a3Path is not a folder!"
} elseif ( !(Test-Path $a3Exe) ){
	initFailed "Invalid value in common.cfg, path setting: $a3Exe was not found!"
} elseif ( !(Test-Path $pidPath -PathType container) ){
	initFailed "Invalid value in common.cfg, pid setting: $pidPath is not a folder!"
} elseif ( !(Test-Path $profilePath -PathType container) ){
	initFailed "Invalid value in common.cfg, profile setting: $profilePath is not a folder!"
}
if ( $usebec -eq "true" ){
	if ( !(Test-Path $becPath -PathType container) ){
		initFailed "Invalid value in common.cfg, bec setting : $becPath is not a folder!"
	} elseif ( !(Test-Path $a3Exe) ){
		initFailed "Invalid value in common.cfg, bec setting: $becExe was not found!"
	}
}
if ( !(Test-Path "$a3Path\$cfg") ){
	initFailed "Invalid value in $args, cfg setting: $a3Path\$cfg was not found!"
} elseif ( !(Test-Path "$a3Path\$config") ){
	initFailed "Invalid value in $args, config setting: $a3Path\$config was not found!"
}

# Check that a given process exists and is responding
Function isRunning($exe, $procID){
	$procObj = Get-Process $exe -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $procID }
	if ( !$procObj ){ 
		return $false 
	}
	if ( $procObj.Responding ){ 
		return $procObj 
	}
	for($i=1;$i -le $crashTry; $i++){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - Process $procID is not responding (attempt $i / 5), waiting $($crashWait)s..."  -BackgroundColor "Red" -ForegroundColor "white"
		Start-Sleep -s $crashWait
		$procObj = Get-Process $exe -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $procID }
		if ( !$procObj ){
			$a=(Get-Date).ToUniversalTime()
			Write-Host "$a - Process $procID does not exists anymore, marked as dead"  -BackgroundColor "Red" -ForegroundColor "white"
			return $false 
		}
		if ( $procObj.Responding ){
			$a=(Get-Date).ToUniversalTime()
			Write-Host "$a - Process $procID has responded"
			return $procObj
		}
	}
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Process $procID is not responding after 5 attempts, considered dead"  -BackgroundColor "Red" -ForegroundColor "white"
	return $false
}

# Arma 3 server management functions
Function removeKeys {
	$keyFiles = get-childitem -LiteralPath "$a3Path\keys" -recurse | Where-Object { $_.Name -match ".bikey$" -and $_.Name -notLike "a3.bikey" }
	if ( ($keyFiles | Measure-Object).count -gt 0 ){
		foreach($keyFile in $keyFiles){
			$fname = $keyFile.fullName
			remove-item -LiteralPath $keyFile.fullName
		}
	}
	$Script:keyCount = 0
}
Function importKeys($mods=$null){
	if ( !($mods) ){
		if (test-path $globalKeys -PathType container){ copyKeys $globalKeys }
		if (test-path $extraKeys -PathType container){ copyKeys $extraKeys }
	} else {
		$option = [System.StringSplitOptions]::RemoveEmptyEntries
		$modArray = $mods.Split(";", $option)
		foreach($mod in $modArray){ copyKeys "$modPath\$mod" }
	}
}
Function copyKeys($from){
	if ( !(test-path "$from" -PathType container) ){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $from folder was not found, no keys were imported!"  -BackgroundColor "Red" -ForegroundColor "white"
		return
	}
	$keyFiles = get-childitem -LiteralPath $from -recurse | Where-Object { $_.Name -match ".bikey$" }
	$count += ($keyFiles | Measure-Object).count
	if (  $count -gt 0 ){
		foreach($keyFile in $keyFiles){
			$fname = $keyFile.Name
			$dest = "$a3Path\keys\$fname"
			Copy-Item -literalPath $keyFile.fullName -Destination $dest 
		}
	}
	$Script:keyCount += $count
}
Function start_A3 {
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Removing keys"
	removeKeys
	
	if ( $cpKeys ){
		importKeys $null
		importKeys $cltMods
		importKeys $srvMods
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $keyCount keys imported for $srvName"
	}
	
	$option = [System.StringSplitOptions]::RemoveEmptyEntries
	$modArray = $cltMods.Split(";", $option)
	$cltStr = ""
	foreach($mod in $modArray){ $cltStr += "$modPath\$mod;" }
	$modArray = $srvMods.Split(";", $option)
	$srvStr = ""
	foreach($mod in $modArray){ $srvStr += "$modPath\$mod;" }
	
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Starting: $srvName on port: $port"
	
	$Script:a3ID = Start-Process arma3server.exe "$param -port=$port -profiles=$profilePath -name=$profileName -config=$config -cfg=$cfg -mod=$cltStr -servermod=$srvStr" -WorkingDirectory $a3Path -passthru
	
	$a=(Get-Date).ToUniversalTime()
	if ( !$a3ID ){
		Write-Host "$a - $srvName failed to start"  -BackgroundColor "Red" -ForegroundColor "white"
		$Script:a3Run = $false;
	} else {
		Write-Host "$a - $srvName started with PID: $($a3ID.Id)"
		Set-Content $pidFile "$($a3ID.Id)"
		$Script:a3Run = $true;
	}
}
function kill_A3 {
	isA3Running
	if ($A3Run) {
		pid = $($a3ID.Id)
		Stop-Process $pid
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a  -  $srvName with PID: $pid has been killed"
		Set-Content $pidFile ""
	}
}
function isA3Running {
	$Script:a3Run = $false
	if ( !$a3ID ){
		if ( Test-Path $pidfile ){
			$storedPID = Get-Content $pidFile
		}
		if ( $storedPID ){
			$Script:a3ID = isRunning "arma3server" $storedPID
			if ( $a3ID ){
				$Script:a3Run = $true
			}
		}
	} else {
		$Script:a3ID = isRunning "arma3server" $a3ID.Id
		if ( $a3ID ){
			$Script:a3Run = $true
		}
	}
}


# BEC management functions
Function start_BEC {
	$a=(Get-Date).ToUniversalTime()
	$b = "$a - Starting: BEC for $srvName with: $beconfig"
	Write-Host "$b"
	
	$Script:becID = Start-Process $becExe "-f $beconfig --dsc" -WorkingDirectory $becPath -passthru
	
	$a=(Get-Date).ToUniversalTime()
	if ( !$becID ){
		Write-Host "$a - $srvName BEC failed to start"  -BackgroundColor "Red" -ForegroundColor "white"
	} else {
		Write-Host "$a - $srvName BEC started with PID: $($becID.Id)"
		Set-Content $becPid "$($becID.Id)"
	}
}
function kill_BEC {
	isBECRunning
	if ($BECRun) {
		pid = $($becID.Id)
		Stop-Process $pid
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $srvName BEC with PID: $pid has been killed"
		Set-Content $pidFile ""
	}
}
function isBECRunning {
	$Script:becRun = $false
	if ( !$becID ){
		if ( Test-Path $becPid ){
			$storedPID = Get-Content $becPid
		}
		if ( $storedPID ){
			$Script:becID = isRunning "Bec" $StoredPID
			if ( $becID ){
				$Script:becRun = $true
			}
		}
	} else {
		$Script:becID = isRunning "Bec" $becID.Id
		if ( $becID ){
			$Script:becRun = $true
		}
	}
}



#Arma 3 headless clients management functions
function start_A3HL($key){
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Starting: $srvName headless client ($key)"
	
	$pass = ""
	if ( $hlPassword ){
		$pass = "-password=$hlPassword"
	}
	#adding modPath to needed mods
	$option = [System.StringSplitOptions]::RemoveEmptyEntries
	$modArray = $cltMods.Split(";", $option)
	$cltStr = ""
	foreach($mod in $modArray){ $cltStr += "$modPath\$mod;" }
	
	$Script:a3hlID[$key] = Start-Process arma3server.exe "-client $hlParam -profiles=$profilePath -mod=$cltStr -connect $hlconnect $pass" -WorkingDirectory $a3Path -passthru
	
	$a=(Get-Date).ToUniversalTime()
	if ( !$a3hlID[$key] ){
		Write-Host "$a - $srvName headless client ($key) failed to start"  -BackgroundColor "Red" -ForegroundColor "white"
	} else {
		Write-Host "$a - $srvName headless client ($key) started with PID: $($a3hlID[$key].Id)"
		Set-Content $hlPid[$key] "$($a3hlID[$key].Id)"
	}
}
function kill_A3HL($key){
	isA3HLRunning $key
	if ($A3HLRun[$key]) {
		Stop-Process $($a3hlID[$key].Id)
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $srvName headless client ($key) with PID: $($a3hlID[$key].Id) has been killed"
		Set-Content $hlPid[$key] ""
	}
}
function isA3HLRunning($key){
	$Script:A3HLRun[$key] = $false;
	if ( !$a3hlID[$key] ){
		if ( Test-Path $hlPid[$key] ){
			$storedPID = Get-Content $hlPid[$key]
		}
		if ( $storedPID ){
			$Script:a3hlID[$key] = isRunning "arma3server" $storedPID
			if ( $a3hlID[$key] ){
				$Script:A3HLRun[$key] = $true;
			}
		}
	} else {
		$Script:a3hlID[$key] = isRunning "arma3server" $a3hlID[$key].Id
		if ( $a3hlID[$key] ){
			$Script:A3HLRun[$key] = $true;
		}
	}
}

if ( $usebec -eq "true" ){
	Write-Host "BEC is enabled."
} else {
	Write-Host "BEC is disabled."
}
Write-Host "$hlCount headless client(s) will be launched."
Write-Host "Entering the loop..."


# Main loop
$Script:loop = 0;
$Script:firstLoop = $true;
Do {
	# check if Arma server is running
	IsA3Running
	if (!$A3Run){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $srvName is not running, starting..." -BackgroundColor "Red" -ForegroundColor "white"
		if ( $usebec -eq "true" ){
			kill_BEC
			Start-Sleep -s $killWait
		}
		if ( $hlCount -gt 0 ){
			for($i=1; $i -le $hlCount; $i++){ 
				kill_A3HL $i 
				Start-Sleep -s $killWait
			}
		}
		start_A3
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - Waiting $($srvWait)s for server to init..."
		Start-Sleep -s $srvWait
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - Done."
	} elseif ( $firstLoop ){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $srvName is already running with PID: $($a3ID.id)"
	}
	if ( $usebec ){
		# checking if BEC is running
		IsBECRunning
		if ($A3Run -and !$BECRun){
			$a=(Get-Date).ToUniversalTime()
			Write-Host "$a - $srvName BEC is not running, starting..." -BackgroundColor "Red" -ForegroundColor "white"
			kill_BEC
			Start-Sleep -s $killWait
			start_BEC
		} elseif ( $firstLoop ){
			$a=(Get-Date).ToUniversalTime()
			Write-Host "$a - $srvName BEC is already running with PID: $($becID.id)"
		}
	}
	if ( $hlCount -gt 0 -and $A3Run){
		#checking if Arma headless clients are running
		for($i=1; $i -le $hlCount; $i++){
			isA3HLRunning $i
			if (!$A3HLRun[$i]){
				$a=(Get-Date).ToUniversalTime()
				Write-Host "$a - $srvName headless client ($i) is not running, starting..." -BackgroundColor "Red" -ForegroundColor "white"
				kill_A3HL $i
				Start-Sleep -s $killWait
				start_A3HL $i
				$a=(Get-Date).ToUniversalTime()
				Write-Host "$a - Waiting $($hlWait)s for headless client to init..."
				Start-Sleep -s $hlWait
				$a=(Get-Date).ToUniversalTime()
				Write-Host "$a - Done."
			} elseif ( $firstLoop ){
				$a=(Get-Date).ToUniversalTime()
				Write-Host "$a - $srvName headless client ($i) is already running with PID: $($a3hlID[$i].id)"
			}
		}
	}
	$Script:firstLoop = $false;
	Start-Sleep -s $loopWait
	
} While ($true)