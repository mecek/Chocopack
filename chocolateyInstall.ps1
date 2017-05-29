#
# chocolateyInstall.ps1
#

. $PSScriptRoot\library-commons.ps1
. $PSScriptRoot\custom-scripts.ps1

#START WORKING ...
$targetEnv = "dev"
$outputDir = "$PSScriptRoot"
Log "beginning chocolatey install"
$pars = $env:chocolateyPackageParameters
Log "chocolateyPackageParameters: $pars"
#decode settings
$settingsJson = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($pars))
Log "Decoded as follows:"
Log $settingsJson
#decode settings
[HashTable]$settings = @{}

if($settingsJson){
    Log "parsing target environment" -i
	$settings = parseSettings $settingsJson
    $parsedEnv = $settings["env"]
    if($parsedEnv){
        $targetEnv = $parsedEnv
    }else{
		$targetEnv = "local"
        Log "can not parse target environment. [env:chocolateyPackageParameters is $pars]" -e
    }
}else{
	$targetEnv = "local"
	$outputDir = "$psscriptroot\..\output"
}

Log "target environment is $targetEnv" -i
$ec = getEnvironmentConfig $targetEnv
[string]$installDir = "C:\apps\$([guid]::NewGuid())"
if($ec.installdirectory){
	$installDir = "$($ec.installdirectory)"
}

$packageversion = "$($env:ChocolateyPackageVersion)"
if(-not $packageversion){
	$packageversion = "$([guid]::NewGuid())"
}

$installDir = "$installDir\$targetEnv\$packageversion"
Log "install directory is: $installDir"
applyRetentionPolicy "$installDir\.."

if(-not (Test-Path $installDir)){
	New-Item $installDir -ItemType Directory -ErrorAction Stop
}

Log "copying artifacts to install directory." -i
"from: $outputDir"
"to  : $installDir"
Copy-Item "$outputDir\*" $installDir -Recurse -Force -ErrorAction Stop

configTransform $targetEnv $settings $installDir
configOverride $targetEnv $settings $installDir
beforeInstall $targetEnv $settings $installDir

if($ec.migrator){ 
	runMigrator $targetEnv $settings $installDir 
} 
else {	
	Log "no migration configuration found." -i 
}

if($ec.iis){ 
	uninstallWebsite $targetEnv
	iisInstall $targetEnv $installDir 
}

installTopshelf $targetEnv $installDir

cd "$PSScriptRoot"
Log "end of line" -i