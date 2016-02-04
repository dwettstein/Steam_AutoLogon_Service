<#
.Synopsis
    Removes auto logon entry.
    
.DESCRIPTION
    Removes auto logon entry.
    
    File-Name:      Remove-AutoLogon.ps1
    Author:         David Wettstein
    Version:        1.0
    
    Changelog:
                    v1.0    19.01.2016, David Wettstein: First implementation.

.PARAMETER defaultUserName
    The user name, which is used to set as default username.
#>

#---------------------------------------------------------------------------------------------------------------------------
# Script parameter
#---------------------------------------------------------------------------------------------------------------------------

[CmdletBinding()]
#[OutputType([int])]
Param (
    [Parameter(
        Mandatory=$false,
        ValueFromPipeline=$true,
        Position=0
    )]
    [String] $defaultUserName = "your_usual_username"
)

#---------------------------------------------------------------------------------------------------------------------------
# Load Modules
#---------------------------------------------------------------------------------------------------------------------------



#---------------------------------------------------------------------------------------------------------------------------
# Global Variables
#---------------------------------------------------------------------------------------------------------------------------

[string]$script:sScriptPath = Split-Path $MyInvocation.MyCommand.Path
[string]$script:sScriptName = Split-Path $MyInvocation.MyCommand.Path -Leaf

[string]$script:sMyDate = "{0:yyyy.MM.dd HH:mm:ss}" -f (Get-Date)
[boolean]$script:bError = $false

#------------------------------------------------------------
# Variables used for Log function.
[string]$script:sLogFileName = $sScriptPath + "\" + $sScriptName + ".log"

[boolean]$script:bIsVerboseGiven = $false
[boolean]$script:bIsDebugGiven = $false

function Set-BoundParams {
    try {
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $True) {
            $script:bIsVerboseGiven = $true
        }
        if ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent -eq $True) {
            $script:bIsDebugGiven = $true
        }
    }
    catch {
        #Write-Warning "Exception: $_"
    }
}
Set-BoundParams

#---------------------------------------------------------------------------------------------------------------------------
# Functions
#---------------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------
# Logs a given message with defined stream to stream and log-file.
function Log {
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0
        )]
        [String] $stream,

        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=1
        )]
        [String] $message
    )
    
    $logDate = "{0:yyyy.MM.dd HH:mm:ss}" -f (Get-Date)
    
    switch ($stream) {
        Host {
            Write-Output "$logDate [HOST] $message" | Out-File -FilePath $sLogFileName -Append
            Write-Host $message
            break
        }
        Output {
            Write-Output "$logDate [OUTPUT] $message" | Out-File -FilePath $sLogFileName -Append
            Write-Output $message
            break
        }
        Verbose {
            if ($bIsVerboseGiven) {
                Write-Output "$logDate [VERBOSE] $message" | Out-File -FilePath $sLogFileName -Append
            }
            Write-Verbose $message
            break
        }
        Warning {
            Write-Output "$logDate [WARNING] $message" | Out-File -FilePath $sLogFileName -Append -Force
            Write-Warning $message
            break
        }
        Error {
            Write-Output "$logDate [ERROR] $message" | Out-File -FilePath $sLogFileName -Append -Force
            Write-Error $message
            break
        }
        Debug {
                if ($bIsDebugGiven) {
                    Write-Output "$logDate [DEBUG] $message" | Out-File -FilePath $sLogFileName -Append -Force
                }
                Write-Debug $message
                break
        }
        default {
            Write-Output "$logDate [DEFAULT] $message" | Out-File -FilePath $sLogFileName -Append
            break
        }
    }
    
    Remove-Variable logDate
    Remove-Variable stream,message
}

function Remove-AutoLogon {
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0
        )]
        [String] $newUserName
    )
    
    $registryKey = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Log Output "Called function 'Remove-AutoLogon' for scriptName '$sScriptName'."

    Log Output "Set registry entry 'AutoAdminLogon' to value: '0'."
    Set-ItemProperty -Path $registryKey -Name AutoAdminLogon -Value 0
    #REG ADD "$registryKey" /v AutoAdminLogon /d 0 /t REG_DWORD /REG:64 /f
    
    Log Output "Remove registry entry 'AutoLogonCount'."
    $regEntry = Get-ItemProperty -Path $registryKey -Name AutoLogonCount -ErrorAction SilentlyContinue
    if ($regEntry -ne $null) {
        Remove-ItemProperty -Path $registryKey -Name AutoLogonCount
    }
    #Set-ItemProperty -Path $registryKey -Name AutoLogonCount -Value 0
    
    Log Output "Set registry entry 'DefaultUserName' to value: '$newUserName'."
    Set-ItemProperty -Path $registryKey -Name DefaultUserName -Value $newUserName
    #REG ADD "$registryKey" /v DefaultUserName /d $newUserName /t REG_SZ /REG:64 /f
    
    Log Output "Remove registry entry 'DefaultPassword'."
    $regEntry = Get-ItemProperty -Path $registryKey -Name DefaultPassword -ErrorAction SilentlyContinue
    if ($regEntry -ne $null) {
        Remove-ItemProperty -Path $registryKey -Name DefaultPassword
    }
    #Set-ItemProperty -Path $registryKey -Name DefaultPassword -Value ""
    #REG ADD "$registryKey" /v DefaultPassword /d $defaultPassword /t REG_SZ /REG:64 /f
    
    Log Output "Successfully reset autologin registry entries."
}


#---------------------------------------------------------------------------------------------------------------------------
# Main
#---------------------------------------------------------------------------------------------------------------------------

try {
    Log Output "Started script '$sScriptName'."

    Remove-AutoLogon -newUserName $defaultUserName
}
catch {
    # Error in $_ or $Error[0] variable.
    $bError = $true
    Log Warning "Exception: $_"
}
finally {
    if ($bError) {
        Remove-Variable bError
        Log Error "An error occurred while executing the script '$sScriptName'."
        Exit 1
    }
    else {
        Remove-Variable bError
        Log Output "The script '$sScriptName' was finished successfully."
        # Delete log file if no error.
        Remove-Item "$sLogFileName"
        Exit 0
    }
}