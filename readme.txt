

Creating package (on build agent: tfs agent)
	
	1. build.ps1
		- Compiles project
		- Compiles migration project
		- move dlls to output directory

		output directory structure is so:

			/projectDir/output/app/*
			/projectDir/output/migrator/*
			/projectDir/output/chocolateyInstall.ps1
			/projectDir/output/install.config

	2. pack.ps1
		- Creates chocolatey package (a nuget package)

		chocolatey package structure is so:

			/tools/app/*
			/tools/migrator/*
			/tools/chocolateyInstall.ps1
			/tools/install.config

Installing package (on target host: web server)

	1. choco install <projectName> -version <version> -s <http://nugetserver/api/v2> -packageParameters `"env:test`"
	2. chocolatey downloads the package extracts it and runs chocolateyInstall.ps1 in the package.
	3. chocolateyInstall.ps1
		- apply config transformations
		- run migrations
		- install application (creates web site in IIS or creates a service)