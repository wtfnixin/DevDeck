using System;
using System.Runtime.InteropServices;

class Program {
    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    const uint KEYEVENTF_KEYUP = 0x0002;

    static void Main(string[] args) {
        byte vk;
        if (args.Length > 0 && byte.TryParse(args[0], out vk)) {
            // For Windows volume and multimedia keys (VK_VOLUME_MUTE, VK_VOLUME_DOWN, VK_VOLUME_UP),
            // KEYEVENTF_EXTENDEDKEY is strictly required by the OS to recognize the keystroke.
            keybd_event(vk, 0, KEYEVENTF_EXTENDEDKEY, UIntPtr.Zero); // Key Down
            keybd_event(vk, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, UIntPtr.Zero); // Key Up
        }
    }
}
