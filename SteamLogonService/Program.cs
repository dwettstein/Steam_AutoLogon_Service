using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;

namespace SteamLogonService
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        static void Main()
        {
            ServiceBase[] ServicesToRun;
            ServicesToRun = new ServiceBase[] 
            { 
                new SteamLogonService()
            };
            ServiceBase.Run(ServicesToRun);
            // The following code is just for debugging in Visual Studio.
            //(new SteamLogonService()).StartSteamLogonService();
        }
    }
}
