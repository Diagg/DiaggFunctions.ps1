###################################################
#
# PsFonction 3.6
#
# Compiled By Diagg/www.OSD-Couture.com
#
# My collection of usefull function   
#
#
#
# Changes : 08/04/2015 v1.1 Added Copy-ItemWithProgress function
#			09/04/2015 v1.2 Added Color to log output to console
#					Added Get-CMSite function
#			14/04/2015 V1.3 Bug fix
#			08/05/2016 v1.4 Added Set-CMFolder function
#			16/06/2016 v1.5	Added Get-WindowsVersion function
#                           Added Set-DeploymentEnv function
#			11/07/2016 v1.6 Bug fix	
#			06/12/2016 V1.7 Fixed ZtiUtility import when in SCCM
#			26/02/2017 V1.8 Added TestandLog-Path function
#			27/02/2017 V1.9 Added New-Shortcut function
#			12/04/2017 V2.0 Function Copy-ItemWithProgress has now more parameters
#					Copy-ItemWithProgress -source $SrcPath -dest $DestPath -arg "/Mir" 
#					-arg is not mandatory, if no arg then folder & subfolder content is also copied
#			19/04/2017 V3.0	Added a bunch of functions from Noha Swanson https://github.com/ndswanson/TaskSequenceModule
#					https://ndswanson.wordpress.com/2016/01/02/task-sequence-powershell-module/
#			19/07/2017 V3.1 Log will not be broadcasted in console during deployment
#					Finaly fixed an old bug in the logs
#			28/07/2017 V3.2 Added TestAndLog-RegistryValue
#			31/07/2017 V3.3 Added Invoke-executable by by Nickolaj Andersen
#			17/10/2017 V3.4 Added logging to BDD.log
#			27/01/2018 V3.5	Corrected a bug in the OutToConsole log function
#			31/01/2018 V3.51Logging optimized
#			16/03/2018 V3.6	Added -logpath to Int-Function so a custom log path can be set
#				   	Invoke-Execution rewritten to generate commande outoup					
#           
###################################################

Function Init-Logging
	{
	# Create the default log file.
	# This function must be executed once to avoid error and to make logs working.
	# If no full Log file path is specified, a default log file is created in c:\windows\logs
	
	    Param (
            [parameter(Mandatory = $false)]
            [string]$oPath = ($Global:CurrentScriptPath + "\" + $Global:CurrentScriptName.replace("ps1","log"))
			)
			
		Log-ScriptEvent $oPath "***************************************************************************************************" $Global:CurrentScriptName 1
		Log-ScriptEvent $oPath "Started processing at [$([DateTime]::Now)]." $Global:CurrentScriptName 1
		Log-ScriptEvent $oPath "***************************************************************************************************" $Global:CurrentScriptName 1
		Log-ScriptEvent $oPath " " $Global:CurrentScriptName 1
		Log-ScriptEvent $oPath "***************************************************************************************************" $Global:CurrentScriptName 1

	
		Return $oPath
	}

Function Get-DiaggShortName
    {
    # This function allow powershell to manage files or folders with special char-set like "[]"
    # Borrowed to http://stackoverflow.com/questions/16995359/get-childitem-equivalent-of-dir-x
    # input parameter = file ou folder
    # Return path in 8.3 format !
    # see link for recusive exemple.


        Param (
            [parameter(Mandatory = $true)]
            [string]$oPath
			)

            $fso = New-Object -ComObject Scripting.FileSystemObject

            if (Test-Path -literalpath $oPath)
                {
            
                    if((Get-Item -literalpath $opath).psiscontainer) 
                        {
                            Return $fso.GetFolder($opath).ShortPath
                        }
                    else 
                        {
                            Return $fso.GetFile($opath).ShortPath
                        } 
                }
        

    }
	

Function IsReady-PsRemoting
	{
	# This function enable WinRm on local computer (don't set the -FromHost parameter) or remote (set -fromHost with the name of the remote PC)
	# You can also add a list of machine to add to the trusted host list with the -withRemotePc parameter. if multiple computers must be added, 
	# the list should be submitted in form of "PC1,PC2,PC3". if the parameter is empty, the "*" is added to the trusted host list.
	# Borrowed to https://richardspowershellblog.wordpress.com/2014/05/22/adding-to-the-trusted-hosts-list/
	
	
		Param (
            [parameter(Mandatory = $false)]
            [string]$WithRemotePc = "*",
			[string]$FromHost = $env:COMPUTERNAME
			)
			
			
		If ((Get-Service WinRm).Status -ne "Running")
			{
				try
					{
						Enable-PSRemoting –force -verbose
					}
				catch
					{
					   If ($_.Exception.ToString() -like '*this machine is set to Public*')
						{
							Get-NetConnectionProfile -NetworkCategory public|Set-NetConnectionProfile -NetworkCategory Private
							Enable-PSRemoting –force -verbose
						}
					}
			}
			
			
		if (Test-Connection -ComputerName $FromHost -Quiet -Count 1) 
			{
				$th = Get-WSManInstance -ResourceURI winrm/config/client -ComputerName $FromHost | 	select -ExpandProperty TrustedHosts

				if ($th) 
					{
						$newth = $th + ", $WithRemotePc"
					}
				else 
					{
						$newth = $WithRemotePc
					}

				Set-WSManInstance -ResourceURI winrm/config/client -ComputerName $FromHost -ValueSet @{TrustedHosts = $newth}
			}
		else 
			{
				Write-Warning -Message "$FromHost is unreachable"
			}	
			
			
		If ((Get-Service WinRm).Status -eq "Running")
			{
				IsReady-PsRemoting = $true
			}
		Else
			{
				IsReady-PsRemoting = $false
			}
	}
	
	
Function Log-ScriptEvent 
	{

		##########################################################################################################
		<#

		This Function by Ian Farr : https://gallery.technet.microsoft.com/scriptcenter/Log-ScriptEvent-Function-ea238b85

		.SYNOPSIS
		   Log to a file in a format that can be read by Trace32.exe / CMTrace.exe 

		.DESCRIPTION
		   Write a line of data to a script log file in a format that can be parsed by Trace32.exe / CMTrace.exe

		   The severity of the logged line can be set as:

		        1 - Information
		        2 - Warning
		        3 - Error

		   Warnings will be highlighted in yellow. Errors are highlighted in red.

		   The tools to view the log:

		   SMS Trace - http://www.microsoft.com/en-us/download/details.aspx?id=18153
		   CM Trace - Installation directory on Configuration Manager 2012 Site Server - <Install Directory>\tools\

		.EXAMPLE
		   Log-ScriptEvent c:\output\update.log "Application of MS15-031 failed" Apply_Patch 3

		   This will write a line to the update.log file in c:\output stating that "Application of MS15-031 failed".
		   The source component will be Apply_Patch and the line will be highlighted in red as it is an error 
		   (severity - 3).

		#>
		##########################################################################################################



		#Define and validate parameters
		[CmdletBinding()]
		Param(
		      #Path to the log file
		      [parameter(Mandatory=$False)]
		      [String]$NewLog = $Global:LogFile,

		      #The information to log
		      [parameter(Mandatory=$True)]
		      [String]$Value,

		      #The source of the error
		      [parameter(Mandatory=$False)]
		      [String]$Component = $Global:CurrentScriptName,

		      #The severity (1 - Information, 2- Warning, 3 - Error)
		      [parameter(Mandatory=$False)]
		      [ValidateRange(1,3)]
		      [Single]$Severity = 1,
			  
			  #Also output to console ($True or $False)
		      [parameter(Mandatory=$False)]
		      [bool]$OutToConsole = $True
			  			  
		      )


		#Obtain UTC offset
		$DateTime = New-Object -ComObject WbemScripting.SWbemDateTime 
		$DateTime.SetVarDate($(Get-Date))
		$UtcValue = $DateTime.Value
		$UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21)


		#Create the line to be logged
		$LogLine =  "<![LOG[$Value]LOG]!>" +`
		            "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " +`
		            "date=`"$(Get-Date -Format M-d-yyyy)`" " +`
		            "component=`"$Component`" " +` 
		            "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
		            "type=`"$Severity`" " +`
		            "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +`
		            "file=`"`">"

		#Write the line to the passed log file
		Try
			{Add-Content -Path $NewLog -Value $LogLine} 
		Catch
			{
				While ((TestAndLog-Path -Path $NewLog) -eq $False)
					{ 
						Start-Sleep -Milliseconds 200
						$oWait= $oWait +200
						If ($owait -ge 5000){Break}
					}
				
			}
		
		#Write the Line to BDD.log
		If ($Global:TSenv -eq $True -and  (!([string]::IsNullOrEmpty($Global:OSD_Env.BDDLog))))
			{
				Try
					{Add-Content -Path $($Global:OSD_Env.BDDLog) -Value $LogLine}
				Catch
					{
						While ((TestAndLog-Path -Path $($Global:OSD_Env.BDDLog)) -eq $False)
							{ 
								Start-Sleep -Milliseconds 200
								$oWait= $oWait +200
								If ($owait -ge 5000){Break}
							}					
					
					}
			}
		
		

		If ($OutToConsole)
			{
				If (($Global:TSenv -eq $True -and $Global:OSD_Env.IsStandAlone) -or $Global:TSenv -eq $False -or $Global:TSenv -eq $null)
					{
						switch ($Severity)
						
							{
						
								1 {Write-Host ((Get-Date -Format HH:mm:ss)+ " - " + $Value); break}
						
								2 {Write-Host ((Get-Date -Format HH:mm:ss)+ " - " + $Value) -ForegroundColor black -BackgroundColor Yellow; break}
						
								3 {Write-Host ((Get-Date -Format HH:mm:ss)+ " - " + $Value) -ForegroundColor Red; break}
							}
					}		
			}

	}	
	

Function Copy-ItemWithProgress
	{
		<#
		.SYNOPSIS
		RoboCopy with PowerShell progress.

		.DESCRIPTION
		Performs file copy with RoboCopy. Output from RoboCopy is captured,
		parsed, and returned as Powershell native status and progress.

		.PARAMETER RobocopyArgs
		List of arguments passed directly to Robocopy.
		Must not conflict with defaults: /ndl /TEE /Bytes /NC /nfl /Log

		.OUTPUTS
		Returns an object with the status of final copy.
		REMINDER: Any error level below 8 can be considered a success by RoboCopy.

		.EXAMPLE
		C:\PS> .\Copy-ItemWithProgress c:\Src d:\Dest

		Copy the contents of the c:\Src directory to a directory d:\Dest
		With the /e switch, files, folder and subfolders from the root of c:\src are copied.

		.EXAMPLE
		C:\PS> .\Copy-ItemWithProgress '"c:\Src Files"' d:\Dest /mir /xf *.log -Verbose

		Copy the contents of the 'c:\Name with Space' directory to a directory d:\Dest
		/mir and /XF parameters are passed to robocopy, and script is run verbose

		.LINK
		http://keithga.wordpress.com/2014/06/23/copy-itemwithprogress

		.NOTES
		By Keith S. Garner (KeithGa@KeithGa.com) - 6/23/2014
		With inspiration by Trevor Sullivan @pcgeek86

		#>

		[CmdletBinding()]
		param(
			[Parameter(Mandatory = $true)] 
			[string[]] $Source,
			[Parameter(Mandatory = $true)] 
			[string[]] $Dest,			
			[Parameter(Mandatory = $false,ValueFromRemainingArguments=$true)] 
			[string[]] $Args="/E"
		)
		
		#remove last char if it's "\"
		If ($Source.EndsWith("\")) {$source = $source.Substring(0,$source.Length-1)}
		If ($Dest.EndsWith("\")) {$Dest = $Dest.Substring(0,$Dest.Length-1)}
		
		# Add quote to paths
		$Source = [char]34 + $Source + [char]34
		$Dest = [char]34 + $Dest + [char]34
		
		#Rebuild arg
		$RobocopyArgs = $Source + " " + $Dest + " " + $Args + " " 
		
		$ScanLog  = [IO.Path]::GetTempFileName()
		$RoboLog  = [IO.Path]::GetTempFileName()
		$ScanArgs = $RobocopyArgs + "/ndl /TEE /bytes /Log:$ScanLog /nfl /L".Split(" ")
		$RoboArgs = $RobocopyArgs + "/ndl /TEE /bytes /Log:$RoboLog /NC".Split(" ")

		# Launch Robocopy Processes
		Log-ScriptEvent -value ("Robocopy Scan:`n " + ($ScanArgs -join " ")) -Component "Function-Library(Copy-ItemWithProgress)" -Severity  1 -OutToConsole $True
		Log-ScriptEvent -value ("Robocopy Full:`n " + ($RoboArgs -join " ")) -Component "Function-Library(Copy-ItemWithProgress)" -Severity  1 -OutToConsole $True
		Log-ScriptEvent -value "Log file Scan : $ScanLog" -Component "Function-Library(Copy-ItemWithProgress)" -Severity  1 -OutToConsole $True
		Log-ScriptEvent -value "Log file Copy : $RoboLog" -Component "Function-Library(Copy-ItemWithProgress)" -Severity  1 -OutToConsole $True
		$ScanRun = start-process robocopy -PassThru -WindowStyle Hidden -ArgumentList $ScanArgs
		$RoboRun = start-process robocopy -PassThru -WindowStyle Hidden -ArgumentList $RoboArgs

		# Parse Robocopy "Scan" pass
		$ScanRun.WaitForExit()
		$LogData = get-content $ScanLog
		if ($ScanRun.ExitCode -ge 10)
		{
			$LogData|out-string|Write-Error
			throw "Robocopy $($ScanRun.ExitCode)"
		}
		$FileSize = [regex]::Match($LogData[-4],".+:\s+(\d+)\s+(\d+)").Groups[2].Value
		Log-ScriptEvent -value ("Robocopy Bytes: $FileSize `n" +($LogData -join "`n")) -Component "Function-Library(Copy-ItemWithProgress)" -Severity  1 -OutToConsole $True

		# Monitor Full RoboCopy
		while (!$RoboRun.HasExited)
		{
			$LogData = get-content $RoboLog
			$Files = $LogData -match "^\s*(\d+)\s+(\S+)"
		    if ($Files -ne $Null )
		    {
			    $copied = ($Files[0..($Files.Length-2)] | %{$_.Split("`t")[-2]} | Measure -sum).Sum
			    if ($LogData[-1] -match "(100|\d?\d\.\d)\%")
			    {
				    write-progress Copy -ParentID $RoboRun.ID -percentComplete $LogData[-1].Trim("% `t") $LogData[-1]
				    $Copied += $Files[-1].Split("`t")[-2] /100 * ($LogData[-1].Trim("% `t"))
			    }
			    else
			    {
				    write-progress Copy -ParentID $RoboRun.ID -Completed
			    }
				$PercentComplete = [math]::min(100,(100*$Copied/[math]::max($Copied,$FileSize)))
				write-progress ROBOCOPY -ID $RoboRun.ID -PercentComplete $PercentComplete $Files[-1].Split("`t")[-1] 
		    }
		}

		write-progress Copy -ParentID $RoboRun.ID -Completed
		write-progress Copy -ID $RoboRun.ID -Completed

		# Parse full RoboCopy pass results, and cleanup
		(get-content $RoboLog)[-50..-2] | out-string | Write-Verbose
		[PSCustomObject]@{ ExitCode = $RoboRun.ExitCode }
		remove-item $RoboLog, $ScanLog
	}


Function Get-CMSite
	{

		# this funtion will return an object with properties like SCCM Site Name and Sccm server site Name. It will also import the SCCM powershell module.
		# thanks and respect to Andrew Barns for great inspiration

    #Load the ConfigurationManager Module
    If (test-path "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1" )
        {
            If (!(Get-Module ConfigurationManager))
                {
                    Log-ScriptEvent -value "Importing SCCM Module." -Component "Function-Library(Get-CMSite)" -Severity  1 -OutToConsole $True
					Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"
                }
        }
    Else
        {
            Log-ScriptEvent -value "No Powershell module found !!!" -Component "Function-Library(Get-CMSite)" -Severity  3 -OutToConsole $True
			Log-ScriptEvent -value "SCCM Console not installed or script launched with insuffisant access right. Exiting !!!" -Component "Function-Library" -Severity  3 -OutToConsole $True
            Exit
        }

    # Check if the SCCM drive Exist 
    $CCMDrive = (Get-PSDrive -PsProvider CMSITE).Name
        If (!([string]::IsNullOrEmpty($CCMDrive)))
            {
                Log-ScriptEvent -value ("SCCM Drive Found with name : " + $CCMDrive) -Component "Function-Library" -Severity  1 -OutToConsole $True
				[PSCustomObject]@{ SiteCode = $CCMDrive ; SiteDrive = ($CCMDrive + ":") ; SiteServer = (get-psdrive $CCMDrive).root }
            }
        Else
            {
                Log-ScriptEvent -value "Unable to find SCCM Drive. Exiting !!!" -Component "Function-Library" -Severity  3 -OutToConsole $True
                Exit
            }

	}
	

Function Set-CMFolder
	{
	
		#This function will create folders into SCCM Console
		# Usage Set-CMFolder -Path <SCCM console Path without site name>
		# Exemple Set-CMFolder -Path "\Package\12 - Deploiement OS\NEDUGO"
	
		#Define and validate parameters
		[CmdletBinding()]
		Param(
			      #Path to the SCCM Folder
			      [parameter(Mandatory=$True)]
			      [String]$Path

		    	)
	
	
		# Save Current location
		$CurrentLocation = Get-Location
				
		# Relocate to SCCM Drive
		CD $CMSiteInfo.SiteDrive
		
		# Rebuild fill patch
		$Path = $CMSiteInfo.SiteDrive + $Path

		# create folders in SCCM console Driver's folder
		Log-ScriptEvent -value "Creating folders in SCCM Console with this path $Path "  -Component $Global:CurrentScriptName -Severity  1 -OutToConsole $True
		$FinalFolder =""
		$subFolders = $Path.Split("\")
		ForEach ($Folder in $subFolders)
			{
				$FinalFolder = $FinalFolder + $Folder + "\"
				
				If (!(Test-Path $FinalFolder.substring(0,$FinalFolder.Length - 1)))
			    {
					Log-ScriptEvent -value "Creating new sccm folder : $FinalFolder" -Component $Global:CurrentScriptName -Severity  1 -OutToConsole $True
					New-item -path $FinalFolder

			    }
			}
			
		# relocate back to previous location
		CD $CurrentLocation
	}	
	
	
Function Get-WindowsVersion
	{
		# this funtion will return an object with properties like :
		# full Windows version number as string (.fullNum) ex: 10.0.10586
		# Short Windows version number as a number (.MiniNum) ex: 10
		# SKU Name (.SKU) ex: Windows 10
		# Short SKU Name (.MinSKU) ex: Win10
		# Os Architecture (.Arch) ex: x64
		# Build Number as a number(Build) ex: 10586
		# Edition of Windows (.edition) ex: Microsoft Windows 10 Enterprise
		# Service Pack Level (.ServicePack) ex: SP1
		# Servicing CBB (.IsCBB) ex: $True
		# Servicing LSTB (.IsLTSB) ex: $False
		
		$FullNum =  (Get-WmiObject win32_operatingSystem).Version
        $MiniNum= $FullNum.Split(".")[0] + "." + $FullNum.Split(".")[1] 
        switch ($MiniNum)
            {
             "10.0" { [int]$MiniNum = 10}
             "6.1" { [int]$MiniNum = 7}
             "6.2" { [int]$MiniNum = 8}
             "6.3" { [single]$MiniNum = 8,1}
            }

		$SKU = ("Windows " + ($FullNum.Split(".")[0]))
		$MiniSKU = ("Win" + ($FullNum.Split(".")[0]))
		[int]$Build = [Convert]::ToInt32((Get-WmiObject win32_operatingSystem).BuildNumber,10)
		
		$Arch = (Get-WmiObject win32_operatingSystem).OSArchitecture
		If ($Arch -eq "64 bits") {$Arch = "x64"} Else {$Arch = "x86"}
		
		$Edition = (Get-WmiObject win32_operatingSystem).Caption
		
		$ServicePack = (Get-WmiObject win32_operatingSystem).ServicePackMajorVersion
		If ($ServicePack -eq 0) {$ServicePack = "RTM"} Else {$ServicePack = ("SP" + $ServicePack)}
		
		If ($MiniNum -ge 10)
			{
				If (((Get-CimInstance Win32_OperatingSystem).Caption).contains('LTSB'))
				   	{$IsLTSB = $true; $IsCBB = $False} Else {$IsLTSB = $False; $IsCBB = $True}
			}
		Else
			{
				$IsLTSB = $False; $IsCBB = $False
			}
				
		[PSCustomObject]@{ FullNum = $FullNum ; MiniNum = $MiniNum ; SKU = $SKU ; MiniSKU = $MiniSKU ; Arch = $Arch ; Build = $Build ; Edition = $Edition ; ServicePack = $ServicePack ; IsLTSB = $IsLTSB ; IsCBB = $IsCBB }
		
	}
	
Function Set-DeploymentEnv
	{
	
		# Warning: Log-ScriptEvent is not yet initialized and can't be used at this stage !!!! 
	
	
		##== Import MDT Module
		If (Test-Path 'C:\_SMSTaskSequence\WDPackage\Tools\Modules\ZTIUtility\ZTIUtility.psm1') 
			{
				$env:PSModulePath = $env:PSModulePath + ";C:\_SMSTaskSequence\WDPackage\Tools\Modules\"
				$IsSCCM = $true
			}
		
		
		If (!((Get-Module).name -eq "ZTIUtility"))	
			{
				Import-Module "ZTIUtility" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
			}	

		If (!((Get-Module).name -eq "ZTIUtility"))	
			{
				$Global:TSenv = $False
			}
		Else
			{
				##== Verfiy that the drive is loaded and not empty
				If((Get-PSDrive).name -eq "TSenv") 
					{
						If ((Get-childitem TSenv:).count -gt 10) 
							{
								$Global:TSenv = $True
								
								#Get Task Sequence Name
								[xml]$TSXml = $tsenv:_SMSTSTaskSequence
								$TSName = $TSXml.sequence.Name
								
								#Get Deployment Method
								If (($tsenv:DeploymentMethod -eq "SCCM") -or ($tsenv:DeploymentMethod -eq "OSD") -or ($IsSCCM -eq $True))
									{$IsSCCM = $true; $IsMDT = $False; $IsStandAlone = $false}	
								ElseIf (($tsenv:DeploymentMethod -eq "UNC") -or ($tsenv:DeploymentMethod -eq "MEDIA"))
									{$IsSCCM = $False; $IsMDT = $True; $IsStandAlone = $false}
								Else {$IsSCCM = $False; $IsMDT = $False; $IsStandAlone = $True}	
								
								
								#Get BDD Log
								If ($IsSCCM -eq $False)
									{
										$oDrives = (get-psdrive| where Provider -like "*FileSystem*" ).Root 
										ForEach ( $oDrv in $oDrives )
											{
												$oBddLog = ($oDrv + "MININT\SMSOSD\OSDLOGS\BDD.log")
												If (test-path $oBddLog )
													{
														break	
													}
											}
										#Create Returning Object
										[PSCustomObject]@{ TaskSequenceName = $TSName  ; IsSCCM = $IsSCCM ; IsMDT = $IsMDT ; IsStandAlone = $IsStandAlone ; TaskSequenceXML = $TSXml ; BDDLog = $oBddLog }
											
									}		
								Else
									{
										#Create Returning Object
										[PSCustomObject]@{ TaskSequenceName = $TSName  ; IsSCCM = $IsSCCM ; IsMDT = $IsMDT ; IsStandAlone = $IsStandAlone ; TaskSequenceXML = $TSXml }
									}	
							} 
						Else 
							{
								$Global:TSenv = $False
								Return $Null
							} 
					} 
				Else 
					{
						$Global:TSenv = $False
						Return $Null
					}
 			}
	}
	
	
	
	
Function TestAndLog-Path
	{
	
		#Define and validate parameters
		[CmdletBinding()]
		Param(
			      #Path to verify
			      [parameter(Mandatory=$True)]
			      [String]$Path,
				  
				  #Action to log
				  [ValidateSet("created","modified","checked")]
				  [String]$Action="checked"

		    	)
		
		# check if this a path or a file
		If ($Path.Substring($Path.Length-4).StartsWith(".")) {$PathType= 'File'} Else {$PathType= 'Folder'} 	
				
		If (Test-Path $Path)
			{
				# Check if path is locked		
				$oFile = New-Object System.IO.FileInfo $Path

				try 
					{
		    			$oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		    			if ($oStream) {$oStream.Close()}
						return $True
		  			} 
				catch 
					{
		    			# file is locked by a process.
						Log-ScriptEvent -value "File $Path is locked and can't be processed !" -Severity 2
						return $false
		  			}				
				
			}
		Else	
			{
				Log-ScriptEvent -value "Error, $PathType $Path not found !!!" -Severity  2
				Return $false
			}
	}
	
	
function TestAndLog-RegistryValue 
	{

		param (

				#Path to Verify
				[parameter(Mandatory=$true)]
				[ValidateNotNullOrEmpty()]$Path,

				#Registry Value to verify
				[parameter(Mandatory=$true)]
				[ValidateNotNullOrEmpty()]$Value,
				 
				#Action to log
				[ValidateSet("created","modified","checked")]
				[String]$Action="checked"
			 
			)

		$CheckPath = TestAndLog-Path $Path		
		
		If ($CheckPath)
			{
				try 
					{
						$Content = (Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop)
					}
				catch 
					{
						Log-ScriptEvent -value "Error, RegistryKey $Value not found at $Path !!!" -Severity  2
					}
				Finally
					{
						If (-not([string]::IsNullOrWhiteSpace($Content)))
							{
				 				Log-ScriptEvent -value "Value $content from $Path\Value was $Action Sucessfully" -Severity 1							
							}
						Else
							{
								$Content = $false
							}
						
					}
				Return $Content
			}
	}	
	
	

Function New-Shortcut 
	{ 
		<#   
		.SYNOPSIS   
		    This script is used to create a  shortcut.         
		.DESCRIPTION   
		    This script uses a Com Object to create a shortcut. 
		.PARAMETER Path 
		    The path to the shortcut file.  .lnk will be appended if not specified.  If the folder name doesn't exist, it will be created. 
		.PARAMETER TargetPath 
		    Full path of the target executable or file. 
		.PARAMETER Arguments 
		    Arguments for the executable or file. 
		.PARAMETER Description 
		    Description of the shortcut. 
		.PARAMETER HotKey 
		    Hotkey combination for the shortcut.  Valid values are SHIFT+F7, ALT+CTRL+9, etc.  An invalid entry will cause the  
		    function to fail. 
		.PARAMETER WorkDir 
		    Working directory of the application.  An invalid directory can be specified, but invoking the application from the  
		    shortcut could fail. 
		.PARAMETER WindowStyle 
		    Windows style of the application, Normal (1), Maximized (3), or Minimized (7).  Invalid entries will result in Normal 
		    behavior. 
		.PARAMETER Icon 
		    Full path of the icon file.  Executables, DLLs, etc with multiple icons need the number of the icon to be specified,  
		    otherwise the first icon will be used, i.e.:  c:\windows\system32\shell32.dll,99 
		.PARAMETER admin 
		    Used to create a shortcut that prompts for admin credentials when invoked, equivalent to specifying runas. 
		.NOTES   
		    Author        : Rhys Edwards 
		    Email        : powershell@nolimit.to   
		.INPUTS 
		    Strings and Integer 
		.OUTPUTS 
		    True or False, and a shortcut 
		.LINK   
		    Script posted over:  N/A   
		.EXAMPLE   
		    New-Shortcut -Path c:\temp\notepad.lnk -TargetPath c:\windows\notepad.exe     
		    Creates a simple shortcut to Notepad at c:\temp\notepad.lnk 
		.EXAMPLE 
		    New-Shortcut "$($env:Public)\Desktop\Notepad" c:\windows\notepad.exe -WindowStyle 3 -admin 
		    Creates a shortcut named Notepad.lnk on the Public desktop to notepad.exe that launches maximized after prompting for  
		    admin credentials. 
		.EXAMPLE 
		    New-Shortcut "$($env:USERPROFILE)\Desktop\Notepad.lnk" c:\windows\notepad.exe -icon "c:\windows\system32\shell32.dll,99" 
		    Creates a shortcut named Notepad.lnk on the user's desktop to notepad.exe that has a pointy finger icon (on Windows 7). 
		.EXAMPLE 
		    New-Shortcut "$($env:USERPROFILE)\Desktop\Notepad.lnk" c:\windows\notepad.exe C:\instructions.txt 
		    Creates a shortcut named Notepad.lnk on the user's desktop to notepad.exe that opens C:\instructions.txt  
		.EXAMPLE 
		    New-Shortcut "$($env:USERPROFILE)\Desktop\ADUC" %SystemRoot%\system32\dsa.msc -admin  
		    Creates a shortcut named ADUC.lnk on the user's desktop to Active Directory Users and Computers that launches after  
		    prompting for admin credentials 
		#> 
		 
		[CmdletBinding()] 
		param( 
		    [Parameter(Mandatory=$True,  ValueFromPipelineByPropertyName=$True,Position=0)]  
		    [Alias("File","Shortcut")]  
		    [string]$Path, 
		 
		    [Parameter(Mandatory=$True,  ValueFromPipelineByPropertyName=$True,Position=1)]  
		    [Alias("Target")]  
		    [string]$TargetPath, 
		 
		    [Parameter(ValueFromPipelineByPropertyName=$True,Position=2)]  
		    [Alias("Args","Argument")]  
		    [string]$Arguments, 
		 
		    [Parameter(ValueFromPipelineByPropertyName=$True,Position=3)]   
		    [Alias("Desc")] 
		    [string]$Description, 
		 
		    [Parameter(ValueFromPipelineByPropertyName=$True,Position=4)]   
		    [string]$HotKey, 
		 
		    [Parameter(ValueFromPipelineByPropertyName=$True,Position=5)]   
		    [Alias("WorkingDirectory","WorkingDir")] 
		    [string]$WorkDir, 
		 
			[Parameter(ValueFromPipelineByPropertyName=$True,Position=6)]
			[ValidateSet("Normal","Maximized","Minimized")]
			[String]$WindowStyle="Normal", 
		 
		    [Parameter(ValueFromPipelineByPropertyName=$True,Position=7)]   
		    [string]$Icon, 
		 
		    [Parameter(ValueFromPipelineByPropertyName=$True)]   
		    [switch]$admin 
		) 
		 
		 
		Process 
			{ 
		 
		  		If (!($Path -match "^.*(\.lnk)$")) 
					{ 
		    			$Path = "$Path`.lnk" 
		  			} 
		  		[System.IO.FileInfo]$Path = $Path 
		  	Try 
				{ 
		    		If (!(Test-Path $Path.DirectoryName)) 
						{ 
		      				md $Path.DirectoryName -ErrorAction Stop | Out-Null 
		    			} 
		  		} 
			Catch 
				{ 
		    		Log-ScriptEvent -value "Unable to create $($Path.DirectoryName), shortcut cannot be created"  -Component $Global:CurrentScriptName -Severity 2 -OutToConsole $True
		    		Return $false 
		    		Break 
		  		} 
		 
			# Convert Window size to integer
			if( $WindowStyle -like "Normal" ) { [Int]$WindowStyle = 1 }
			if( $WindowStyle -like "Maximized" ) { [Int]$WindowStyle = 3 }
			if( $WindowStyle -like "Minimized" ) { [Int]$WindowStyle = 7 }

		 
		  # Define Shortcut Properties 
		  $WshShell = New-Object -ComObject WScript.Shell 
		  $Shortcut = $WshShell.CreateShortcut($Path.FullName)
		  if($Hotkey.Length -gt 0 ) { $Shortcut.HotKey = $Hotkey }
		  if($Arguments.Length -gt 0 ) { $Shortcut.Arguments = $Arguments }
		  if($Description.Length -gt 0 ) { $Shortcut.Description = $Description }
		  if($WorkDir.Length -gt 0 ) { $Shortcut.WorkingDirectory = $WorkDir }
		  If($Icon.Length -gt 0){ $Shortcut.IconLocation = $Icon }
		  $Shortcut.TargetPath = $TargetPath 
		  $Shortcut.WindowStyle = $WindowStyle 
		 
		 
		  Try 
			{ 
			    # Create Shortcut 
			    $Shortcut.Save() 
			    # Set Shortcut to Run Elevated 
			    If ($admin) 
					{      
						$TempFileName = [IO.Path]::GetRandomFileName() 
						$TempFile = [IO.FileInfo][IO.Path]::Combine($Path.Directory, $TempFileName) 
						$Writer = New-Object System.IO.FileStream $TempFile, ([System.IO.FileMode]::Create) 
						$Reader = $Path.OpenRead() 
						While ($Reader.Position -lt $Reader.Length) { 
							$Byte = $Reader.ReadByte() 
						    If ($Reader.Position -eq 22) {$Byte = 34} 
						    $Writer.WriteByte($Byte) 
						} 
						$Reader.Close() 
						$Writer.Close() 
						$Path.Delete() 
						Rename-Item -Path $TempFile -NewName $Path.Name | Out-Null 
			    	} 
			    Return $True 
		  	} 
		Catch 
			{ 
		    	Log-ScriptEvent -value "Unable to create $($Path.FullName)" -Component $Global:CurrentScriptName -Severity 2 -OutToConsole $True
				Log-ScriptEvent -value $Error[0].Exception.Message -Component $Global:CurrentScriptName -Severity 2 -OutToConsole $True  
		    	Return $False 
		  	} 
		 
		} 
	}
	
	
	
Function Init-Function
	{

		param( 
		    [Parameter(Mandatory=$false)]  
		    [string]$logPath
            )



		$Global:OSD_Env = Set-DeploymentEnv

        	If ([string]::IsNullOrWhiteSpace($logPath)) {$logPath = ($Global:CurrentScriptPath + "\" + $Global:CurrentScriptName.replace("ps1","log"))}
		If ($OSD_Env.IsSCCM -or $OSD_Env.IsMDT)
			{
				$Global:LogFile = Init-Logging -oPath $logPath
			}
		Else
			{
				$Global:LogFile = Init-Logging -oPath $logPath
			}
		Log-ScriptEvent -value "LogFile is located in  : $Global:LogFile"	
		
				
		If($Global:TSenv -eq $False) {Log-ScriptEvent -value "ERROR : unable to import MDT Powershell Module !!!" -Severity 3}
		
		
		$Global:OS_Env = Get-WindowsVersion
		
		#Init Com object for aditional functions
		If ($Global:OSD_Env.IsSCCM -or $Global:OSD_Env.IsMDT)
			{
				$Global:TaskSequenceProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI
			}
	}
	
function Show-TSActionProgress	
	{
	    <#
	    .SYNOPSIS
	    Shows task sequence secondary progress of a specific step
	    
	    .DESCRIPTION
	    Adds a second progress bar to the existing Task Sequence Progress UI.
	    This progress bar can be updated to allow for a real-time progress of
	    a specific task sequence sub-step.
	    The Step and Max Step parameters are calculated when passed. This allows
	    you to have a "max steps" of 400, and update the step parameter. 100%
	    would be achieved when step is 400 and max step is 400. The percentages
	    are calculated behind the scenes by the Com Object.
	    
	    .PARAMETER Message
	    The message to display the progress
	    .PARAMETER Step
	    Integer indicating current step
	    .PARAMETER MaxStep
	    Integer indicating 100%. A number other than 100 can be used.
	    .INPUTS
	     - Message: String
	     - Step: Long
	     - MaxStep: Long
	    .OUTPUTS
	    None
	    .EXAMPLE
	    Set's "Custom Step 1" at 30 percent complete
	    Show-TSActionProgress -Message "Running Custom Step 1" -Step 100 -MaxStep 300
	    
	    .EXAMPLE
	    Set's "Custom Step 1" at 50 percent complete
	    Show-TSActionProgress -Message "Running Custom Step 1" -Step 150 -MaxStep 300
	    .EXAMPLE
	    Set's "Custom Step 1" at 100 percent complete
	    Show-TSActionProgress -Message "Running Custom Step 1" -Step 300 -MaxStep 300
	    #>
	    param(
	        [Parameter(Mandatory=$true)]
	        [string] $Message,
	        [Parameter(Mandatory=$true)]
	        [long] $Step,
	        [Parameter(Mandatory=$true)]
	        [long] $MaxStep
	    )

	    $Global:TaskSequenceProgressUi.ShowActionProgress(`
	        $tsenv:_SMSTSOrgName,`
	        $tsenv:_SMSTSPackageName,`
	        $tsenv:_SMSTSCustomProgressDialogMessage,`
	        $tsenv:_SMSTSCurrentActionName,`
	        [Convert]::ToUInt32($tsenv:_SMSTSNextInstructionPointer),`
	        [Convert]::ToUInt32($tsenv:_SMSTSInstructionTableSize),`
	        $Message,`
	        $Step,`
	        $MaxStep)
	}


function Close-TSProgressDialog
	{
	    <#
	    .SYNOPSIS
	    Hides the Task Sequence Progress Dialog
	    
	    .DESCRIPTION
	    Hides the Task Sequence Progress Dialog
	    
	    .INPUTS
	    None
	    .OUTPUTS
	    None
	    .EXAMPLE
	    Close-TSProgressDialog
	    #>

	    $Global:TaskSequenceProgressUi.CloseProgressDialog()
	}

function Show-TSProgress
	{
	    <#
	    .SYNOPSIS
	    Shows task sequence progress of a specific step
	    
	    .DESCRIPTION
	    Manipulates the Task Sequence progress UI; top progress bar only.
	    This progress bar can be updated to allow for a real-time progress of
	    a specific task sequence step.
	    The Step and Max Step parameters are calculated when passed. This allows
	    you to have a "max steps" of 400, and update the step parameter. 100%
	    would be achieved when step is 400 and max step is 400. The percentages
	    are calculated behind the scenes by the Com Object.
	    
	    .PARAMETER CurrentAction
	    Step Title. Modifies the "Running action: " Message
	    .PARAMETER Step
	    Integer indicating current step
	    .PARAMETER MaxStep
	    Integer indicating 100%. A number other than 100 can be used.
	    .INPUTS
	     - CurrentAction: String
	     - Step: Long
	     - MaxStep: Long
	    .OUTPUTS
	    None
	    .EXAMPLE
	    Set's "Custom Step 1" at 30 percent complete
	    Show-TSProgress -CurrentAction "Running Custom Step 1" -Step 100 -MaxStep 300
	    
	    .EXAMPLE
	    Set's "Custom Step 1" at 50 percent complete
	    Show-TSProgress -CurrentAction "Running Custom Step 1" -Step 150 -MaxStep 300
	    .EXAMPLE
	    Set's "Custom Step 1" at 100 percent complete
	    Show-TSProgress -CurrentAction "Running Custom Step 1" -Step 300 -MaxStep 300
	    #>
	    param(
	        [Parameter(Mandatory=$true)]
	        [string] $CurrentAction,
	        [Parameter(Mandatory=$true)]
	        [long] $Step,
	        [Parameter(Mandatory=$true)]
	        [long] $MaxStep
	    )

	    $Global:TaskSequenceProgressUi.ShowTSProgress(`
	        $tsenv:_SMSTSOrgName, `
	        $tsenv:_SMSTSPackageName, `
	        $tsenv:_SMSTSCustomProgressDialogMessage, `
	        $CurrentAction, `
	        $Step, `
	        $MaxStep)

	}

function Show-TSErrorDialog
	{
		<#
	    .SYNOPSIS
	    Shows the Task Sequence Error Dialog
	    
	    .DESCRIPTION
	    Shows a task sequence error dialog allowing for custom failure pages.
	    
	    .PARAMETER OrganizationName
	    Name of your Organization
	    .PARAMETER CustomTitle
	    Custom Error Title
	    .PARAMETER ErrorMessage
	    Message details of the error
	    .PARAMETER ErrorCode
	    Error Code the Task sequence will exit with
	    .PARAMETER TimeoutInSeconds
	    Timout for the Reboot Prompt
	    .PARAMETER ForceReboot
	    Indicates whether a reboot will be forced or not
	    .INPUTS
	     - OrganizationName: String
	     - CustomTitle: String
	     - ErrorMessage: String
	     - ErrorCode: Long
	     - TimeoutInSeconds: Long
	     - ForceReboot: System.Boolean
	    .OUTPUTS
	    None
	    .EXAMPLE
	    Sets an Error but does not force a reboot
	    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "That thing you tried...it didnt work" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $false
	    
	    .EXAMPLE
	    Sets an Error and forces a reboot
	    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "He's dead Jim!" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $true
	    #>
	    param(
	        [Parameter(Mandatory=$true)]
	        [string] $OrganizationName,
	        [Parameter(Mandatory=$true)]
	        [string] $CustomTitle,
	        [Parameter(Mandatory=$true)]
	        [string] $ErrorMessage,
	        [Parameter(Mandatory=$true)]
	        [long] $ErrorCode,
	        [Parameter(Mandatory=$true)]
	        [long] $TimeoutInSeconds,
	        [Parameter(Mandatory=$true)]
	        [bool] $ForceReboot
	    )

	    if ($ForceReboot)
		    {
		        $Global:TaskSequenceProgressUi.ShowErrorDialog($OrganizationName, $Tsenv:_SMSTSPackageName, $CustomTitle, $ErrorMessage, $ErrorCode, $TimeoutInSeconds, 1)
		    }
	    else
		    {
		        $Global:TaskSequenceProgressUi.ShowErrorDialog($OrganizationName, $Tsenv:_SMSTSPackageName, $CustomTitle, $ErrorMessage, $ErrorCode, $TimeoutInSeconds, 0)
		    }
	}

function Show-TSMessage
	{
	    <#
	    .SYNOPSIS
	    Shows a Windows Forms Message Box
	    
	    .DESCRIPTION
	    Shows a Windows Forms Message Box, but does not return the response.
	    This will halt any current operations while the prompt is shown.
	    
	    .PARAMETER Message
	    Message to be displayed
	    .PARAMETER Title
	    Title of the message box
	    .PARAMETER Type
	    Button Style for the MessageBox
	    0 = OK
	    1 = OK, Cancel
	    2 = Abort, Retry, Ignore
	    3 = Yes, No, Cancel
	    4 = Yes, No
	    5 = Retry, Cancel
	    6 = Cancel, Try Again, Continue
	    .INPUTS
	     - Message: String
	     - Title: String
	     - Type: Long
	    .OUTPUTS
	    None
	    .EXAMPLE
	    Sets an Error but does not force a reboot
	    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "That thing you tried...it didnt work" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $false
	    
	    .EXAMPLE
	    Sets an Error and forces a reboot
	    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "He's dead Jim!" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $true
	    #>
	    param(
	        [Parameter(Mandatory=$true)]
	        [string] $Message,
	        [Parameter(Mandatory=$true)]
	        [string] $Title,
	        [Parameter(Mandatory=$true)]
	        [ValidateRange(0,6)]
	        [long] $Type
	    )

	    $Global:TaskSequenceProgressUi.ShowMessage($Message, $Title, $Type)

	}

function Show-TSRebootDialog
	{
	    <#
	    .SYNOPSIS
	    Shows the Reboot Dialog
	    
	    .DESCRIPTION
	    Shows the Task Sequence "System Restart" Dialog. This allows you
	    to trigger custom Task Sequence Reboot Messages.
	    
	    .PARAMETER OrganizationName
	    Name of your Organization
	    .PARAMETER CustomTitle
	    Custom Title for the Reboot Dialog
	    .PARAMETER Message
	    Detailed Message regarding the reboot
	    .PARAMETER TimeoutInSeconds
	    Timout before the system reboots
	    .INPUTS
	     - OrganizationName: String
	     - CustomTitle: String
	     - Message: String
	     - TimeoutInSeconds: Long
	    .OUTPUTS
	    None
	    .EXAMPLE
	    Show's a Reboot Dialog
	    Show-TSRebootDialog -OrganizationName "My Organization" -CustomTitle "I need a reboot!" -Message "I need to reboot to complete something..." -TimeoutInSeconds 90
	    #>
	    param(
	        [Parameter(Mandatory=$true)]
	        [string] $OrganizationName,
	        [Parameter(Mandatory=$true)]
	        [string] $CustomTitle,
	        [Parameter(Mandatory=$true)]
	        [string] $Message,
	        [Parameter(Mandatory=$true)]
	        [long] $TimeoutInSeconds
	    )

	    $Global:TaskSequenceProgressUi.ShowRebootDialog($OrganizationName, $Tsenv:_SMSTSPackageName, $CustomTitle, $Message, $TimeoutInSeconds)
	}

function Show-TSSwapMediaDialog
	{
		<#
	    .SYNOPSIS
	    Shows Task Sequence Swap Media Dialog.
	    
	    .DESCRIPTION
	    Shows Task Sequence Swap Media Dialog.
	    
	    .PARAMETER TaskSequenceName
	    Name of the Task Sequence
	    .PARAMETER MediaNumber
	    Media Number to insert
	    .INPUTS
	     - TaskSequenceName: String
	     - CustomTitle: Long
	    .OUTPUTS
	    None
	    .EXAMPLE
	    Prompts to insert media #2 for the Task Sequence "My Task Sequence"
	    Show-TSSwapMediaDialog -TaskSequenceName "My Task Sequence" -MediaNumber 2
	    #>
	    param(
	        [Parameter(Mandatory=$true)]
	        [string] $TaskSequenceName,
	        [Parameter(Mandatory=$true)]
	        [long] $MediaNumber
	    )

	    $Global:TaskSequenceProgressUi.ShowSwapMediaDialog($TaskSequenceName, $MediaNumber)

	}
	
	
function Invoke-Executable
	{
	   
		# usage:
		# $Iret = Invoke-Executable -Path "Setup.exe" -Arguments " /install /quiet /norestart"
		# The function return an array with the exit code in $Iret[0], the console output in $Iret[1] and the console ouput errors in $Iret[2]
		
		
		param(
	        [parameter(Mandatory=$true)]
	        [ValidateNotNullOrEmpty()]
	        [string]$Path,

	        [parameter(Mandatory=$false)]
	        [ValidateNotNull()]
	        [string]$Arguments
	    )
		
		
		# Setup the Process startup info
		$pinfo = New-Object System.Diagnostics.ProcessStartInfo
		$pinfo.FileName = $Path
		$pinfo.UseShellExecute = $false
		$pinfo.CreateNoWindow = $true
		$pinfo.RedirectStandardOutput = $true
		$pinfo.RedirectStandardError = $true
		
	    if (-not([String]::isnullorempty($Arguments))){$pinfo.Arguments = $Arguments}
		
		# Create a process object using the startup info
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo = $pinfo
		
				
	    # Invoke Start-Process cmdlet depending on if Arguments parameter input contains a object
        try 
			{$process.Start() | Out-Null}
        catch [System.Exception] 
			{Log-ScriptEvent -value $_.Exception.Message -Severity 2 ; Break}
			
		while (!$process.HasExited){sleep -Seconds 1}
		Log-ScriptEvent -value "Process has existed with return code $($process.ExitCode)"
		
		# get output from stdout and stderr
		$stdout = $process.StandardOutput.ReadToEnd()
		$stderr = $process.StandardError.ReadToEnd()
		if (-not([String]::IsNullOrEmpty($stdout))){foreach ($line in $stdout.split([Environment]::NewLine)){If(-not([String]::IsNullOrEmpty($line))){Log-ScriptEvent -value $line}}}
		if (-not([String]::IsNullOrEmpty($stderr))){foreach ($line in $stderr.split([Environment]::NewLine)){If(-not([String]::IsNullOrEmpty($line))){Log-ScriptEvent -value $line}}}
		
		Return $process.ExitCode,$stdout,$stderr
	}	
	
##################################################################################