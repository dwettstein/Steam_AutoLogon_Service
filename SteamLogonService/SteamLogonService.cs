using System;
using System.Diagnostics;
using System.Configuration;
using System.ServiceProcess;
using System.Net;
using System.Net.Sockets;
//using System.Security.AccessControl;
using Microsoft.Win32;
using System.Threading;


namespace SteamLogonService
{
    public partial class SteamLogonService : ServiceBase
    {
        private const string EVENT_LOG_SOURCE = "SteamLogonService";
        private const string EVENT_LOG = "Application";
        private const string REGISTRY_PATH = @"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon";
        //private RegistrySecurity userSecurity;
        
        private string serverIpAddress;
        private Int32 serverPort;
        private string autoLogonUser;
        private string autoLogonPassword;
        private string startPhrase;

        private IPAddress localAddr;
        private TcpListener server;
        private bool isServerStopped;
        private Thread serverThread;

        public SteamLogonService()
        {
            InitializeComponent();
            
            if (!EventLog.SourceExists(EVENT_LOG_SOURCE))
                EventLog.CreateEventSource(EVENT_LOG_SOURCE, EVENT_LOG);

            // Read settings from app configuration.
            serverIpAddress = readAppSetting("serverIpAddress");
            serverPort = int.Parse(readAppSetting("serverPort"));
            autoLogonUser = readAppSetting("autoLogonUser");
            autoLogonPassword = readAppSetting("autoLogonPassword");
            startPhrase = readAppSetting("startPhrase");

            localAddr = IPAddress.Parse(serverIpAddress);
        }

        public void StartSteamLogonService()
        {
            OnStart(new string[0]);
        }

        protected override void OnStart(string[] args)
        {
            server = new TcpListener(localAddr, serverPort);
            isServerStopped = false;
            serverThread = new Thread(new ThreadStart(StartServerThread));
            serverThread.Start();
            EventLog.WriteEntry(EVENT_LOG_SOURCE, "The service has been started.", EventLogEntryType.Information);
        }

        protected override void OnStop()
        {
            isServerStopped = true;
            server.Stop();
            server = null;
            if (serverThread.IsAlive)
                serverThread.Abort();
            EventLog.WriteEntry(EVENT_LOG_SOURCE, "The service has been stopped.", EventLogEntryType.Information);
        }

        /// <summary>
        /// See also here: https://web.archive.org/web/20090720052829/http://www.switchonthecode.com/tutorials/csharp-tutorial-simple-threaded-tcp-server
        /// </summary>
        private void StartServerThread()
        {
            try
            {
                // Start listening for client requests.
                server.Start();

                while (!isServerStopped)
                {
                    EventLog.WriteEntry(EVENT_LOG_SOURCE, "Service waiting for a connection...", EventLogEntryType.Information);
                    // Perform a blocking call to accept requests.
                    // You could also use server.AcceptSocket() here.
                    TcpClient client = server.AcceptTcpClient();

                    // Check received start phrase.
                    // See here: https://msdn.microsoft.com/en-us/library/system.net.sockets.tcplistener%28v=vs.110%29.aspx
                    string receivedStartPhrase = "";
                    // Buffer for reading data
                    Byte[] bytes = new Byte[128];
                    NetworkStream stream = client.GetStream();
                    int byteCount = 0;
                    // Wait for 1 seconds until data has been written to stream. Just a quick and dirty solution.
                    Thread.Sleep(1 * 1000);

                    while (true) 
                    {
                        if (!stream.DataAvailable)
                            break;
                        try
                        {
                            //blocks until a client sends a message
                            byteCount += stream.Read(bytes, 0, bytes.Length);
                        }
                        catch (Exception ex)
                        {
                            EventLog.WriteEntry(EVENT_LOG_SOURCE, string.Format("Exception while reading stream: {0}", ex.Message), EventLogEntryType.Error);
                            break;
                        }
                    }
                    
                    receivedStartPhrase = System.Text.Encoding.ASCII.GetString(bytes, 0, byteCount);
                    if (receivedStartPhrase.Equals(startPhrase))
                    {
                        // Send back a response.
                        try
                        {
                            byte[] msg = System.Text.Encoding.ASCII.GetBytes("Start phrase accepted.");
                            stream.Write(msg, 0, msg.Length);
                        }
                        catch (Exception ex)
                        {
                            EventLog.WriteEntry(EVENT_LOG_SOURCE, string.Format("Exception while writing stream: {0}", ex.Message), EventLogEntryType.Error);
                        }

                        EventLog.WriteEntry(EVENT_LOG_SOURCE, "Correct start phrase received! Now setting auto logon values...", EventLogEntryType.SuccessAudit);
                        // Set the auto logon registry values. Enable auto logon just once.
                        bool isAutoLogonEnabled = enableAutoLogon(autoLogonUser, autoLogonPassword, "1");

                        if (isAutoLogonEnabled)
                        {
                            EventLog.WriteEntry(EVENT_LOG_SOURCE, "Successfully set the auto logon values! Now restarting the computer...", EventLogEntryType.Information);
                            restartComputer(0);
                        }
                        else
                        {
                            EventLog.WriteEntry(EVENT_LOG_SOURCE, "Setting the auto logon values failed! Don't restart computer.", EventLogEntryType.Information);
                        }
                    }
                    else
                    {
                        try
                        {
                            // Send back a response.
                            byte[] msg = System.Text.Encoding.ASCII.GetBytes("Start phrase denied.");
                            stream.Write(msg, 0, msg.Length);
                        }
                        catch (Exception ex)
                        {
                            EventLog.WriteEntry(EVENT_LOG_SOURCE, string.Format("Exception while writing stream: {0}", ex.Message), EventLogEntryType.Error);
                        }
                        EventLog.WriteEntry(EVENT_LOG_SOURCE, string.Format("Wrong start phrase received: '{0}'. Do nothing and end connection.", receivedStartPhrase), EventLogEntryType.FailureAudit);
                    }

                    // Wait for 1 second and end connection. Just a quick and dirty solution.
                    Thread.Sleep(1 * 1000);
                    client.Close();
                }
            }
            catch (Exception ex)
            {
                EventLog.WriteEntry(EVENT_LOG_SOURCE, string.Format("Exception: {0}", ex.Message), EventLogEntryType.Error);
            }
        }

        /// <summary>
        /// See also here: http://stackoverflow.com/questions/9810767/32-bit-windows-service-writing-to-the-64-bit-registry-autoadminlogon-keys?rq=1
        /// </summary>
        //private void setRegistryPermission()
        //{
        //    userSecurity = new RegistrySecurity();
        //    System.Security.Principal.SecurityIdentifier sid = new System.Security.Principal.SecurityIdentifier(System.Security.Principal.WellKnownSidType.BuiltinUsersSid, null);
        //    RegistryAccessRule userRule = new RegistryAccessRule(sid, RegistryRights.FullControl, AccessControlType.Allow);
        //    userSecurity.AddAccessRule(userRule);
        //}

        /// <summary>
        /// See also here: http://www.mydigitallife.info/how-to-enable-auto-logon-to-windows-xp-and-vista-joined-as-domain-member/
        /// </summary>
        /// <param name="defaultUserName"></param>
        /// <param name="defaultPassword"></param>
        /// <param name="autoLogonCount"></param>
        private bool enableAutoLogon(string defaultUserName, string defaultPassword, string autoLogonCount)
        {
            bool isSuccess = false;
            try
            {
                //setRegistryPermission();
                
                var regKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64);
                regKey = regKey.OpenSubKey(REGISTRY_PATH, RegistryKeyPermissionCheck.ReadWriteSubTree);
                if (regKey == null)
                {
                    EventLog.WriteEntry(EVENT_LOG_SOURCE, "Error accessing the registry keys.", EventLogEntryType.FailureAudit);
                }
                else
                {
                    try
                    {
                        regKey.SetValue("AutoAdminLogon", "1", RegistryValueKind.String);
                        regKey.SetValue("AutoLogonCount", autoLogonCount, RegistryValueKind.String);
                        regKey.SetValue("DefaultUserName", defaultUserName, RegistryValueKind.String);
                        regKey.SetValue("DefaultPassword", defaultPassword, RegistryValueKind.String);
                        EventLog.WriteEntry(EVENT_LOG_SOURCE, string.Format("Enabled auto logon for '{0}' times.", autoLogonCount), EventLogEntryType.SuccessAudit);
                        isSuccess = true;
                    }
                    catch (Exception ex)
                    {
                        EventLog.WriteEntry(EVENT_LOG_SOURCE, "Problem setting up keys: " + ex.Message, EventLogEntryType.Error);
                    }
                    regKey.Close();
                }
            }
            catch (Exception ex)
            {
                EventLog.WriteEntry(EVENT_LOG_SOURCE, "Exception catched: " + ex.Message, EventLogEntryType.Error);
            }
            return isSuccess;
        }

        private bool disableAutoLogon()
        {
            bool isSuccess = false;
            try
            {
                //setRegistryPermission();

                var regKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Default);
                regKey = regKey.OpenSubKey(REGISTRY_PATH, RegistryKeyPermissionCheck.ReadWriteSubTree);
                if (regKey == null)
                {
                    EventLog.WriteEntry(EVENT_LOG_SOURCE, "Error accessing the registry keys.", EventLogEntryType.FailureAudit);
                }
                else
                {
                    try
                    {
                        regKey.SetValue("AutoAdminLogon", "0", RegistryValueKind.String);
                        regKey.SetValue("AutoLogonCount", "0", RegistryValueKind.String);
                        regKey.SetValue("DefaultUserName", "", RegistryValueKind.String);
                        regKey.SetValue("DefaultPassword", "", RegistryValueKind.String);
                        EventLog.WriteEntry(EVENT_LOG_SOURCE, "Disabled auto logon.", EventLogEntryType.SuccessAudit);
                        isSuccess = true;
                    }
                    catch (Exception ex)
                    {
                        EventLog.WriteEntry(EVENT_LOG_SOURCE, "Problem setting up keys: " + ex.Message, EventLogEntryType.Error);
                    }
                    regKey.Close();
                }
            }
            catch (Exception ex)
            {
                EventLog.WriteEntry(EVENT_LOG_SOURCE, "Exception catched: " + ex.Message, EventLogEntryType.Error);
            }
            return isSuccess;
        }

        private void restartComputer(int timeout)
        {
            Process.Start("shutdown", string.Format("/r /t {0}", timeout.ToString()));
        }

        private string readAppSetting(string key)
        {
            string result = "";
            try
            {
                var appSettings = ConfigurationManager.AppSettings;
                result = appSettings[key] ?? "Not Found";
            }
            catch (Exception ex)
            {
                EventLog.WriteEntry(EVENT_LOG_SOURCE, "Exception catched: " + ex.Message, EventLogEntryType.Error);
            }
            return result;
        }
    }
}
