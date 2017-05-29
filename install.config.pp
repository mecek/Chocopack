<?xml version="1.0" encoding="utf-8" ?>
<config>
  <environments>
    <local>
      <installdirectory>D:\apps\$DefaultNamespace$</installdirectory>
      <iis>
        <appName>$DefaultNamespace$</appName>
        <appPoolName>$DefaultNamespace$.pool</appPoolName>
        <appPoolDotNetVersion>v4.0</appPoolDotNetVersion>
        <!-- application pool identity type can be specified. For values: https://msdn.microsoft.com/en-us/library/ms524908(v=vs.90).aspx
        <appPoolIdentityType>0</appPoolIdentityType>
        -->
        <binding>
          <type>http</type>
          <hostname></hostname>
          <ip>*</ip>
          <port>80</port>
        </binding>

        <!-- https binding sample
        <binding>
          <type>https</type>
          <thumbprint>thumprint of the certificate</thumbprint>
          <hostname></hostname>
          <ip>*</ip>
          <port>443</port>
        </binding>
        -->
        
      </iis>
      
      <!--
      <migrator>
        <dbContextName>DbContextClassName</dbContextName>
      </migrator>
      -->
      
      <!--<windowsservice>
        <topshelf>
          <executable>FastAccountService.exe</executable>
        </topshelf>
      </windowsservice>-->
      
    </local>
  </environments>
</config>