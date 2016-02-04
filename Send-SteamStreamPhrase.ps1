<#
.Synopsis
    Use this script to send your start phrase to the SteamLogonService. On success the script starts the Steam application ($pathToSteam) automatically.
    If the MAC address of your computer is provided, the script sends first a wake-on-lan packet to it and waits until the computer responds to a ping.
    
.DESCRIPTION
    Use this script to send your start phrase to the SteamLogonService. On success the script starts the Steam application ($pathToSteam) automatically.
    If the MAC address of your computer is provided, the script sends first a wake-on-lan packet to it and waits until the computer responds to a ping.
    
    File-Name:      Send-SteamStreamPhrase.ps1
    Author:         David Wettstein
    Version:        1.1
    
    Changelog:
                    v1.0    22.01.2016, David Wettstein: First implementation.
                    v1.1    02.02.2016, David Wettstein: Added wake-on-lan functions.

.PARAMETER computerIpAddress
    The IP address of your desktop/gaming PC.
.PARAMETER computerPort
    The port on which the SteamLogonService is listening.
.PARAMETER steamStreamPhrase
    The phrase that is sent to the SteamLogonService. This string has to be equal as the string configured within the SteamLogonService.
.PARAMETER macAddress
    The MAC address of your desktop/gaming PC used for wake-on-lan. If you don't want to use wake-on-lan, just leave this parameter empty.
    Use only uppercase letters and ':' or '-' as separator for the MAC address.
.EXAMPLE
    Send-SteamStreamPhrase.ps1 -computerIpAddress "192.168.1.1" -computerPort 13000 -steamStreamPhrase "your_start_phrase" -macAddress "1A:2B:3C:4D:5E:6F"
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
    [String] $computerIpAddress = "192.168.1.1",

    [Parameter(
        Mandatory=$false,
        ValueFromPipeline=$true,
        Position=1
    )]
    [int] $computerPort = 13000,

    [Parameter(
        Mandatory=$false,
        ValueFromPipeline=$true,
        Position=2
    )]
    [String] $steamStreamPhrase = "your_start_phrase",

    [Parameter(
        Mandatory=$false,
        ValueFromPipeline=$true,
        Position=3
    )]
    [String] $macAddress = "" # Optional. Only use uppercase letters and ':' or '-' as separator.
)

#---------------------------------------------------------------------------------------------------------------------------
# Load Modules
#---------------------------------------------------------------------------------------------------------------------------



#---------------------------------------------------------------------------------------------------------------------------
# Global Variables
#---------------------------------------------------------------------------------------------------------------------------

# Change the path of the Steam application here, if it is installed in another folder (e.g. Program Files).
[string]$script:pathToSteam = "C:\Program Files (x86)\Steam\Steam.exe"


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

function Send-TcpMessage {
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0
        )]
        [String] $computerIpAddress,

        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=1
        )]
        [int] $computerPort,

        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=2
        )]
        [string] $message

    )
    
    Log Host "Called function 'Send-TcpMessage' with parameters '$computerIpAddress', '$computerPort' and message '$message'."
    $isSuccess = $false;

    try {
        Log Debug "Creating new TcpClient."
        $tcpClient = New-Object System.Net.Sockets.TcpClient($computerIpAddress, $computerPort);
        $stream = $tcpClient.GetStream();
        
        $waitAnswerInSec = 1;
        Log Debug "Now starting to write the message. Afterwards, wait for '$waitAnswerInSec' seconds."
        $messageInBytes = [System.Text.Encoding]::ASCII.GetBytes($message);
        $stream.Write($messageInBytes, 0, $messageInBytes.Length);

        Start-Sleep -Seconds $waitAnswerInSec;

        $bytes = New-Object Byte[](128);
        $byteCount = 0;
        while ($stream.CanRead -and $stream.DataAvailable) 
        {
            $byteCount += $stream.Read($bytes, 0, $bytes.Length);
        }
        
        $readMessage = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $byteCount);
        Log Host "Received message: $readMessage"

        Log Debug "Successfully wrote message to the TcpClient. Now closing it."
        $stream.Close();
        $tcpClient.Close();
        $isSuccess = $true;
    }
    catch {
        Log Error "An error occurred while executing function 'Send-TcpMessage': $_"
    }
    return $isSuccess;
}

function Send-WakeOnLanPacket {
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0,
            HelpMessage="The target MAC address as string separated with ':' or '-'."
        )]
        [String] $macAddress
    )

    Log Host "Called function 'Send-WakeOnLanPacket' with MAC address '$macAddress'."
    $isSuccess = $false;

    try
    {
        # See also here:
        # https://en.wikipedia.org/wiki/Wake-on-LAN
        # http://blogs.technet.com/b/matthts/archive/2012/06/02/wakeup-machines-a-powershell-script-for-wake-on-lan.aspx
        # http://www.adminarsenal.com/admin-arsenal-blog/powershell-sending-a-wake-on-lan-wol-magic-packet/
        Log Host "Generating wake-on-lan magic packet..."

        # Convert given MAC address into byte array of format: 0x1A,0x2B,0x3C,0x4D,0x5E,0x6F
        $macByteArray = $macAddress -split "[:-]" | ForEach-Object { [Byte] "0x$_"}

        # Construct the Magic Packet frame. Initialize array with: 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
        [Byte[]] $magicPacket = [byte[]]@(255,255,255,255,255,255);
        # Add the MAC address 16 times.
        $magicPacket += ($macByteArray * 16);

        $udpClient = New-Object System.Net.Sockets.UdpClient;
        $broadcast = ([System.Net.IPAddress]::Broadcast);
 
        # Create IP endpoints for each common wake-on-lan port (0, 7, 9)
        $ipEndPoint1 = New-Object System.Net.IPEndPoint($broadcast, 0);
        $ipEndPoint2 = New-Object System.Net.IPEndPoint($broadcast, 7);
        $ipEndPoint3 = New-Object System.Net.IPEndPoint($broadcast, 9);
        
        $numberOfBroadcasts = 3;
        Log Host "Generated packet and UdpClient successfully. Now sending packet to endpoints for '$numberOfBroadcasts' times."

        ## Broadcast UDP packets to the IP endpoints of the machine
        for ($i = 0; $i -lt $numberOfBroadcasts; $i++) {
            $udpClient.Send($magicPacket, $magicPacket.Length, $ipEndPoint1) | Out-Null
            $udpClient.Send($magicPacket, $magicPacket.Length, $ipEndPoint2) | Out-Null
            $udpClient.Send($magicPacket, $magicPacket.Length, $ipEndPoint3) | Out-Null
            # Sleep for 1 seconds before sending next packets.
            Start-Sleep -Seconds 1;
        }

        $isSuccess = $true;
    }
    catch
    {
        Log Error "An error occurred while executing function 'Send-WakeOnLanPacket': $_"
    }
    return $isSuccess;
}

function Wait-OnComputerStarted {
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0
        )]
        [String] $computerIpAddress,

        [Parameter(
            Mandatory=$false,
            ValueFromPipeline=$true,
            Position=1
        )]
        [int] $maxPingAttempts = 1,

        [Parameter(
            Mandatory=$false,
            ValueFromPipeline=$true,
            Position=2,
            HelpMessage="Wait for given amount of seconds after a successful ping to guarantee that the computer has fully booted."
        )]
        [int] $waitInSecAfterSuccessfulPing = 0
    )

    Log Host "Called function 'Wait-OnComputerStarted' with parameters computerIpAddress: '$computerIpAddress', maxPingAttempts: '$maxPingAttempts', waitInSecAfterSuccessfulPing: '$waitInSecAfterSuccessfulPing'."
    $isSuccess = $false;

    try {
        $ping = New-Object System.Net.NetworkInformation.Ping;
        $j = 1;
        do {
            $echo = $ping.Send($computerIpAddress);
            # Wait until the ping response has been arrived.
            Start-Sleep -Seconds 1;
            
            if ($j -gt $maxPingAttempts) {
                throw "The maximum attempts for pings has been reached.";
            }
            $j++
        }
        while ($echo.Status.ToString() -ne "Success")
        
        # Wait for given amount of seconds after a successful ping to guarantee that the computer has fully booted.
        if ($waitInSecAfterSuccessfulPing -gt 0) {
            Start-Sleep -Seconds $waitInSecAfterSuccessfulPing;
        }
        $isSuccess = $true;
    }
    catch {
        Log Error "An error occurred while executing function 'Wait-OnComputerStarted': $_"
    }
    return $isSuccess;
}

#---------------------------------------------------------------------------------------------------------------------------
# Main
#---------------------------------------------------------------------------------------------------------------------------

try {
    Log Host "Started script '$sScriptName'."

    if ($macAddress -ne "") 
    {
        # First check if computer is not already running.
        $isRunning = Wait-OnComputerStarted -computerIpAddress $computerIpAddress;
        if (-not $isRunning) {
            Send-WakeOnLanPacket -macAddress $macAddress;
            Wait-OnComputerStarted -computerIpAddress $computerIpAddress -maxPingAttempts 20 -waitInSecAfterSuccessfulPing 3;
        }
    }

    $isSuccess = Send-TcpMessage -computerIpAddress $computerIpAddress -computerPort $computerPort -message $steamStreamPhrase
    
    if ($isSuccess -eq $true) {
        Log Host "Now starting Steam application."
        start $pathToSteam
    }
}
catch {
    # Error in $_ or $Error[0] variable.
    $bError = $true
    Log Warning "Exception: $_"
}
finally {
    # Remove the Read-Host if you want to close the console window automatically.
    Log Host "Press Enter to continue..."
    Read-Host

    if ($bError) {
        Remove-Variable bError
        Log Error "An error occurred while executing the script '$sScriptName'."
        Exit 1
    }
    else {
        Remove-Variable bError
        Log Debug "The script '$sScriptName' was finished successfully."
        # Delete log file if no error.
        Remove-Item "$sLogFileName"
        Exit 0
    }
}