
function execSafe([string]$command){
	$outpt = iex "$command" 2>&1
	$outpt = $outpt -replace "ERROR", "E-R-R-O-R"
	$outpt
}

function beforeInstall([string]$environment, [HashTable]$settings, [string]$installDir){
	#executed before install

}