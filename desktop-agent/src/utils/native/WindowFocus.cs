using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Diagnostics;

class WindowFocus {
    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern void SwitchToThisWindow(IntPtr hWnd, bool fUnknown);

    [DllImport("user32.dll")]
    static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    static readonly IntPtr HWND_TOP = IntPtr.Zero;
    const uint SWP_NOMOVE = 0x0002;
    const uint SWP_NOSIZE = 0x0001;
    const int SW_RESTORE = 9;

    static string[] searchTerms;
    static IntPtr foundHwnd = IntPtr.Zero;

    static void Main(string[] args) {
        if (args.Length == 0) Environment.Exit(1);

        searchTerms = new string[args.Length];
        for (int i = 0; i < args.Length; i++) {
            searchTerms[i] = args[i].Trim().ToLower();
        }

        // 1. Check processes with main windows
        foreach (var proc in Process.GetProcesses()) {
            try {
                if (proc.MainWindowHandle != IntPtr.Zero) {
                    string pName = proc.ProcessName.ToLower();
                    string wTitle = "";
                    try { wTitle = proc.MainWindowTitle.ToLower(); } catch { }

                    foreach (var term in searchTerms) {
                        if (term.Length > 0 && (pName.Contains(term) || (wTitle.Length > 0 && wTitle.Contains(term)))) {
                            Activate(proc.MainWindowHandle);
                            Environment.Exit(0);
                        }
                    }
                }
            } catch { }
        }

        // 2. Enumerate top-level windows
        EnumWindows((hWnd, lParam) => {
            // Include visible windows and minimized (iconic) windows
            if (!IsWindowVisible(hWnd) && !IsIconic(hWnd)) return true;

            int len = GetWindowTextLength(hWnd);
            StringBuilder sb = new StringBuilder(len + 1);
            if (len > 0) {
                GetWindowText(hWnd, sb, len + 1);
            }
            string title = sb.ToString().ToLower();

            uint pid = 0;
            GetWindowThreadProcessId(hWnd, out pid);
            string pName = "";
            if (pid != 0) {
                try {
                    pName = Process.GetProcessById((int)pid).ProcessName.ToLower();
                } catch { }
            }

            // Skip non-iconic windows with empty title (e.g. system helper windows)
            if (title.Length == 0 && !IsIconic(hWnd)) return true;

            foreach (var term in searchTerms) {
                if (term.Length > 0) {
                    if ((pName.Length > 0 && (pName.Contains(term) || term.Contains(pName))) ||
                        (title.Length > 0 && (title.Contains(term) || term.Contains(title)))) {
                        foundHwnd = hWnd;
                        return false;
                    }
                }
            }
            return true;
        }, IntPtr.Zero);

        if (foundHwnd != IntPtr.Zero) {
            Activate(foundHwnd);
            Environment.Exit(0);
        }

        Environment.Exit(1);
    }

    static void Activate(IntPtr hWnd) {
        IntPtr foregroundWnd = GetForegroundWindow();

        // 1. Already foreground: 0ms instant no-op
        if (hWnd == foregroundWnd) {
            return;
        }

        // 2. Un-minimize if minimized
        if (IsIconic(hWnd)) {
            ShowWindow(hWnd, SW_RESTORE);
        }

        // 3. Inject harmless dummy input event (VK 0xE8 is unassigned in Windows)
        // This grants the thread foreground activation rights from background sessions without menu flash
        const byte VK_DUMMY = 0xE8;
        keybd_event(VK_DUMMY, 0, 0, UIntPtr.Zero);
        keybd_event(VK_DUMMY, 0, 2 /* KEYEVENTF_KEYUP */, UIntPtr.Zero);

        // 4. Bring window to top and set foreground
        BringWindowToTop(hWnd);
        SetForegroundWindow(hWnd);

        // 5. Switch to target window via Windows shell switcher (works from background/tray)
        SwitchToThisWindow(hWnd, true);

        // 6. Ensure topmost placement in normal Z-order without repaint flicker
        SetWindowPos(hWnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    }
}
