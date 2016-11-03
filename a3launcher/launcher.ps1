# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# File:			launcher.ps1
# Version:		V0.1
# Author:		Ben 2016
# Contributers:	None
#
# Arma3 Server (re)starter for TFU
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

$Script:IntervalShort = 1
$Script:IntervalMedium = 3
$Script:IntervalLong = 20
$Script:A3Run = $false
$Script:BECRun = $false
$Script:A3HLRun = @($null,$false,$false, $false)
$Script:a3hlID = @($null,$null,$null,$null)

Write-Host ""
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host "			 TaskForceUnicorn Arma3 Launcher by Ben"
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host ""
Write-Host "Initializing..."

# Parsing main config-file
Get-Content "common.cfg" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,' = '); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
$Script:pidPath = $h.Get_Item("pid")
$Script:a3Path = $h.Get_Item("path")
$script:a3Exe = "$a3Path\arma3server.exe"
$Script:profilePath = $h.Get_Item("profile")
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
$Script:srvMods = $h.Get_Item("srvMods")
$Script:headless = $h.Get_Item("headless")
$Script:hlConnect = $h.Get_Item("hlconnect")
$Script:usebec = $h.Get_Item("usebec")
$Script:beconfig = $h.Get_Item("beconfig")
$Script:becPid = "$pidPath\BEC_$pidFilename"

if ( $headless -gt 0 ){
	$Script:hlPid = @($null, "$pidPath\hl1_$pidFilename", "$pidPath\hl2_$pidFilename", "$pidPath\hl3_$pidFilename")
}

$host.ui.RawUI.WindowTitle = "TFU Launcher: $srvName"


#Prerun checks
$a=(Get-Date).ToUniversalTime()
if ( !(Test-Path $a3Path -PathType container) ){
	Write-Host "$a - Invalid value in common.cfg, path setting : $a3Path is not a folder!, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	exit
} elseif ( !(Test-Path $a3Exe) ){
	Write-Host "$a - Invalid value in common.cfg, path setting: $a3Exe was not found!, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	exit
} elseif ( !(Test-Path $pidPath -PathType container) ){
	Write-Host "$a - Invalid value in common.cfg, pid setting: $pidPath is not a folder !, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	exit
} elseif ( !(Test-Path $profilePath -PathType container) ){
	Write-Host "$a - Invalid value in common.cfg, profile setting: $profilePath is not a folder!, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	exit
}
if ( $usebec -eq "true" ){
	if ( !(Test-Path $becPath -PathType container) ){
		Write-Host "$a - Invalid value in common.cfg, bec setting : $becPath is not a folder!, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
		exit
	} elseif ( !(Test-Path $a3Exe) ){
		Write-Host "$a - Invalid value in common.cfg, bec setting: $becExe was not found!, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
		exit
	}
}
if ( !(Test-Path "$a3Path\$cfg") ){
	Write-Host "$a - Invalid value in $args, cfg setting: $a3Path\$cfg was not found!, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	exit
} elseif ( !(Test-Path "$a3Path\$config") ){
	Write-Host "$a - Invalid value in $args, config setting: $a3Path\$config was not found!, exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	exit
}


# Arma 3 server management functions
Function start_A3 {
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Starting: $srvName on port: $port"
	
	$Script:a3ID = Start-Process arma3server.exe "$param -port=$port -profiles=$profilePath -name=$profileName -config=$config -cfg=$cfg -mod=$mods -servermod=$srvMods" -WorkingDirectory $a3Path -passthru
	Start-Sleep -s $IntervalMedium
	
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
		$b = "$a  -  $srvName with PID: $pid has been killed"
		Write-Host "$b"
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
			$Script:a3ID = Get-Process arma3server -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $storedPID } | Where-Object {$_.Responding -eq $true}
			if ( $a3ID ){
				$Script:a3Run = $true
			}
		}
	} else {
		$Script:a3ID = Get-Process arma3server -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $($a3ID.Id) } | Where-Object {$_.Responding -eq $true}
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
	Start-Sleep -s $IntervalMedium
	
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
			$Script:becID = Get-Process Bec -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $storedPID } | Where-Object {$_.Responding -eq $true}
			if ( $becID ){
				$Script:becRun = $true
			}
		}
	} else {
		$Script:becID = Get-Process Bec -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $($becID.Id) } | Where-Object {$_.Responding -eq $true}
		if ( $becID ){
			$Script:becRun = $true
		}
	}
}



#Arma 3 headless clients management functions
function start_A3HL($key){
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Starting: $srvName headless client ($key)"
	
	$Script:a3hlID[$key] = Start-Process arma3server.exe "-client -profiles=$profilePath -mod=$mods -connect $hlconnect" -WorkingDirectory $a3Path -passthru
	Start-Sleep -s $IntervalMedium
	
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
			$Script:a3hlID[$key] = Get-Process arma3server -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $storedPID } | Where-Object {$_.Responding -eq $true}
			if ( $a3hlID[$key] ){
				$Script:A3HLRun[$key] = $true;
			}
		}
	} else {
		$Script:a3hlID[$key] = Get-Process arma3server -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $($a3hlID[$key].Id) } | Where-Object {$_.Responding -eq $true}
		if ( $a3hlID[$key] ){
			$Script:A3HLRun[$key] = $true;
		}
	}
}
function killall_A3HL {
	if ( $headless -gt 0 ){
		for($i=1; $i -le 3; $i++){ kill_A3HL $i }
	}
}


if ( $usebec -eq "true" ){
	Write-Host "BEC is enabled."
} else {
	Write-Host "BEC is disabled."
}
Write-Host "$headless headless client(s) will be launched."
Write-Host "Entering the loop..."
# Main loop
$Script:loop = 0;
$Script:firstLoop = $true;
Do {
	# check if Arma server is running
	IsA3Running
	if (!$A3Run){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $srvName is not running: starting ..." -BackgroundColor "Red" -ForegroundColor "white"
		Start-Sleep -s $IntervalMedium
		if ( $usebec -eq "true" ){
			kill_BEC
			Start-Sleep -s $IntervalMedium
		}
		killall_A3HL
		Start-Sleep -s $IntervalMedium
		start_A3
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - Waiting for server to init..."
		Start-Sleep -s $IntervalLong
		Start-Sleep -s $IntervalLong
		Start-Sleep -s $IntervalLong
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - Done."
	} elseif ( $firstLoop ){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $srvName is already running with PID: $($a3ID.id)"
	}
	if ( $usebec -eq "true" ){
		# checking if BEC is running
		IsBECRunning
		if ($A3Run -and !$BECRun){
			$a=(Get-Date).ToUniversalTime()
			Write-Host "$a - $srvName BEC is not running: starting ... " -BackgroundColor "Red" -ForegroundColor "white"
			kill_BEC
			Start-Sleep -s $IntervalMedium
			start_BEC
		} elseif ( $firstLoop ){
			$a=(Get-Date).ToUniversalTime()
			Write-Host "$a - $srvName BEC is already running with PID: $($becID.id)"
		}
	}
	if ( $headless -gt 0 -and $A3Run){
		#checking if Arma headless clients are running
		for($i=1; $i -le 3; $i++){
			if ( $i -le $headless ){
				isA3HLRunning $i
				if (!$A3HLRun[$i]){
					$a=(Get-Date).ToUniversalTime()
					Write-Host "$a - $srvName headless client ($i) is not running: starting ... " -BackgroundColor "Red" -ForegroundColor "white"
					kill_A3HL $i
					Start-Sleep -s $IntervalMedium
					start_A3HL $i
					$a=(Get-Date).ToUniversalTime()
					Write-Host "$a - Waiting for headless client to init..."
					Start-Sleep -s $IntervalLong
					Start-Sleep -s $IntervalLong
					$a=(Get-Date).ToUniversalTime()
					Write-Host "$a - Done."
				} elseif ( $firstLoop ){
					$a=(Get-Date).ToUniversalTime()
					Write-Host "$a - $srvName headless client ($i) is already running with PID: $($a3hlID[$i].id)"
				}
			}
		}
	}
	
	$loop = $loop + 1;
	if ( $loop -eq 2 ){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - Heartbeat."
		$loop = 0;
	}
	$Script:firstLoop = $false;
	Start-Sleep -s $IntervalLong
	
} While ($true)