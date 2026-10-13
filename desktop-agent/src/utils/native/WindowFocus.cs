using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Diagnostics;

class WindowFocus {
    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

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
                    string wTitle = proc.MainWindowTitle.ToLower();

                    foreach (var term in searchTerms) {
                        if (term.Length > 0 && (pName.Contains(term) || wTitle.Contains(term))) {
                            Activate(proc.MainWindowHandle);
                            Environment.Exit(0);
                        }
                    }
                }
            } catch { }
        }

        // 2. Enumerate visible top-level windows
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;

            StringBuilder sb = new StringBuilder(256);
            if (GetWindowText(hWnd, sb, 256) > 0) {
                string title = sb.ToString().ToLower();
                foreach (var term in searchTerms) {
                    if (term.Length > 0 && title.Contains(term)) {
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
        if (IsIconic(hWnd)) {
            ShowWindowAsync(hWnd, 9); // SW_RESTORE
        }
        ShowWindowAsync(hWnd, 5); // SW_SHOW
        BringWindowToTop(hWnd);
        SetForegroundWindow(hWnd);
    }
}
