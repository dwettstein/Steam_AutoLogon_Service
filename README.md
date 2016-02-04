## Description
The service and scripts within this project can be used for automatically turn on and log on your gaming computer remotely.

For Steam In-Home Streaming, your remote computer has to be unlocked unfortunately. By using the service and scripts within this project you are able to logon and unlock your gaming computer remotely. This is especially useful if you don't want to always auto logon into your gaming account.

#### Procedure
1. The couch computer boots remote computer over Wake-On-Lan (or just power it on manually) and sends start phrase to it after it has booted.
2. The remote computer (Steam Logon Service) receives the start phrase and automatically logs on into your gaming account once (after a reboot).
3. The couch computer can start streaming your Steam games from the remote computer.

#### Recommendations
* Use this service only within your local (home) network and not over the internet.


## Prerequirements, initial setup (on desktop/remote computer)
1. Extract the contents of the installer ZIP to the folder `C:\SteamLogonService\` (just an example, you can also choose another location).
  * Copy over the script `Send-SteamStreamPhrase.ps1` to your couch/streaming computer and update the values in it (IP, Port, start phrase).
2. Install the Steam AutoLogon Service with the provided installer (you can also install it by using Visual Studio if you want, see on the bottom).
3. Goto installation folder and open the file `SteamLogonService.exe.config` with a text editor (e.g. Notepad).
4. Fill in the information needed by the service:
  * IP address of your desktop/remote computer
  * Port of your desktop/remote computer you want to use for the logon command
  * Username of the auto logon account
  * Password of the auto logon account
  * Start phrase you want to use for the logon command
5. Open Windows Firewall and go to Inbound Rules. Create a new rule of type Port and enter your chosen port from above (apply to TCP). Allow the connection, but apply the rule only to your private network.
6. Set up a new local Windows account with username and password from above (no administrator rights needed) on your desktop/remote computer.
7. Log on to the newly created account.
8. Create a scheduled task with following settings:
  * Name: Remove-AutoLogon
  * When running the task, use the following user account: your administrator account (run whether user is logged on or not)
  * Trigger: At log on of your newly created local gaming account.
  * Action:
    * Start a program: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
    * Add arguments: `-File "C:\SteamLogonService\Remove-AutoLogon.ps1"`
9. Start the Steam application within your new gaming account and set up auto-start in Big Picture mode (needed for streaming).
10. Reboot your desktop/remote computer.


## Using the service (on couch/streaming computer)
1. Boot your streaming computer.
2. Either boot (no logon) your desktop/remote computer manually or by using Wake-On-Lan functionality provided in the script.
3. Send start phrase to your desktop/remote computer with Powershell script.
  * You can create a shortcut with: `%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -File "C:\SteamLogonService\Send-SteamStreamPhrase.ps1"` as target if you want.
4. Wait until the desktop/remote computer is ready for streaming (it has to reboot because of Windows restrictions).


## Install/uninstall the service from source code with Visual Studio

#### Install:
1. Open Visual Studio Tools (Startmenu => Visual Studio).
2. Run "Developer Command Prompt" as administrator.
3. Change directory in command prompt to SteamLogonService.exe directory.
4. Use installutil.exe to install the service: `installutil.exe SteamLogonService.exe`

#### Uninstall:
(Repeat steps 1-3 from above.)
4. Use installutil.exe to uninstall the service: `installutil.exe /u SteamLogonService.exe`