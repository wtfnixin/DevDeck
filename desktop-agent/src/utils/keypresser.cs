using System;
using System.Runtime.InteropServices;

class Program {
    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);

    static void Main(string[] args) {
        byte vk;
        if (args.Length > 0 && byte.TryParse(args[0], out vk)) {
            keybd_event(vk, 0, 0, 0); // Down
            keybd_event(vk, 0, 2, 0); // Up
        }
    }
}
