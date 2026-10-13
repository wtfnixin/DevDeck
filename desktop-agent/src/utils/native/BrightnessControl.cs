using System;
using System.Collections.Generic;
using System.Management;
using System.Runtime.InteropServices;

namespace DevDeck.Native {
    /// <summary>
    /// DevDeck Native Brightness Control Utility
    /// Fast Win32/WMI/DXVA2 brightness controller without PowerShell overhead.
    /// Supports both internal laptop screens (WMI) and external desktop monitors (DXVA2 DDC/CI).
    /// </summary>
    internal class BrightnessControl {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct PHYSICAL_MONITOR {
            public IntPtr hPhysicalMonitor;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string szPhysicalMonitorDescription;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int left;
            public int top;
            public int right;
            public int bottom;
        }

        private delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData);

        [DllImport("user32.dll")]
        private static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

        [DllImport("dxva2.dll", SetLastError = true)]
        private static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, out uint pdwNumberOfPhysicalMonitors);

        [DllImport("dxva2.dll", SetLastError = true)]
        private static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint dwPhysicalMonitorArraySize, [Out] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

        [DllImport("dxva2.dll", SetLastError = true)]
        private static extern bool GetMonitorBrightness(IntPtr hMonitor, out uint pdwMinimumBrightness, out uint pdwCurrentBrightness, out uint pdwMaximumBrightness);

        [DllImport("dxva2.dll", SetLastError = true)]
        private static extern bool SetMonitorBrightness(IntPtr hMonitor, uint dwNewBrightness);

        [DllImport("dxva2.dll", SetLastError = true)]
        private static extern bool DestroyPhysicalMonitors(uint dwPhysicalMonitorArraySize, [In] PHYSICAL_MONITOR[] pPhysicalMonitorArray);

        static int Main(string[] args) {
            bool isGet = false;
            int delta = 10;
            int absoluteTarget = -1;

            if (args.Length > 0) {
                string arg = args[0].Trim().ToLowerInvariant();
                if (arg == "get" || arg == "status") {
                    isGet = true;
                } else if (arg == "up" || arg == "+") {
                    delta = 10;
                } else if (arg == "down" || arg == "-") {
                    delta = -10;
                } else if (arg.StartsWith("set") && args.Length > 1) {
                    int.TryParse(args[1], out absoluteTarget);
                } else {
                    int parsed;
                    if (int.TryParse(arg.Replace("+", ""), out parsed)) {
                        delta = arg.StartsWith("-") ? -Math.Abs(parsed) : parsed;
                    }
                }
            }

            bool anySuccess = false;
            int reportedBrightness = -1;

            // 1. Internal / Laptop display via WMI (root\wmi)
            try {
                using (var searcher = new ManagementObjectSearcher("root\\wmi", "SELECT * FROM WmiMonitorBrightness WHERE Active = True")) {
                    foreach (ManagementObject obj in searcher.Get()) {
                        int cur = Convert.ToInt32(obj["CurrentBrightness"]);
                        reportedBrightness = cur;

                        if (isGet) {
                            anySuccess = true;
                            break;
                        }

                        int target = absoluteTarget >= 0 ? absoluteTarget : cur + delta;
                        target = Math.Max(0, Math.Min(100, target));

                        using (var classObj = new ManagementClass("root\\wmi", "WmiMonitorBrightnessMethods", null)) {
                            foreach (ManagementObject methodObj in classObj.GetInstances()) {
                                methodObj.InvokeMethod("WmiSetBrightness", new object[] { 0, (byte)target });
                                reportedBrightness = target;
                                anySuccess = true;
                                break;
                            }
                        }
                    }
                }
            } catch (Exception) {
                // Ignore if WMI brightness is not available
            }

            // 2. External Desktop Monitors via DXVA2 (DDC/CI)
            try {
                List<IntPtr> monitors = new List<IntPtr>();
                EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData) {
                    monitors.Add(hMonitor);
                    return true;
                }, IntPtr.Zero);

                foreach (IntPtr hMon in monitors) {
                    uint count = 0;
                    if (GetNumberOfPhysicalMonitorsFromHMONITOR(hMon, out count) && count > 0) {
                        PHYSICAL_MONITOR[] physMons = new PHYSICAL_MONITOR[count];
                        if (GetPhysicalMonitorsFromHMONITOR(hMon, count, physMons)) {
                            for (int i = 0; i < count; i++) {
                                uint minB = 0, curB = 0, maxB = 100;
                                if (GetMonitorBrightness(physMons[i].hPhysicalMonitor, out minB, out curB, out maxB)) {
                                    if (reportedBrightness < 0) {
                                        reportedBrightness = (int)curB;
                                    }

                                    if (!isGet) {
                                        int target = absoluteTarget >= 0 ? absoluteTarget : (int)curB + delta;
                                        if (target < (int)minB) target = (int)minB;
                                        if (target > (int)maxB) target = (int)maxB;

                                        if (SetMonitorBrightness(physMons[i].hPhysicalMonitor, (uint)target)) {
                                            reportedBrightness = target;
                                            anySuccess = true;
                                        }
                                    } else {
                                        anySuccess = true;
                                    }
                                }
                            }
                            DestroyPhysicalMonitors(count, physMons);
                        }
                    }
                }
            } catch (Exception) {
                // Ignore DXVA2 failures
            }

            if (anySuccess) {
                Console.WriteLine(string.Format("BRIGHTNESS:{0}", reportedBrightness));
                return 0;
            } else {
                Console.WriteLine("ERROR:No compatible display monitor detected");
                return 1;
            }
        }
    }
}
