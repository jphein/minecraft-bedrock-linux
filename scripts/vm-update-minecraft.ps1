# vm-update-minecraft.ps1
# Run this INSIDE the Windows 11 VM (driven by game-update.sh over one SSH hop).
#
# Triggers a headless Microsoft Store update for Minecraft Bedrock (UWP/Store
# app — not winget-managed), waits for the new version to land, then launches
# the game once (extraction requires the updated package has run at least once)
# and closes it to release file locks before the host extracts the build.
#
# This is the recon-proven recipe from the 2026-06-20 26.21->26.31 update:
#   - MDM UpdateScanMethod over root\cimv2\mdm\dmmap pulled the update headless
#     (no SPICE GUI needed); the bump landed ~8 min after the scan.
#   - Headless launch via the AppsFolder AUMID worked over SSH (process came up);
#     Stop-Process released the locks before robocopy/decrypt extraction.
#
# Contract (design doc section 3): prints machine-readable RESULT lines to stdout:
#   RESULT new_version=<v>
#   RESULT install_location=<path>
# or, if the version never changed within the timeout:
#   RESULT no_update=true
# Over Win32-OpenSSH (powershell -File ... via ssh), Write-Host is NOT a separate
# channel — it merges into the same stdout stream the caller captures. So to keep
# RESULT parsing clean we route all human progress to stderr ([Console]::Error,
# the caller splits stderr off) and emit ONLY the RESULT lines on stdout (design
# doc section 47). Never start a stdout line with the token 'RESULT ' unless it is
# a real machine result.
#
# Usage (driven over SSH):
#   powershell -ExecutionPolicy Bypass -File vm-update-minecraft.ps1
#   powershell -ExecutionPolicy Bypass -File vm-update-minecraft.ps1 `
#       -PackageFamily "Microsoft.MinecraftUWP_8wekyb3d8bbwe" `
#       -Aumid "Microsoft.MinecraftUWP_8wekyb3d8bbwe!Game"

param(
    [string]$PackageFamily = "Microsoft.MinecraftUWP_8wekyb3d8bbwe",
    [string]$Aumid = "Microsoft.MinecraftUWP_8wekyb3d8bbwe!Game"
)

$ErrorActionPreference = "Stop"

# Poll cadence (design doc: every 30s, up to ~15 min).
$PollIntervalSec = 30
$MaxWaitMin = 15
$MaxPolls = [int][math]::Ceiling(($MaxWaitMin * 60) / $PollIntervalSec)

# The AppxPackage *name* is the family minus the publisher hash suffix
# (e.g. "Microsoft.MinecraftUWP_8wekyb3d8bbwe" -> "Microsoft.MinecraftUWP").
# Keeps the package lookup parametrized off -PackageFamily.
$PackageName = $PackageFamily.Split("_")[0]

function Get-McPackage {
    # Returns the installed Minecraft Appx package object, or $null if absent.
    # During a UWP update two versions can be briefly registered; sort descending
    # so the highest (newest) registered version is chosen deterministically
    # rather than relying on unsorted enumeration order (design doc safety note).
    return Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1
}

[Console]::Error.WriteLine("=== Minecraft Bedrock VM Update ===")
[Console]::Error.WriteLine("Package family : $PackageFamily")
[Console]::Error.WriteLine("AUMID          : $Aumid")
[Console]::Error.WriteLine("Package name   : $PackageName")
[Console]::Error.WriteLine("")

# --- Step 1: capture current version --------------------------------------
[Console]::Error.WriteLine("[1/4] Reading current installed version...")
$pkg = Get-McPackage
if (-not $pkg) {
    [Console]::Error.WriteLine("ERROR: $PackageName is not installed in this VM.")
    [Console]::Error.WriteLine("Install Minecraft Bedrock from the Xbox/Store app and launch it once.")
    exit 1
}
$oldVersion = [string]$pkg.Version
[Console]::Error.WriteLine("  Current version: $oldVersion")

# --- Step 2: trigger the Store update scan (headless MDM) -----------------
[Console]::Error.WriteLine("[2/4] Triggering Microsoft Store update scan (MDM UpdateScanMethod)...")
try {
    $scan = Get-CimInstance `
        -Namespace "root\cimv2\mdm\dmmap" `
        -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" |
        Invoke-CimMethod -MethodName "UpdateScanMethod"
    if ($null -ne $scan -and $null -ne $scan.ReturnValue) {
        [Console]::Error.WriteLine("  UpdateScanMethod ReturnValue: $($scan.ReturnValue)")
    } else {
        [Console]::Error.WriteLine("  UpdateScanMethod invoked.")
    }
} catch {
    [Console]::Error.WriteLine("ERROR: UpdateScanMethod failed: $($_.Exception.Message)")
    exit 1
}

# --- Step 3: poll for the version to change -------------------------------
[Console]::Error.WriteLine("[3/4] Polling for version change every ${PollIntervalSec}s (up to ${MaxWaitMin} min)...")
$newVersion = $null
for ($i = 1; $i -le $MaxPolls; $i++) {
    Start-Sleep -Seconds $PollIntervalSec
    $cur = Get-McPackage
    $curVersion = if ($cur) { [string]$cur.Version } else { $oldVersion }
    $elapsed = $i * $PollIntervalSec
    [Console]::Error.WriteLine(("  poll {0}/{1} (+{2}s): version = {3}" -f $i, $MaxPolls, $elapsed, $curVersion))
    if ($curVersion -ne $oldVersion) {
        $newVersion = $curVersion
        [Console]::Error.WriteLine("  Version changed: $oldVersion -> $newVersion")
        break
    }
}

if (-not $newVersion) {
    [Console]::Error.WriteLine("  No version change after ${MaxWaitMin} min.")
    [Console]::Error.WriteLine("  The Store may not have an update available, or it is still downloading.")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("=== No update ===")
    # Machine-readable result for the caller (game-update.sh).
    Write-Output "RESULT no_update=true"
    exit 0
}

# --- Step 4: launch-once to finalize, then close to release file locks ----
# Extraction requires the updated package has run at least once. Launch headless
# via the AppsFolder AUMID (proven over SSH on 2026-06-20), let it settle, then
# Stop-Process so robocopy/decrypt are not blocked by file locks.
[Console]::Error.WriteLine("[4/4] Launch-once to finalize the install, then closing it...")
$procName = "Minecraft.Windows"

# Launch-once is a REQUIRED finalize step here (design doc step 4 / "Fail loud,
# fail safe"): a real update was detected, so the updated package MUST run at
# least once before extraction. explorer.exe shell:AppsFolder returns immediately
# and almost never throws even when the app fails to come up, so "process never
# appeared" is the real failure path — treat it as a HARD failure (retry once,
# then ERROR + exit 1, emitting no RESULT so the caller aborts and keeps game.bak).
function Invoke-LaunchOnce {
    try {
        Start-Process "explorer.exe" -ArgumentList "shell:AppsFolder\$Aumid"
        [Console]::Error.WriteLine("  Launched via shell:AppsFolder\$Aumid; waiting 40s for it to settle...")
    } catch {
        [Console]::Error.WriteLine("  WARNING: launch via AUMID failed: $($_.Exception.Message)")
    }
    Start-Sleep -Seconds 40
    return (Get-Process -Name $procName -ErrorAction SilentlyContinue)
}

$proc = Invoke-LaunchOnce
if (-not $proc) {
    [Console]::Error.WriteLine("  WARNING: $procName process not found after launch; retrying launch-once once...")
    $proc = Invoke-LaunchOnce
}

if ($proc) {
    $ws = [math]::Round((($proc | Measure-Object -Property WorkingSet64 -Sum).Sum) / 1MB, 0)
    [Console]::Error.WriteLine("  $procName is running (WS ~${ws} MB). Stopping to release file locks...")
    Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    [Console]::Error.WriteLine("  $procName stopped.")
} else {
    [Console]::Error.WriteLine("ERROR: $procName never came up after launch-once (incl. retry).")
    [Console]::Error.WriteLine("  A real update was detected but the package was not finalized; refusing to")
    [Console]::Error.WriteLine("  report success. Extraction would ship a registered-but-not-finalized build.")
    exit 1
}

# --- Final verification + RESULT emission ---------------------------------
$final = Get-McPackage
if (-not $final) {
    [Console]::Error.WriteLine("ERROR: package not found after update.")
    exit 1
}
$finalVersion = [string]$final.Version
$installLocation = [string]$final.InstallLocation

# Cross-check the final read against the version that tripped the poll. A
# transient dual-registration window could otherwise let the final read report a
# different version than the one already proven during polling (design doc safety
# note re: the 26.x silent-stale-binary mode). Warn loudly before emitting RESULT.
if ($finalVersion -ne $newVersion) {
    [Console]::Error.WriteLine("WARNING: final version ($finalVersion) does not match the version detected during polling ($newVersion).")
    [Console]::Error.WriteLine("  Possible transient dual-registration; the caller's downstream version checks must confirm.")
}

[Console]::Error.WriteLine("")
[Console]::Error.WriteLine("=== Update Complete ===")
[Console]::Error.WriteLine("  Old version     : $oldVersion")
[Console]::Error.WriteLine("  New version     : $finalVersion")
[Console]::Error.WriteLine("  Install location: $installLocation")
[Console]::Error.WriteLine("")

# Machine-readable results for the caller (game-update.sh) — keep these last
# and unadorned so RESULT parsing is clean.
Write-Output "RESULT new_version=$finalVersion"
Write-Output "RESULT install_location=$installLocation"
exit 0
