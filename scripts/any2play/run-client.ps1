# Launch the dev build (build/gui/chiaki.exe) without packaging.
# Puts the MSYS2 UCRT64 runtime and the in-tree cpp-steam-tools DLL on PATH,
# which is what scripts/deploy-windows-msys2.sh would otherwise copy next to
# the exe.

param(
    # MSYS2 install root; defaults to $env:MSYS2_ROOT, then common locations.
    [string]$Msys2Root,
    # Emit upstream's per-frame "[latency]" lines (needs Verbose Logging on in Settings too).
    [switch]$Telemetry,
    [switch]$Wait
)

$client = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$build = Join-Path $client "build"
$exe = Join-Path $build "gui\chiaki.exe"
if (-not (Test-Path $exe)) { throw "not built yet: $exe (run scripts/any2play/build-client-ucrt64.sh)" }

if (-not $Msys2Root) {
    $candidates = @($env:MSYS2_ROOT, "C:\msys64", (Join-Path $env:USERPROFILE "Tools\msys64")) | Where-Object { $_ }
    $Msys2Root = $candidates | Where-Object { Test-Path (Join-Path $_ "ucrt64\bin") } | Select-Object -First 1
    if (-not $Msys2Root) { throw "MSYS2 not found: pass -Msys2Root or set MSYS2_ROOT" }
}

$env:PATH = @(
    (Join-Path $Msys2Root "ucrt64\bin"),
    (Join-Path $build "third-party\cpp-steam-tools"),
    $env:PATH
) -join ";"
if ($Telemetry) { $env:CHIAKI_VERBOSE_LOG_NOISE = "1" }

$p = Start-Process -FilePath $exe -PassThru
if ($Wait) { $p.WaitForExit(); exit $p.ExitCode }
$p
