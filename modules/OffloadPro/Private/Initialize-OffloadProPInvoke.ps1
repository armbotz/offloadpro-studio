function Initialize-OffloadProPInvoke {
    try {
        if (-not ([System.Management.Automation.PSTypeName]'OffloadPro.PowerGuard').Type) {
            Add-Type -Namespace 'OffloadPro' -Name 'PowerGuard' -MemberDefinition @'
                [System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto, SetLastError = true)]
                public static extern uint SetThreadExecutionState(uint esFlags);
'@ -ErrorAction SilentlyContinue
        }
        if (-not ([System.Management.Automation.PSTypeName]'OffloadPro.DiskControl').Type) {
            Add-Type -Namespace 'OffloadPro' -Name 'DiskControl' -MemberDefinition @'
                [System.Runtime.InteropServices.DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
                public static extern bool DeviceIoControl(
                    IntPtr hDevice,
                    uint dwIoControlCode,
                    IntPtr lpInBuffer,
                    uint nInBufferSize,
                    IntPtr lpOutBuffer,
                    uint nOutBufferSize,
                    out uint lpBytesReturned,
                    IntPtr lpOverlapped);
'@ -ErrorAction SilentlyContinue
        }
    } catch {}
}
