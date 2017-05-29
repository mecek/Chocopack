#runs after nuget install on build machine

param($installPath, $toolsPath, $package, $project)

write-host "running after nuget install.."
write-host "script folder is : $PSScriptRoot"
write-host "installPath is: $installPath"
write-host "toolsPath is: $toolsPath"

# set build action for added files as <None> in destination project.

function SetBuildActionToNone($parent, [string]$folderName, $prefix){
	$self = $parent.ProjectItems | where { $_.Name -eq $folderName } | Select-Object -First 1
	$self.ProjectItems | foreach { 

		if($_.ProjectItems.Count -gt 0){
			SetBuildActionToNone $self "$($_.Name)" "$prefix/$($self.Name)"
		}
		else{
			Write-Host " >>> changing build action of $prefix/$($self.Name)/$($_.Name)"
			$_.Properties.Item("BuildAction").Value = [int]0 
		}
	}
}

SetBuildActionToNone $project "Chocopack" $project.Name