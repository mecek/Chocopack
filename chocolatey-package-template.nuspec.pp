<?xml version="1.0"?>
<package >
  <metadata>
    <id>$DefaultNamespace$.install</id>
    <version>1.0.0</version>
    <title>$DefaultNamespace$</title>
    <authors>Global Kapital Group</authors>
    <owners>Global Kapital Group</owners>
    <!--<licenseUrl>http://LICENSE_URL_HERE_OR_DELETE_THIS_LINE</licenseUrl>
    <projectUrl>http://PROJECT_URL_HERE_OR_DELETE_THIS_LINE</projectUrl>-->
    <!--<iconUrl>http://ICON_URL_HERE_OR_DELETE_THIS_LINE</iconUrl>-->
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>to install: choco install $DefaultNamespace$.install -s http://devtfs/api/v2 </description>
    <releaseNotes>$DefaultNamespace$</releaseNotes>
    <copyright>Copyright 2017</copyright>
  </metadata>
  <files>
    <!-- this section controls what actually gets packaged into the Chocolatey package -->
    <file src="..\output\**" target="tools" />
    <!--Building from Linux? You may need this instead: <file src="tools/**" target="tools" />-->
  </files>
</package>