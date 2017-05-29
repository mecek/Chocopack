
. $PSScriptRoot\transformer\xmlReplaceParams.ps1
. $PSScriptRoot\transformer\xmlTransformer.ps1

function Log([string]$message, [switch]$e, [switch]$i){
    $date = get-date -Format 'hh:mm:ss, dd/MM/yyyy'
    $col = "white"
    if($e){ $col = "magenta" }
    if($i){ $col = "green" }
        write-host "[Installer][$date] > $message" -foregroundcolor $col
}

function getEnvironmentConfig([string]$envName){

	[string]$installConfigFile = "$PSScriptRoot\install." + $envName + ".config"
	if(Test-Path $installConfigFile){
		"installation configuration from $installConfigFile" | Write-Host
	}
	elseif(Test-Path "$PSScriptRoot\install.config"){
		$installConfigFile = "$PSScriptRoot\install.config"
		"installation configuration from $installConfigFile" | Write-Host
	}
	else{
		throw "install.config or install."+"$envName"+".config not found in $psscriptroot."
	}

	$iconfig = [xml](Get-Content $installConfigFile)
	if(-Not $iconfig.config.environments.$envName){
		throw "Environment:$envName not found in $installConfigFile. Exiting from migrator."
	}
	return $iconfig.config.environments.$envName
}

function configTransform([string]$environment, [HashTable]$settings, [string]$installDir){
	Log "[configure] running config transformations"
	$appPath = "$installDir\app"
	$xmlFrom = "$appPath\Web.$environment.config"
	$xmlTo = "$appPath\Web.config"
	if((Test-Path $xmlFrom) -and (Test-Path $xmlTo)){
		XmlDocTransform $xmlTo $xmlFrom
	}
	else{
		Log "[configure] No Web.config and Web.$environment.config files found to transform."
	}
	Log "[configure] end of line"
}

function configOverride([string]$environment, [HashTable]$settings, [string]$installDir){
	Log "[configoverride] overriding config file parameters with settings provided."
	$appPath = "$installDir\app"
	@("$appPath\App.config", "$appPath\Web.config") | foreach {
		if(Test-Path $_){
			replaceConnectionStrings $_ $settings
			replaceAppSettings $_ $settings
		}
	}

	$ec = getEnvironmentConfig $environment
	if($ec.windowsservice.topshelf.executable) {
		$executable = $ec.windowsservice.topshelf.executable
		$execonfig = "$appPath\$executable"+".config"
		if(Test-Path $execonfig){
			replaceConnectionStrings $execonfig $settings
			replaceAppSettings $execonfig $settings
		}
	}
}

function applyRetentionPolicy([string]$d){
	Log "running retention policy..." -i
	if(-not (Test-Path "$d")){
		return
	}
	dir $d | sort $_.creationTime |% {
		if((dir $d).length -gt 3){
			"removing $d\$_"
			Remove-Item "$d\$_" -Force -Recurse -ErrorAction SilentlyContinue
		}
	}
}

function runMigrator([string]$environment, [HashTable]$settings, [string]$installDir){
	Log "[migrator] running migrator"
	Log "[migrator] reading configurations..."

	#override appsettings in migrator\app.config
	Log "[migrator] override appsettings in $installDir\migrator\Migrator.exe.config"
	replaceAppSettings "$installDir\migrator\Migrator.exe.config" $settings

	#get dbContextName
	$ec = getEnvironmentConfig $environment
	[string]$dbContextName = "$($ec.migrator.dbContextName)"
	Log "[migrator] dbcontextname: $dbContextName" -i

	#get connection string from app/Web.config
	$wconfig = [xml](Get-Content "$installDir\app\Web.config")
	if(-Not $wconfig.configuration.connectionStrings.add){
		throw "connection string not found in web.config (in $PSScriptRoot\app.$environment\Web.config)"
	}

	$connStr = ($wconfig.configuration.connectionStrings.add | Select-Object -First 1).connectionString 
	[string]$connectionString = "$($connStr)"
	Log "[migrator] connectionString: `"$connectionString`"" -e

	#run migrator.exe
	$command = "$installDir\migrator\Migrator.exe c:$dbContextName --cs `"$connectionString`" "
	Log "[migrator] executing $command"
	cmd.exe /c "$command"
	Log "[migrator] end of line" -i
}

function iisInstall($environment, [string]$installDir){
	$iisAppPoolName = "unknown" + ".pool"
	$iisAppName = "unknown"
	$iisAppPoolDotNetVersion = "v4.0"

	###### get configureation
	$bindings = @()

	$ec = getEnvironmentConfig $environment
	$iisAppName = "$($ec.iis.appName)"
	Log "[iis] installing application $iisAppName" -i

	Log "[iis] application pool name: $($ec.iis.appPoolName)" -i
	$iisAppPoolName = "$($ec.iis.appPoolName)"
	$appPoolIdentityType = "$($ec.iis.appPoolIdentityType)"

	$ec.iis.binding | foreach {
		[string]$protocol_ = "$($_.type)"
		[string]$host_ = "$($_.hostname)"
		[string]$ip_ = "$($_.ip)"
		[string]$port_ = "$($_.port)"
		$binfo = $ip_+":"+$port_+":"+$host_
		Log "[iis] with binding: ($binfo)" -i
		if(!($protocol_ -eq "https")){
			$bindings += @{protocol="$protocol_";bindingInformation="$binfo"}
		}
	}

	Import-Module WebAdministration	


	#REMOVE EXISTING WEBSITE
	cd IIS:\Sites\
	if (Test-Path $iisAppName -pathType container)
	{
		Remove-Item $iisAppName -Force -Recurse -ErrorAction SilentlyContinue
		Log "[iis] $iisAppName website removed." -i
	}

	#REMOVE EXISTING APP POOL
	cd IIS:\AppPools\
	if ((Test-Path $iisAppPoolName -pathType container)){
		Remove-Item $iisAppPoolName -Force -Recurse -ErrorAction SilentlyContinue
		Log "[iis] $iisAppPoolName website removed." -i
	}

	#CREATE APP POOL
	$appPool = New-Item $iisAppPoolName
	$appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $iisAppPoolDotNetVersion
	if($appPoolIdentityType){
        [int]$iType = "$($appPoolIdentityType)"
        Log "[iis][pool][identityType is $iType]"
        $appPool | Set-ItemProperty -Name processModel.identityType -value $iType
    }

    #CREATE WEBSITE
    cd IIS:\Sites\
	$iisApp = New-Item $iisAppName -bindings $bindings -physicalPath "$installDir\app" #create the site
	Log "[iis] $iisAppName website added." -i
	$iisApp | Set-ItemProperty -Name "applicationPool" -Value $iisAppPoolName
	
	$ec.iis.binding | foreach {
		[string]$protocol_ = "$($_.type)"
		[string]$host_ = "$($_.hostname)"
		[string]$ip_ = "$($_.ip)"
		[string]$port_ = "$($_.port)"
		[string]$thumbprint_ = "$($_.thumbprint)"
		$binfo = $ip_+":"+$port_+":"+$host_
		Log "[iis] with binding: ($binfo)" -i
		if(($protocol_ -eq "https")){
			$sslbinding = Get-WebBinding -name "$iisAppName" -Protocol https -Port 443
			if($sslbinding){
				"removing existing ssl binding"
				Remove-WebBinding -name "$iisAppName" -Protocol https -Port 443 -HostHeader "$host_"
			}
			"after deleting web binding"
			Get-WebBinding -name "$iisAppName" -Protocol https -Port 443

			New-WebBinding -name "$iisAppName" -Protocol https -Port 443 -SslFlags 1 -HostHeader "$host_"
			try{
				get-item Cert:\LocalMachine\WebHosting\* | Where-Object Thumbprint -eq "$thumbprint_" | New-Item "IIS:\SslBindings\0.0.0.0!443!$host_" -SSLFlags 1
			}
			catch{
				Log "could not bind certificate to https binding. New-Item IIS:\\SslBindings..." -e
			}
		}
	}

	Log "[iis] application installed." -i
}

function ToHashTable($obj){
	[HashTable]$hash = @{}
	$hash = @{}
	$obj | Get-Member -MemberType Properties | SELECT -exp "Name" | % {
		$hash[$_] = ($obj | SELECT -exp $_)
	}
	return $hash
}

function parseSettings($settingsJson){
	Log "[ParseSettings] settings deserialized to hashtable:"
	$set = ConvertFrom-Json $settingsJson
	[HashTable]$setHash = ToHashTable $set
	$setHash | Out-String | Write-Host

	Log "[ParseSettings] looping in settings hashtable"
	$setHash.GetEnumerator() | ForEach {
		$_.Key +" = "+ $_.Value | write-host
	}
	return $setHash
}

function uninstallWebsite([string]$environment){
	$ec = getEnvironmentConfig $environment
	$iisAppName = "$($ec.iis.appName)"
	Log "[iis][uninstalling]  application: $iisAppName for env:$environment" -i
	Log "[iis][uninstalling] applicationpool name: $($ec.iis.appPoolName)" -i
	$iisAppPoolName = "$($ec.iis.appPoolName)"

	Import-Module WebAdministration	
	cd IIS:\AppPools\
	if (Test-Path $iisAppPoolName -pathType container) #check if the app pool exists
	{
		Remove-Item $iisAppPoolName -Force -Recurse -ErrorAction SilentlyContinue
		Log "[iis][uninstalling] $iisAppPoolName appPool removed." -i
	}
	cd IIS:\Sites\ #navigate to the sites root
	if (Test-Path $iisAppName -pathType container) #check if the site exists
	{
		Remove-Item $iisAppName -Force -Recurse -ErrorAction SilentlyContinue
		Log "[iis][uninstalling] $iisAppName website removed." -i
	}

	#if(Test-Path $installDir){
	#	Log "[iis][uninstalling] removing previously installed directory $installDir"
	#	Remove-Item $installDir -Force -Recurse -ErrorAction Stop
	#}
}


function installTopshelf($environment, [string]$installDir){
	$ec = getEnvironmentConfig $environment
	if(-not $ec.windowsservice) {return }
	if(-not $ec.windowsservice.topshelf) {return }

	$executable = $ec.windowsservice.topshelf.executable

	Log "[windowsservice.topshelf] installing service $executable" -i
	$currentFile = "$($ec.installdirectory)\current.txt"
	Log "[windowsservice.topshelf] uninstalling first" -i
	"** $currentFile"
	if((Test-Path $currentFile)){
		$currentPath = Get-Content "$currentFile" -Encoding UTF8
		"** previous installation is $currentPath"
		. "$currentPath" "stop"
		. "$currentPath" "uninstall"
		Remove-Item $currentFile -Force -ErrorAction SilentlyContinue
	}else{
		. "$installDir\app\$executable" "stop"
		. "$installDir\app\$executable" "uninstall"
	}
	
	"** installing"
	Log "$installDir\app\$executable"
	. "$installDir\app\$executable" "install" "start"
	[System.IO.File]::WriteAllLines($currentFile, "$installDir\app\$executable")
	
	Log "[windowsservice.topshelf] application $executable installed" -i
}