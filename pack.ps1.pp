
param(
	[string]$version = "1.0.0"
)

[string]$projFileLocation = "$psscriptroot\.."

cd $projFileLocation
nuget pack ".\Chocopack\chocolatey-package-template.nuspec" -version $version