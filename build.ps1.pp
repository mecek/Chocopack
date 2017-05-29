
param(
[string]$msbuildPath = "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe",
[string]$projFile = "$filename$",
[string]$version = "1.0.0.0",
[string]$projFileLocation = "$psscriptroot\..",
[string]$migrator = "Migrator.csproj",
[string]$migratorProjLocation = "$projFileLocation\..\..\Tools\Migrator",
[string]$configuration = "Debug"
)

if(-Not [System.IO.File]::Exists($msbuildPath)){
	throw "MSBUILD not found here: $msbuildPath"
}

function compile($projFileName){
	"compiling $projFileName"
	$buildProject = """$msbuildPath"" $projFileName /p:Configuration=$configuration /p:AutoParameterizationWebConfigConnectionStrings=false /p:TransformWebConfigEnabled=false /p:VisualStudioVersion=14.0 /verbosity:minimal /nologo /p:RunCodeAnalysis=false /t:Rebuild /tv:14.0 /p:DeployOnBuild=true"
	"running:" + $buildProject
	iex "cmd.exe /c $buildProject"
}

"Cleaning output directory..."
if(Test-Path $projFileLocation\output){
	Remove-Item $projFileLocation\output -Force -Recurse
}
if(Test-Path '$projFileLocation\obj\$configuration'){
	Remove-Item '$projFileLocation\obj\$configuration' -Force -Recurse
}

cd $projFileLocation
compile $projFile
Copy-Item $projFileLocation\obj\$configuration\Package\PackageTmp .\output\app -Recurse -Force
"created project artifacts in $projFileLocation\output\app"

cd $migratorProjLocation
compile $migrator
Copy-Item "$migratorProjLocation\bin\$configuration" $projFileLocation\output\migrator -Recurse -Force
"created migration artifacts in $projFileLocation\output\migrator"

Copy-Item $projFileLocation\Chocopack\chocolateyInstall.ps1 $projFileLocation\output\chocolateyInstall.ps1 -Recurse -Force
Copy-Item $projFileLocation\Chocopack\library-commons.ps1 $projFileLocation\output\library-commons.ps1 -Recurse -Force
Copy-Item $projFileLocation\Chocopack\custom-scripts.ps1 $projFileLocation\output\custom-scripts.ps1 -Recurse -Force
Copy-Item $projFileLocation\Chocopack\install.config $projFileLocation\output\install.config -Recurse -Force
Copy-Item $projFileLocation\Chocopack\install.*.config $projFileLocation\output\ -Recurse -Force
Copy-Item $projFileLocation\Chocopack\transformer $projFileLocation\output\transformer -Recurse -Force
"$projFile version: $version" > $projFileLocation\output\app\version.txt

cd $projFileLocation
"end of line"