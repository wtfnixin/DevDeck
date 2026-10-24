using System;
using System.Runtime.InteropServices;
using System.Threading;

class DesktopSwitcher {
    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    const uint KEYEVENTF_KEYUP = 0x0002;

    const byte VK_CONTROL = 0x11;
    const byte VK_LWIN = 0x5B;
    const byte VK_LEFT = 0x25;
    const byte VK_RIGHT = 0x27;

    static void Main(string[] args) {
        if (args.Length == 0) return;

        string direction = args[0].Trim().ToLowerInvariant();

        byte arrowKey = (direction == "left" || direction == "prev") ? VK_LEFT : VK_RIGHT;

        // Key Down: Ctrl + Win + Arrow
        keybd_event(VK_CONTROL, 0, 0, UIntPtr.Zero);
        keybd_event(VK_LWIN, 0, 0, UIntPtr.Zero);
        keybd_event(arrowKey, 0, KEYEVENTF_EXTENDEDKEY, UIntPtr.Zero);

        Thread.Sleep(10);

        // Key Up: Arrow + Win + Ctrl
        keybd_event(arrowKey, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
}
