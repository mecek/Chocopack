#
# xmlTransformer.ps1
#
#param($a,$b)

function XmlDocTransform($xml, $xdt)
{
	$dllPath = "$psscriptroot\Microsoft.Web.XmlTransform.dll"

	Write-Host "[XmlDocTransform] > xml transforming"
	Write-Host "[XmlDocTransform] > from : $xdt"
	Write-Host "[XmlDocTransform] > to   : $xml"
	Write-Host "[XmlDocTransform] > using: $dllPath"

    if (!$xml -or !(Test-Path -path $xml -PathType Leaf)) {
        throw "Xml File not found. $xml";
    }
    if (!$xdt -or !(Test-Path -path $xdt -PathType Leaf)) {
        throw "Xdt File not found. $xdt";
    }

    Add-Type -LiteralPath $dllPath

    $xmldoc = New-Object Microsoft.Web.XmlTransform.XmlTransformableDocument;
    $xmldoc.PreserveWhitespace = $true
    $xmldoc.Load($xml);

    $transf = New-Object Microsoft.Web.XmlTransform.XmlTransformation($xdt);
    if ($transf.Apply($xmldoc) -eq $false)
    {
        throw "Transformation failed."
    }
    $xmldoc.Save($xml);
	Write-Host "[XmlDocTransform] > $xml saved."
}

#XmlDocTransform $a $b