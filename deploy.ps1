
param(
	[string]$packageName = "chocolatey-package-name",
	[string]$version = "1.0.0.0",
	[string]$nugetFeed = "http://nugetserver/api/v2/", #nuget server address that stores chocolatey packages. (must be accessible by target hosts over network)
	[string[]]$targetHosts = @("hostname1","hostname2"),
	[string]$user = "user",
	[string]$pass = "pass",
	[HashTable]$settings = @{}
)

function ToHashTable($obj){
	[HashTable]$hash = @{}
	$hash = @{}
	$obj | Get-Member -MemberType Properties | SELECT -exp "Name" | % {
		$hash[$_] = ($obj | SELECT -exp $_)
	}
	return $hash
}

$password = convertto-securestring $pass -asplaintext -force
$mycred = new-object -typename System.Management.Automation.PSCredential -argumentlist $user,$password

#Prepare settings hashtable (combining input parameters and environment variables from pipeline)
get-childitem -path env:* | foreach {
	[string]$key = "$($_.Key)"
	if($key.StartsWith("APP_","CurrentCultureIgnoreCase")){
		Write-Output " --->>> $($key): $($_.Value)"
		$settings[$key.Replace("APP_","")] = $_.Value
	}
	if(-not $settings["env"] -and $key -eq "RELEASE_ENVIRONMENTNAME"){
		$settings["env"] = $_.Value
	}
}


Write-Host "---> settings:"
$settings | Out-String | Write-Host

#Prepare settings [END]

Write-Host "---> settings json:"
$settingsJson = ""
ConvertTo-Json $settings -Compress -OutVariable settingsJson
Write-Host $settingsJson

Write-Host "---> settings deserialized to hashtable:"
$set = ConvertFrom-Json "$settingsJson"
[HashTable]$setHash = ToHashTable $set
$setHash | Out-String | Write-Host

Write-Host "---> looping in settings hashtable"
$setHash.GetEnumerator() | ForEach {
	$_.Key +" = "+ $_.Value | write-host
}

$Bytes = [System.Text.Encoding]::Unicode.GetBytes("$($settingsJson)")
$settingsEncoded =[Convert]::ToBase64String($Bytes)
Write-Host "Encoded:"+$settingsEncoded


$deployBlock = {
	param([string]$targetHost, [pscredential]$hostCredentials, [string]$packageName, [string]$version, [string]$nugetFeed, [string]$settingsEncoded)

	"__________________ Deploying to: $targetHost __________________" | Write-Host
	Invoke-Command –ComputerName $targetHost –ScriptBlock { 
		param($packageName,$version,$nugetFeed,$settingsEncoded) 
		#check if choco is installed
		Write-Host "checking if chocolatey is installed"
		$oldPreference = $ErrorActionPreference
		$ErrorActionPreference = 'stop'
		try {
    		if(Get-Command "choco"){ "chocolatey is installed." }
		}
		catch {
    		iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
		}
		finally {
    		$ErrorActionPreference=$oldPreference
		}
		#run choco install
		Write-Host "---> running choco install $packageName -s $nugetFeed --version $version -y --failonstderr"

		choco install $packageName -s $nugetFeed --version $version -params `"$settingsEncoded`" -y --force --failonstderr
		Write-Host "---> end of installation."
		Write-Host "---> running choco list"
		clist $packageName  -localonly
		Write-Host "---> end of line"
	} -ArgumentList $packageName, $version, $nugetFeed, $settingsEncoded -Credential $hostCredentials

	"__________________ End of Deploy $targetHost __________________" | Write-Host
}


#remote invocation in parallel begins
"Deployment targets: " + [string]::Join(", ",$targetHosts) | Write-Host
"Starting remote invocation in parallel..." | Write-Host

$jobs = @()
$targetHosts | foreach {
	$deployTarget = $_
	$jobs += Start-Job -ScriptBlock $deployBlock -ArgumentList $deployTarget, $mycred, $packageName, $version, $nugetFeed, $settingsEncoded
}
Wait-Job -Job $jobs | Out-Null
Receive-Job -Job $jobs
#remote invocation in parallel ends

"End of remote invocation in parallel..." | Write-Host