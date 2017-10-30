<#
.SYNOPSIS
	Private functions for running FudgePop
.NOTES
	1.0.0 - 10/30/2017 - David Stein
#>

$FPRegPath  = "HKLM:\SOFTWARE\FudgePop"
$FPLogFile  = "$($env:TEMP)\fudgepop.log"

<#
.SYNOPSIS
	Yet another custom log writing function, like all the others
.PARAMETER Category
	[string] [required] One of 'Info', 'Warning', or 'Error'
.PARAMETER Message
	[string] [required] Message text to enter into log file
#>

function Write-FudgePopLog {
	param (
		[parameter(Mandatory=$True)]
			[ValidateSet('Info','Warning','Error')]
			[string] $Category,
		[parameter(Mandatory=$True)]
			[ValidateNotNullOrEmpty()]
			[string] $Message
	)
	Write-Verbose "$(Get-Date -f 'yyyy-M-dd HH:mm:ss')  $Category  $Message"
	"$(Get-Date -f 'yyyy-M-dd HH:mm:ss')  $Category  $Message" | 
		Out-File -FilePath $FPLogFile -Append -NoClobber -Encoding Default
}

<#
.SYNOPSIS
	Makes sure Chocolatey is installed and kept up to date
#>

function Assert-Chocolatey {
	param ()
	Write-FudgePopLog -Category "Info" -Message "verifying chocolatey installation"
	if (-not(Test-Path "$($env:ProgramData)\chocolatey\choco.exe" )) {
		try {
			Write-FudgePopLog -Category "Info" -Message "installing chocolatey"
			iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
		}
		catch {
			Write-FudgePopLog -Category "Error" -Message $_.Exception.Message
			break
		}
	}
	else {
		Write-FudgePopLog -Category "Info" -Message "checking for newer version of chocolatey"
		choco upgrade chocolatey -y
	}
}

<#
.SYNOPSIS
	Imports the XML data from the XML control file
.PARAMETER FilePath
	Path or URI to the control XML file
#>

function Get-FPControlData {
	param (
		[parameter(Mandatory=$True, HelpMessage="Path or URI to XML control file")]
		[ValidateNotNullOrEmpty()]
		[string] $FilePath
	)
	Write-FudgePopLog -Category "Info" -Message "preparing to import control file: $FilePath"
	if ($FilePath.StartsWith("http")) {
		try {
			[xml]$result = Invoke-RestMethod -Uri $FilePath -UseBasicParsing
		}
		catch {
			Write-FudgePopLog -Category "Error" -Message "failed to import data from Uri: $FilePath"
			Write-Output -3
			break;
		}
	}
	else {
		if (Test-Path $FilePath) {
			try {
				[xml]$result = Get-Content -Path $FilePath
			}
			catch {
				Write-FudgePopLog -Category "Error" -Message "unable to import control file: $FilePath"
				Write-Output -4
				break;
			}
		}
		else {
			Write-FudgePopLog -Category "Error" -Message "unable to locate control file: $FilePath"
			Write-Output -5
			break;
		}
	}
	Write-Output $result
}

<#
.SYNOPSIS
	Execute CHOCOLATEY INSTALLATION AND UPGRADE directives from XML control file
.PARAMETER DataSet
	XML data set fed from the XML control file
#>

function Invoke-FPChocoInstalls {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$True)]
		$DataSet
	)
	Write-FudgePopLog -Category "Info" -Message "--------- installaation assignments ---------"
	if ($DataSet) {
		$deviceName = $DataSet.device
		$runtime    = $DataSet.when
		$autoupdate = $DataSet.autoupdate
		$username   = $DataSet.user
		$extparams  = $DataSet.params
		Write-FudgePopLog -Category "Info" -Message "assigned to device: $deviceName"
		Write-FudgePopLog -Category "Info" -Message "assigned runtime: $runtime"
		if ($runtime -eq 'now' -or (Get-Date).ToLocalTime() -ge $runtime) {
			Write-FudgePopLog -Category "Info" -Message "run: runtime is now or already passed"
			$pkglist = $DataSet.InnerText -split ','
			foreach ($pkg in $pkglist) {
				if ($extparams.length -gt 0) {
					Write-FudgePopLog -Category "Info" -Message "package: $pkg (params: $extparams)"
					if (-not $TestMode) {
						choco upgrade $pkg $extparams
					}
					else {
						Write-FudgePopLog -Category "Info" -Message "TEST MODE : choco upgrade $pkg $extparams"
					}
				}
				else {
					Write-FudgePopLog -Category "Info" -Message "package: $pkg"
					if (-not $TestMode) {
						choco upgrade $pkg -y
					}
					else {
						Write-FudgePopLog -Category "Info" -Message "TEST MODE: choco upgrade $pkg -y"
					}
				}
			} # foreach
		}
		else {
			Write-FudgePopLog -Category "Info" -Message "skip: not yet time to run this assignment"
		}
	}
	else {
		Write-FudgePopLog -Category "Info" -Message "NO installations have been assigned to this computer"
	}
}

<#
.SYNOPSIS
	Execute CHOCOLATEY REMOVALS directives from XML control file
.PARAMETER DataSet
	XML data set fed from the XML control file
#>

function Invoke-FPChocoRemovals {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$True)]
		$DataSet
	)
	Write-FudgePopLog -Category "Info" -Message "--------- removal assignments ---------"
	if ($DataSet) {
		$deviceName = $DataSet.device
		$runtime    = $DataSet.when
		$username   = $DataSet.user
		$extparams  = $DataSet.params
		Write-FudgePopLog -Category "Info" -Message "assigned to device: $deviceName"
		Write-FudgePopLog -Category "Info" -Message "assigned runtime: $runtime"
		if ($runtime -eq 'now' -or (Get-Date).ToLocalTime() -ge $runtime) {
			Write-FudgePopLog -Category "Info" -Message "run: runtime is now or already passed"
			$pkglist = $DataSet.InnerText -split ','
			foreach ($pkg in $pkglist) {
				if ($extparams.length -gt 0) {
					Write-FudgePopLog -Category "Info" -Message "package: $pkg (params: $extparams)"
					if (-not $TestMode) {
						choco uninstall $pkg $extparams
					}
					else {
						Write-FudgePopLog -Category "Info" -Message "TEST MODE : choco uninstall $pkg $extparams"
					}
				}
				else {
					Write-FudgePopLog -Category "Info" -Message "package: $pkg"
					if (-not $TestMode) {
						choco uninstall $pkg -y -r
					}
					else {
						Write-FudgePopLog -Category "Info" -Message "TEST MODE : choco uninstall $pkg -y -r"
					}
				}
			} # foreach
		}
		else {
			Write-FudgePopLog -Category "Info" -Message "skip: not yet time to run this assignment"
		}
	}
	else {
		Write-FudgePopLog -Category "Info" -Message "NO removals have been assigned to this computer"
	}
}

<#
.SYNOPSIS
	Execute REGISTRY directives from XML control file
.PARAMETER DataSet
	XML data set fed from the XML control file
#>

function Invoke-FPRegistry {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$True)]
		$DataSet
	)
	Write-FudgePopLog -Category "Info" -Message "--------- registry assignments ---------"
	if ($DataSet) {
		Write-FudgePopLog -Category "Info" -Message "registry changes have been assigned to this computer"
		Write-FudgePopLog -Category "Info" -Message "assigned device: $devicename"
		foreach ($reg in $DataSet) {
			$regpath    = $reg.path
			$regval     = $reg.value
			$regdata    = $reg.data
			$regtype    = $reg.type
			$deviceName = $reg.device
			Write-FudgePopLog -Category "Info" -Message "assigned to device: $deviceName"
			Write-FudgePopLog -Category "Info" -Message "keypath: $regpath"
			Write-FudgePopLog -Category "Info" -Message "value: $regval"
			Write-FudgePopLog -Category "Info" -Message "data: $regdata"
			Write-FudgePopLog -Category "Info" -Message "type: $regtype"
			if (-not(Test-Path $regpath)) {
				Write-FudgePopLog -Category "Info" -Message "key not found, creating registry key"
				New-Item -Path $regpath -Force | Out-Null
				Write-FudgePopLog -Category "Info" -Message "updating value assignment to $regdata"
				New-ItemProperty -Path $regpath -Name $regval -Value $regdata -PropertyType $regtype -Force | Out-Null
			}
			else {
				Write-FudgePopLog -Category "Info" -Message "key already exists"
				$cv = Get-ItemProperty -Path $regpath -Name $regval | Select-Object -ExpandProperty $regval
				Write-FudgePopLog -Category "Info" -Message "current value of $regval is $cv"
				if ($cv -ne $regdata) {
					Write-FudgePopLog -Category "Info" -Message "updating value assignment to $regdata"
					New-ItemProperty -Path $regpath -Name $regval -Value $regdata -PropertyType $regtype -Force | Out-Null
				}
			}
		} # foreach
	}
	else {
		Write-FudgePopLog -Category "Info" -Message "NO registry changes have been assigned to this computer"
	}
}

<#
.SYNOPSIS
	Execute SERVICES directives from XML control file
.PARAMETER DataSet
	XML data set fed from the XML control file
#>

function Invoke-FPServices {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$True)]
		$DataSet
	)
	Write-FudgePopLog -Category "Info" -Message "--------- services assignments ---------"
	foreach ($service in $DataSet) {
		$svcName    = $service.name
		$svcStart   = $service.startup
		$svcAction  = $service.action
		$deviceName = $service.device
		Write-FudgePopLog -Category "Info" -Message "assigned to device: $deviceName"
		Write-FudgePopLog -Category "Info" -Message "service name: $svcName"
		Write-FudgePopLog -Category "Info" -Message "startup should be: $svcStart"
		Write-FudgePopLog -Category "Info" -Message "requested action: $svcAction"
		try {
			$scfg = Get-Service -Name $svcName
			$sst  = $scfg.StartType
			if ($svcStart -ne "" -and $scfg.StartType -ne $svcStart) {
				Write-FudgePopLog -Category "Info" -Message "current startup type is: $sst"
				Write-FudgePopLog -Category "Info" -Message "setting service startup to: $svcStart"
				Set-Service -Name $svcName -StartupType $svcStart | Out-Null
			}
			switch ($svcAction) {
				'start' {
					if ($scfg.Status -ne 'Running') {
						Write-FudgePopLog -Category "Info" -Message "starting service..."
						Start-Service -Name $svcName | Out-Null
					}
					else {
						Write-FudgePopLog -Category "Info" -Message "service is already running"
					}
					break
				}
				'restart' {
					Write-FudgePopLog -Category "Info" -Message "restarting service..."
					Restart-Service -Name $svcName -ErrorAction SilentlyContinue
					break
				}
				'stop' {
					Write-FudgePopLog -Category "Info" -Message "stopping service..."
					Stop-Service -Name $svcName -Force -NoWait -ErrorAction SilentlyContinue
					break
				}
			} # switch
		}
		catch {
			Write-FudgePopLog -Category "Error" -Message "service not found: $svcName"
		}
	} # foreach
}

<#
.SYNOPSIS
	Execute FOLDERS directives from XML control file
.PARAMETER DataSet
	XML data set fed from the XML control file
#>

function Invoke-FPFolders {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$True)]
		$DataSet
	)
	Write-FudgePopLog -Category "Info" -Message "--------- folder assignments ---------"
	foreach ($folder in $DataSet) {
		$folderPath  = $folder.path
		$deviceName  = $folder.device
		$action = $folder.action
		Write-FudgePopLog -Category "Info" -Message "assigned to device: $deviceName"
		Write-FudgePopLog -Category "Info" -Message "folder action assigned: $action"
		switch ($action) {
			'create' {
				Write-FudgePopLog -Category "Info" -Message "folder path: $folderPath"
				if (-not(Test-Path $folderPath)) {
					Write-FudgePopLog -Category "Info" -Message "creating new folder"
					mkdir -Path $folderPath -Force | Out-Null
				}
				else {
					Write-FudgePopLog -Category "Info" -Message "folder already exists"
				}
				break
			}
			'empty' {
				$filter = $folder.filter
				if ($filter -eq "") { $filter = "*.*" }
				Write-FudgePopLog -Category "Info" -Message "deleting $filter from $folderPath and subfolders"
				Get-ChildItem -Path "$folderPath" -Filter "$filter" -Recurse |
					foreach { Remove-Item -Path $_.FullName -Confirm:$False -Recurse -ErrorAction SilentlyContinue }
				Write-FudgePopLog -Category "Info" -Message "some files may remain if they were in use"
				break
			}
		} # switch
	} # foreach
}

<#
.SYNOPSIS
	Execute FILES directives from XML control file
.PARAMETER DataSet
	XML data set fed from the XML control file
#>

function Invoke-FPFiles {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$True)]
		$DataSet
	)
	Write-FudgePopLog -Category "Info" -Message "--------- file assignments ---------"
	foreach ($file in $DataSet) {
		$fileSource = $file.source
		$fileTarget = $file.target
		$action     = $file.action
		Write-FudgePopLog -Category "Info" -Message "file action assigned: $action"
		Write-FudgePopLog -Category "Info" -Message "source: $fileSource"
		Write-FudgePopLog -Category "Info" -Message "target: $fileTarget"
		switch ($action) {
			'download' {
				Write-FudgePopLog -Category "Info" -Message "downloading file"
				break
			}
			'rename' {
				Write-FudgePopLog -Category "Info" -Message "renaming file"
				break
			}
			'move' {
				Write-FudgePopLog -Category "Info" -Message "moving file"
				break
			}
		} # switch
	} # foreach
}

<#
.SYNOPSIS
	Actually initiates all the crap being shoved in its face from the XML file
.PARAMETER DataSet
	XML data set fed from the XML control file
#>

function Invoke-FPTasks {
	param (
		[parameter(Mandatory=$True)]
		$DataSet
	)
	$mypc = $env:COMPUTERNAME
	if ($PayLoad -eq 'Configure') {
		if (Set-FPConfiguration) {
			Write-Host "configuration has been updated"
		}
	}
	else {
		$installs = $DataSet.configuration.deployments.deployment | 
			Where-Object {$_.enabled -eq "true" -and ($_.device -eq $mypc -or $_.device -eq 'all')}
		$removals = $DataSet.configuration.removals.removal | 
			Where-Object {$_.enabled -eq "true" -and ($_.device -eq $mypc -or $_.device -eq 'all')}
		$regkeys  = $DataSet.configuration.registry.reg | 
			Where-Object {$_.enabled -eq "true" -and ($_.device -eq $mypc -or $_.device -eq 'all')}
		$services = $DataSet.configuration.services.service | 
			Where-Object {$_.enabled -eq "true" -and ($_.device -eq $mypc -or $_.device -eq 'all')}
		$folders  = $DataSet.configuration.folders.folder | 
			Where-Object {$_.enabled -eq "true" -and ($_.device -eq $mypc -or $_.device -eq 'all')}
		$files    = $DataSet.configuration.files.file | 
			Where-Object {$_.enabled -eq "true" -and ($_.device -eq $mypc -or $_.device -eq 'all')}
		if ($folders)  { if ($Payload -eq 'All' -or $Payload -eq 'Folders')  { Invoke-FPFolders -DataSet $folders } }
		if ($installs) { if ($Payload -eq 'All' -or $Payload -eq 'Installs') { Invoke-FPChocoInstalls -DataSet $installs } }
		if ($removals) { if ($Payload -eq 'All' -or $Payload -eq 'Removals') { Invoke-FPChocoRemovals -DataSet $removals } }
		if ($regkeys)  { if ($Payload -eq 'All' -or $Payload -eq 'Registry') { Invoke-FPRegistry -DataSet $regkeys } }
		if ($services) { if ($Payload -eq 'All' -or $Payload -eq 'Services') { Invoke-FPServices -DataSet $services } }
		if ($files)    { if ($Payload -eq 'All' -or $Payload -eq 'Files')    { Invoke-FPFiles -DataSet $files } }
	}
}

<#
.SYNOPSIS
	Create or Update Scheduled Task for FudgePop client script
.PARAMETER IntervalHours
	[int][optional] Hourly interval from 1 to 12
#>

function Set-FPConfiguration {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$False, HelpMessage="Recurrence Interval in hours")]
		[ValidateNotNullOrEmpty()]
		[ValidateRange(1,12)]
		[int] $IntervalHours = 1
	)
	Write-Host "Configuring FudgePop scheduled task"
	$taskname = "Run FudgePop"
	Write-FudgePopLog -Category "Info" -Message "updating FudgePop client configuration"
	#$filepath = "$PSSCriptRoot\Public\Invoke-FudgePop.ps1"
	$filepath = "$(Split-Path((Get-Module FudgePop).Path))\Public\Invoke-FudgePop.ps1"
	if (Test-Path $filepath) {
		$action = 'powershell.exe -ExecutionPolicy ByPass -NoProfile -File '+$filepath
		Write-Verbose "creating: SCHTASKS /Create /RU `"SYSTEM`" /SC hourly /MO $IntervalHours /TN `"$taskname`" /TR `"$action`""
		SCHTASKS /Create /RU "SYSTEM" /SC hourly /MO $IntervalHours /TN "$taskname" /TR "$action" /RL HIGHEST
		if (Get-ScheduledTask -TaskName $taskname -ErrorAction SilentlyContinue) {
			Write-FudgePopLog -Category "Info" -Message "task has been created successfully."
			Write-Output $True
		}
		else {
			Write-FudgePopLog -Category "Error" -Message "well, that sucked. no new scheduled task for you."
		}
	}
	else {
		Write-FudgePopLog -Category "Error" -Message "unable to locate file: $filepath"
	}
}
