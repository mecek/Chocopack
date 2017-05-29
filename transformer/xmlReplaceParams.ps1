
#param(
#	[HashTable]$settings = @{"CommunicationSqlContext"="Data Source=.\MyDatasource;Initial Catalog=testcatalog;Integrated Security=True";"SmtpHost"="myhost"}
#)

function replaceConnectionStrings([string]$configFile, [HashTable]$settings)
{
	"tring to override connection strings in: $configFile" | Write-Host
	$doc = (Get-Content $configFile) -as [Xml]
	$root = $doc.get_DocumentElement();
    if($root.connectionStrings){
        $root.connectionStrings.SelectNodes("add") | Foreach {
		        $cs = $_
		        $settings.GetEnumerator() | where {$_.Name -eq $cs.GetAttribute("name")} | foreach {
			        "replacing " + $cs.GetAttribute("name") | Write-Host
			        $cs.SetAttribute("connectionString", $_.Value)
		        }
	        }
    }else{
      "no connection string in config file."
      return
    }

	$doc.Save($configFile)
}

function replaceAppSettings([string]$configFile, [HashTable]$settings)
{
	"tring to override app settings in: $configFile" | Write-Host

	$doc = (Get-Content $configFile) -as [Xml]
	$root = $doc.get_DocumentElement();
	if($root.appSettings){
		"selecting nodes <add>"
		$root.appSettings.SelectNodes("add") | Foreach {
			"replacing an item as follows."
			$item = $_
			$settings.GetEnumerator() | where {$_.Name -eq $item.GetAttribute("key")} | foreach {
				"replacing " + $item.GetAttribute("key") | Write-Host
				$item.SetAttribute("value", $_.Value)
			}
		}

		$doc.Save($configFile)
	}else{
		"no appSettings in $configFile"
	}
} 

#replaceConnectionStrings "$psscriptroot\xmls\Web.config" $settings
#replaceAppSettings "$psscriptroot\xmls\Web.config" $settings