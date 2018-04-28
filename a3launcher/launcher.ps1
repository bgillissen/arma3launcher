# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# File:			launcher.ps1
# Version:		V0.2
# Author:		Ben 2016
# Contributers:	None
#
# Arma3 Server (re)starter for TFU
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
param (
    [string]$config = 'directAction.cfg',
    [string]$world = '',
    [string]$modset = '',
    [string]$mission = '',
    [string]$param = '',
	[string]$profile = ''
)

Write-Host ""
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host "			 TaskForceUnicorn Arma3 Launcher by Ben"
Write-Host -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Write-Host ""
Write-Host "Initializing..."

Function initFailed($msg){
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - $($msg), exiting..."  -BackgroundColor "Red" -ForegroundColor "white"
	Read-Host 'Press enter to exit'
	exit
}

$splitOption = [System.StringSplitOptions]::RemoveEmptyEntries
$srvWait = 30
$hlWait = 60
$loopWait = 5
$killWait = 10
$crashWait = 5
$crashTry = 5
$A3Run = $false
$BECRun = $false

# Parsing main config-file
Get-Content "common.cfg" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,' = '); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
$pidPath = $h.Get_Item("pid")
$a3Path = $h.Get_Item("path")
$profilePath = $h.Get_Item("profile")
$modPath = $h.Get_Item("mods")
$becPath = $h.Get_Item("bec")
$becExe = "$becPath\Bec.exe"

# Parsing given config-file
Get-Content $config | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,' = '); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
$sixtyfourbits = ( $h.Get_Item("x64") -eq "true")
$startServer = ( $h.Get_Item("startServer") -eq "true" )
$battleye = $h.Get_Item("battleye")
$pidFilename = $h.Get_Item("pid")
$pidFile = "$pidPath\$pidFilename"
$port = $h.Get_Item("port")
$cfg = $h.Get_Item("cfg")
$tpl = $h.Get_Item("tpl")
$cpKeys = ($h.Get_Item("cpkeys") -eq "true")
$srvCMD = $h.Get_Item("srvCMD")
$srvName = $h.Get_Item("srvName")
$dftProfileName = $h.Get_Item("profile")
$dftModset = $h.Get_Item("modset")
$dftParams = $h.Get_Item("params")
$dftMission = $h.Get_Item("mission")
$dftWorld = $h.Get_Item("world")
$srvPass = $h.Get_Item("srvPass")
$admPass = $h.Get_Item("admPass")
$cmdPass = $h.Get_Item("cmdPass")
$maxPlayers = $h.Get_Item("maxPlayers")
$hlCount = $h.Get_Item("hlcount")
$hlConnect = $h.Get_Item("hlconnect")
$hlCMD = $h.Get_Item("hlCMD")
$hlProfiles =  $h.Get_Item("hlProfiles").Split(";", $splitOption)
$hlMemMax = [scriptblock]::Create($h.Get_Item("hlMemMax")).Invoke()
$usebec = ($h.Get_Item("usebec") -eq "true")
$beconfig = $h.Get_Item("beconfig")
$becPid = "$pidPath\BEC_$pidFilename"

$extraKeys = "$profilePath\Users\$profileName\extrakeys"
$globalKeys = "$profilePath\globalkeys"
#determining active profileName
if ( $profile -eq '' ){
	$profileName = $dftProfileName
} else {
	$profileName = $profile
}

# Parsing modset if defined, otherwise use config default
if ( $modset -eq "" ){ $modset = $dftModset }
if ( $modset -ne "" ){ 
    if ( !(Test-Path "modsets/$modset") ){ initFailed("Modset file was not found @ modsets/$modset, abording") }
    Get-Content "modsets/$modset" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,' = '); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }
    $setName = $h.Get_Item("setName")
    $cltMods = $h.Get_Item("cltMods").Split(";", $splitOption)
    $srvMods = $h.Get_Item("srvMods").Split(";", $splitOption)
    $hlMods = $h.Get_Item("hlMods").Split(";", $splitOption)
} else {
    $setName = ''
    $cltMods = @()
    $srvMods = @()
    $hlMods = @()
}
if ( $setName -eq "" ){ 
   	$fullName = $srvName -replace "%setName%", ""
} else {
   	$fullName = $srvName -replace "%setName%", "| $setName"
}

#use default world if none defined
if ( $world -eq "" ){ $world = $dftWorld }
#use default mission if none defined
if ( $mission -eq "" ){ $mission = $dftMission }
#use default mission parameters if none defined
if ( $param -eq "" ){ $param = $dftParams }

if ( $sixtyfourbits ){
	$a3Proc = "arma3server_x64"
} else {
	$a3Proc = "arma3server"
}
$a3Exe = "$a3Path\$($a3Proc).exe"

if ( $hlCount -gt 0 ){
	$A3HLRun = @($null)
	$a3hlID = @($null)
	$hlPid = @($null)
	$A3HLMem = @($null)
	for($i=1; $i -le $hlCount; $i++){
		$A3HLRun += $false	
		$a3hlID += $null
		$hlPid += "$pidPath\hl$($i)_$pidFilename"
		$A3HLMem += 0
	}
}

$host.ui.RawUI.WindowTitle = "TFU Launcher: $fullName"

#Prerun checks, checking arma env
if ( !(Test-Path $a3Path -PathType container) ){
	initFailed "Invalid value in common.cfg, path setting : $a3Path is not a folder!"
} elseif ( !(Test-Path $a3Exe) ){
	initFailed "Invalid value in common.cfg, path setting: $a3Exe was not found!"
} elseif ( !(Test-Path "$a3Path\$cfg") ){
	initFailed "Invalid value in $config, cfg setting: $a3Path\$cfg was not found!"
} elseif ( !(Test-Path $pidPath -PathType container) ){
	initFailed "Invalid value in common.cfg, pid setting: $pidPath is not a folder!"
} elseif ( !(Test-Path $profilePath -PathType container) ){
	initFailed "Invalid value in common.cfg, profile setting: $profilePath is not a folder!"
} elseif ( !(Test-Path $tpl) ){
	initFailed "Invalid value in $config, tpl setting: $tpl was not found!"
}

#checking mods path
if ( $startServer ){
	foreach($mod in $srvMods){ 
		if ( !(Test-Path "$modPath\$mod" -PathType container) ){ initFailed "Mod '$mod' was not found @ $modPath\$mod" }
	}
}
if ( $hlCount -gt 0 ){
	foreach($mod in $hlMods){ 
		if ( !(Test-Path "$modPath\$mod" -PathType container) ){ initFailed "Mod '$mod' was not found @ $modPath\$mod" }
	}
}
foreach($mod in $cltMods){ 
    if ( !(Test-Path "$modPath\$mod" -PathType container) ){ initFailed "Mod '$mod' was not found @ $modPath\$mod" }
}

#checking mission
if ( $startServer ){
	if ( $mission -eq "" ){ initFailed "Mission was not defined" }
	if ( ($world -eq "") -and ($mission -like "*%world%") ){ initFailed "World was not defined, and is needed by mission setting '$mission'" }
	$missionParam = $mission -replace "%world%", "$world"
	$missionFile = "$a3Path\mpmissions\$missionParam.pbo"
	if ( !(Test-Path $missionFile) ){ initFailed "Mission file was not found @ $missionFile" }
	#checking paramFile
	if ( $param -ne "" ){ 
		if ( !(Test-Path "misParams\$param") ){ initFailed "Mission parameters file was not found @ misParams\$param" } 
	}
	if ( $usebec -eq "true" ){
		if ( !(Test-Path $becPath -PathType container) ){
			initFailed "Invalid value in common.cfg, bec setting : $becPath is not a folder!"
		} elseif ( !(Test-Path $a3Exe) ){
			initFailed "Invalid value in common.cfg, bec setting: $becExe was not found!"
		}
	}
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
    $a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Removing keys"
	$keyFiles = get-childitem -LiteralPath "$a3Path\keys" -recurse | Where-Object { $_.Name -match ".bikey$" -and $_.Name -notLike "a3.bikey" }
	if ( ($keyFiles | Measure-Object).count -gt 0 ){
		foreach($keyFile in $keyFiles){
			$fname = $keyFile.fullName
			remove-item -LiteralPath $keyFile.fullName
		}
	}
	$keyCount = 0
}
Function importKeys($mods=$null){
	if ( !($mods) ){
		if (test-path $globalKeys -PathType container){ copyKeys $globalKeys }
		if (test-path $extraKeys -PathType container){ copyKeys $extraKeys }
	} else {
		foreach($mod in $mods){ copyKeys "$modPath\$mod" }
	}
}
Function copyKeys($from){
	if ( !(test-path "$from" -PathType container) ){
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $from folder was not found, no keys were imported!"  -BackgroundColor "Red" -ForegroundColor "white"
		return
	}
	$keyFiles = get-childitem -LiteralPath $from -recurse | Where-Object { $_.Name -match ".bikey$" }
	$count = ($keyFiles | Measure-Object).count
	if (  $count -gt 0 ){
		foreach($keyFile in $keyFiles){
			$fname = $keyFile.Name
			$dest = "$a3Path\keys\$fname"
			Copy-Item -literalPath $keyFile.fullName -Destination $dest 
		}
	}
	$script:keyCount += $count
}

Function genConfig {
    $a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Generating server config file using $tpl as template"
    $template = Get-Content $tpl
    $template = $template -replace "%srvName%", $fullName  
    $template = $template -replace "%srvPass%", $srvPass
    $template = $template -replace "%admPass%", $admPass
    $template = $template -replace "%cmdPass%", $cmdPass
    $template = $template -replace "%logFile%", "$profileName.log"
    $template = $template -replace "%maxPlayers%", $maxPlayers
    $template = $template -replace "%battleye%", $battleye
    if ( $cpKeys ){ 
        $template = $template -replace "%modKey%", "1"
    } else {
        $template = $template -replace "%modKey%", "0"
    }
    $template = $template -replace "%mission%", $missionParam
    if ( $param -ne "" ){
        $misParams = Get-Content "misParams\$param"
        $template = $template -replace "%misParams%", $misParams
    } else {
       $template = $template -replace "%misParams%", ""
    }
    $template > "$a3Path\launcher.cfg"
}

Function start_A3 {
	removeKeys
	if ( $cpKeys ){
        $script:keyCount = 0
		importKeys $null
        if ( $cltMods.Count -gt 0 ){ importKeys $cltMods }
		if ( $srvMods.Count -gt 0 ){ importKeys $srvMods }
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $script:keyCount keys imported"
	}
    genConfig
	$cltStr = ""
	foreach($mod in $cltMods){ $cltStr += "$modPath\$mod;" }
	$srvStr = ""
	foreach($mod in $srvMods){ $srvStr += "$modPath\$mod;" }
    	
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Starting $fullName, exe: $a3Proc, port: $port"
	
    $script:a3ID = Start-Process "$($a3Proc).exe" "$srvCMD -port=$port -profiles=$profilePath -name=$profileName -config=launcher.cfg -cfg=$cfg -mod=$cltStr -servermod=$srvStr" -WorkingDirectory $a3Path -passthru

	$a=(Get-Date).ToUniversalTime()
	if ( !$script:a3ID ){
		Write-Host "$a - $fullName failed to start"  -BackgroundColor "Red" -ForegroundColor "white"
		$script:a3Run = $false;
	} else {
		Write-Host "$a - $fullName started with PID: $($a3ID.Id)"
		Set-Content $pidFile "$($a3ID.Id)"
		$script:a3ID.priorityclass = "High"
		$script:a3Run = $true;
	}
}
function kill_A3 {
	isA3Running
	if ($A3Run) {
		pid = $($a3ID.Id)
		Stop-Process -Force -Id $pid
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a  -  $fullName with PID: $pid has been killed"
		Set-Content $pidFile ""
	}
}
function isA3Running {
	$script:a3Run = $false
	if ( !$a3ID ){
		if ( Test-Path $pidfile ){ $storedPID = Get-Content $pidFile }
		if ( $storedPID ){
			$script:a3ID = isRunning $a3Proc $storedPID
			if ( $a3ID ){ $script:a3Run = $true }
		}
	} else {
		$script:a3ID = isRunning $a3Proc $a3ID.Id
		if ( $a3ID ){ $script:a3Run = $true }
	}
}


# BEC management functions
Function start_BEC {
	$a=(Get-Date).ToUniversalTime()
	$b = "$a - Starting: BEC for $srvName with: $beconfig"
	Write-Host "$b"
	
	$script:becID = Start-Process $becExe "-f $beconfig --dsc" -WorkingDirectory $becPath -passthru
	
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
		Stop-Process -Force -Id $pid
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $fullName BEC with PID: $pid has been killed"
		Set-Content $pidFile ""
	}
}
function isBECRunning {
	$script:becRun = $false
	if ( !$becID ){
		if ( Test-Path $becPid ){ $storedPID = Get-Content $becPid }
		if ( $storedPID ){
			$script:becID = isRunning "Bec" $StoredPID
			if ( $becID ){ $script:becRun = $true }
		}
	} else {
		$script:becID = isRunning "Bec" $becID.Id
		if ( $becID ){ $script:becRun = $true }
	}
}



#Arma 3 headless clients management functions
function start_A3HL($key){
	$pass = ""
	if ( $srvPass -ne "" ){
		$pass = "-password=$srvPass"
	}	
	$cltStr = ""
	foreach($mod in $cltMods){ $cltStr += "$modPath\$mod;" }
	foreach($mod in $hlMods){ $cltStr += "$modPath\$mod;" }
	$profileK = $key - 1; 
	
	$a=(Get-Date).ToUniversalTime()
	Write-Host "$a - Starting: headless client $($hlProfiles[$profileK])"
	
	$script:a3hlID[$key] = Start-Process "$($a3Proc).exe" "-client $hlCMD -profiles=$profilePath  -name=$($hlProfiles[$profileK]) -mod=$cltStr -connect=$hlconnect -port=$port $pass" -WorkingDirectory $a3Path -passthru
	
	$a=(Get-Date).ToUniversalTime()
	if ( !$a3hlID[$key] ){
		Write-Host "$a - $fullName headless client ($key) failed to start"  -BackgroundColor "Red" -ForegroundColor "white"
	} else {
		Write-Host "$a - $fullName headless client ($key) started with PID: $($a3hlID[$key].Id)"
		Set-Content $hlPid[$key] "$($a3hlID[$key].Id)"
		$script:a3hlID[$key].priorityclass = "High"
	}
}
function kill_A3HL($key){
	isA3HLRunning $key
	if ($A3HLRun[$key]) {
		Stop-Process -Force -Id $($a3hlID[$key].Id)
		$a=(Get-Date).ToUniversalTime()
		Write-Host "$a - $fullName headless client ($key) with PID: $($a3hlID[$key].Id) has been killed"
		Set-Content $hlPid[$key] ""
	}
}
function isA3HLRunning($key){
	$script:A3HLRun[$key] = $false;
	if ( !$a3hlID[$key] ){
		if ( Test-Path $hlPid[$key] ){ $storedPID = Get-Content $hlPid[$key] }
		if ( $storedPID ){
			$script:a3hlID[$key] = isRunning $a3Proc $storedPID
			if ( $a3hlID[$key] ){ $script:A3HLRun[$key] = $true; }
		}
	} else {
		$script:a3hlID[$key] = isRunning $a3Proc $a3hlID[$key].Id
		if ( $a3hlID[$key] ){ $script:A3HLRun[$key] = $true; }
	}
}
function getMemory_A3HL($key){
	if ( !$a3hlID[$key] ){
		Write-Host "from PIDFile"
		if ( Test-Path $hlPid[$key] ){ $storedPID = Get-Content $hlPid[$key] }
		if ( $storedPID ){
			$procObj = Get-Process $a3Proc -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $storedPID}
		}		
	} else {
		Write-Host "from PIDVar"
		$procObj = Get-Process $a3Proc -ErrorAction SilentlyContinue | Where-Object {$_.Id -eq $a3hlID[$key].Id}
	}
	if ( !$procObj ){ 
		$script:A3HLMem[$key] = -1
		return 
	}
	$script:A3HLMem[$key] = $procObj.WorkingSet64
}

if ( !$startServer ){ 
	Write-Host "Server will not be launched" 
} else {
	if ( $usebec -eq "true" ){
		Write-Host "BEC is enabled."
	} else {
		Write-Host "BEC is disabled."
	}
}
Write-Host "$hlCount headless client(s) will be launched."
Write-Host "Entering the loop..."
Write-Host "Max HC Memory:  $hlMemMax"
# Main loop
$firstLoop = $true;
Do {
	# check if Arma server is running, if we need to start it
	if ( $startServer ){ 
        IsA3Running
	    if ( !$A3Run ){
		    $a=(Get-Date).ToUniversalTime()
		    Write-Host "$a - $fullName is not running, starting..." -BackgroundColor "Red" -ForegroundColor "white"
		    if ( $usebec -eq "true" ){
			    kill_BEC
			    Start-Sleep -s $killWait
		    }
		    if ( $hlCount -gt 0 ){
			    for($i=1; $i -le $hlCount; $i++){
                    isA3HLRunning $i
                    if ( $A3HLRun[$i] ){
				        kill_A3HL $i 
				        Start-Sleep -s $killWait
                    }
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
		    Write-Host "$a - $fullName is already running with PID: $($a3ID.id)"
	    }
	    if ( $usebec ){
		    # checking if BEC is running
		    IsBECRunning
		    if ($A3Run -and !$BECRun){
			    $a=(Get-Date).ToUniversalTime()
			    Write-Host "$a - $fullName BEC is not running, starting..." -BackgroundColor "Red" -ForegroundColor "white"
			    kill_BEC
			    Start-Sleep -s $killWait
			    start_BEC
		    } elseif ( $firstLoop ){
			    $a=(Get-Date).ToUniversalTime()
			    Write-Host "$a - $fullName BEC is already running with PID: $($becID.id)"
		    }
	    }
    }
	if ( ($hlCount -gt 0) -and ($A3Run -or !$startServer) ){
		#checking if Arma headless clients are running
		for($i=1; $i -le $hlCount; $i++){
			isA3HLRunning $i
			if (!$A3HLRun[$i]){
				$a=(Get-Date).ToUniversalTime()
				Write-Host "$a - $fullName headless client ($i) is not running, starting..." -BackgroundColor "Red" -ForegroundColor "white"
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
				Write-Host "$a - $fullName headless client ($i) is already running with PID: $($a3hlID[$i].id)"
			} else {
				getMemory_A3HL $i
				Write-Host "Current : $($A3HLMem[$i]), Max :  $hlMemMax"
				if ($A3HLMem[$i] -gt "$hlMemMax"){ #if the memory is above the allowed amount
				    $a=(Get-Date).ToUniversalTime()
				    Write-Host "$a - $fullName headless client ($i) is above allowed memory usage, killing it..." -BackgroundColor "Red" -ForegroundColor "white"
				    kill_A3HL $i
				    Start-Sleep -s $killWait
				    $a=(Get-Date).ToUniversalTime()
				    Write-Host "$a - Done."
				}
			}
		}
	}
	$firstLoop = $false;
	Start-Sleep -s $loopWait
	
} While ($true)