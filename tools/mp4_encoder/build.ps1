# Builds game/encoder/Mp4Encoder.exe from Mp4Encoder.cs with the C# compiler that comes
# with .NET Framework (on every Windows 10/11 PC: nothing to install). Run it after
# changing the .cs file and commit the .exe (the playtest build runs on Linux, where
# this can't be built).
#
#   powershell -ExecutionPolicy Bypass -File tools/mp4_encoder/build.ps1

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$out = Join-Path $root "game\encoder\Mp4Encoder.exe"
New-Item -ItemType Directory -Force (Split-Path -Parent $out) | Out-Null
& $csc /nologo /optimize+ /platform:x64 /target:exe "/out:$out" (Join-Path $here "Mp4Encoder.cs")
if ($LASTEXITCODE -ne 0) { throw "csc failed" }
Get-Item $out | Select-Object Name, Length
