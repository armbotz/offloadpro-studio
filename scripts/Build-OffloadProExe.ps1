<#
.SYNOPSIS
    Compiles a native, auditable Windows Desktop executable (OffloadProStudio.exe)
    using the built-in .NET C# compiler (Zero external SDKs, Zero Node.js).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot 'OffloadProStudio.exe'
}

$csSource = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

[assembly: AssemblyTitle("OffloadPro DIT Studio v4.4.0")]
[assembly: AssemblyDescription("Native Windows Media Offload & ASC-MHL v2 Archival Studio")]
[assembly: AssemblyCompany("OffloadPro Open-Source Community")]
[assembly: AssemblyProduct("OffloadPro DIT Studio")]
[assembly: AssemblyVersion("4.4.0.0")]
[assembly: AssemblyFileVersion("4.4.0.0")]

namespace OffloadProStudio
{
    public static class Program
    {
        [STAThread]
        public static int Main(string[] args)
        {
            string exeDir = AppDomain.CurrentDomain.BaseDirectory;
            string psd1Path = Path.Combine(exeDir, "modules", "OffloadPro", "OffloadPro.psd1");
            if (!File.Exists(psd1Path))
            {
                return 1;
            }

            string escapedModule = psd1Path.Replace("'", "''");
            string psCommand = "Import-Module '" + escapedModule + "' -Force; Start-OffloadProApp -InProcessModal";

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Sta -Command \"" + psCommand + "\"";
            psi.UseShellExecute = true;
            psi.WindowStyle = ProcessWindowStyle.Normal;
            psi.WorkingDirectory = exeDir;

            using (Process p = Process.Start(psi))
            {
                return 0;
            }
        }
    }
}
'@

Add-Type -TypeDefinition $csSource -OutputAssembly $OutputPath -OutputType WindowsApplication -ReferencedAssemblies 'System.dll'
Write-Host "[BUILD COMPLETE] Compiled native Windows desktop app: $OutputPath" -ForegroundColor Green
return [PSCustomObject]@{
    ExecutablePath = $OutputPath
    Exists         = (Test-Path -LiteralPath $OutputPath)
}
