<#
wander installer (Windows x64, experimental) — downloads the prebuilt binary
from GitHub Release, installs to ~\.local\bin, adds it to your user PATH,
and wires the Claude Code statusline. One binary does both the CLI and
`wander statusline`.

Usage (PowerShell):
  irm https://raw.githubusercontent.com/wander-dao/wander/main/install.ps1 | iex

  # with parameters (iex needs the scriptblock form):
  iex "& { $(irm https://raw.githubusercontent.com/wander-dao/wander/main/install.ps1) } -Version v0.1.0"
  iex "& { $(irm https://raw.githubusercontent.com/wander-dao/wander/main/install.ps1) } -NoStatusline"
  iex "& { $(irm https://raw.githubusercontent.com/wander-dao/wander/main/install.ps1) } -Uninstall"
  iex "& { $(irm https://raw.githubusercontent.com/wander-dao/wander/main/install.ps1) } -Uninstall -CleanStatusline"

  # offline / air-gapped: point at a downloaded release zip
  .\install.ps1 -ZipPath "$HOME\Downloads\wander-x86_64-pc-windows-msvc.zip"

Data layout matches macOS (XDG-style under your home):
  ~\.local\bin\wander.exe        binary
  ~\.local\share\wander\         permanent archive (kept on uninstall)
  ~\.cache\wander\               derived cache (removed on uninstall)
  ~\.config\wander\              settings   (kept on uninstall; -Purge removes)
#>
param(
  [string]$Version = 'latest',
  [switch]$NoStatusline,
  [switch]$Uninstall,
  [switch]$CleanStatusline,
  [switch]$Purge,
  [string]$ZipPath = ''
)

$ErrorActionPreference = 'Stop'
$Repo    = 'wander-dao/wander'
$BinDir  = Join-Path $HOME '.local\bin'
$Exe     = Join-Path $BinDir 'wander.exe'
$Settings = Join-Path $HOME '.claude\settings.json'
# Claude Code executes statusLine through Git Bash even on Windows, where
# backslashes in the command are eaten as escape characters (C:\Users -> C:Users,
# fails silently). Windows APIs accept forward slashes, so wire those instead.
$StatuslineCmd = "$($Exe -replace '\\', '/') statusline"

# Matches both the current forward-slash form and the backslash form older
# installers wrote, so cleanup / rewire recognises its own entry either way.
function Is-WanderStatusline($cmd) {
  ($null -ne $cmd) -and (($cmd -replace '\\', '/') -eq $StatuslineCmd)
}

function Say-Cyan($m)  { Write-Host $m -ForegroundColor Cyan }
function Say-Green($m) { Write-Host $m -ForegroundColor Green }
function Say-Red($m)   { Write-Host $m -ForegroundColor Red }
function Say-Gray($m)  { Write-Host $m -ForegroundColor DarkGray }
function Die($m) { Say-Red "x $m"; exit 1 }

# Stream-copy download with a single clean console progress bar. Avoids both
# Invoke-WebRequest's PS 5.1 progress slowdown and redirect-hop bar flicker;
# the bar only draws once the sized response body is flowing.
function Download-WithBar([string]$Url, [string]$Out) {
  $req = [Net.HttpWebRequest]::Create($Url)
  $req.AllowAutoRedirect = $true
  $req.UserAgent = 'wander-install'
  $resp = $req.GetResponse()
  try {
    $total = $resp.ContentLength
    $in = $resp.GetResponseStream()
    $fs = [IO.File]::Create($Out)
    try {
      $buf = New-Object byte[] 65536
      $done = 0; $width = 40; $lastPct = -1
      while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
        $fs.Write($buf, 0, $n); $done += $n
        if ($total -gt 0) {
          $pct = [int][math]::Floor(100 * $done / $total)
          if ($pct -ne $lastPct) {
            $lastPct = $pct
            $filled = [int]($pct * $width / 100)
            $bar = ('#' * $filled).PadRight($width)
            Write-Host -NoNewline ("`r  $bar {0,3}%" -f $pct)
          }
        }
      }
      if ($total -gt 0) { Write-Host "" }
    } finally { $fs.Dispose(); $in.Dispose() }
  } finally { $resp.Dispose() }
}

function Read-SettingsObject {
  if (-not (Test-Path $Settings)) { return $null }
  $raw = [IO.File]::ReadAllText($Settings)
  if ($raw.Trim() -eq '') { return [pscustomobject]@{} }
  try { return ($raw | ConvertFrom-Json) }
  catch { Die "$Settings is not valid JSON - refusing to touch. Fix it first, then re-run." }
}

function Write-SettingsObject($obj) {
  $dir = Split-Path $Settings -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (Test-Path $Settings) {
    $backup = "$Settings.bak.$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    Copy-Item $Settings $backup -Force
    Say-Gray "  backup: $backup"
  }
  $json = $obj | ConvertTo-Json -Depth 100
  # WriteAllText = UTF-8 without BOM (a BOM breaks JSON.parse in Claude Code)
  [IO.File]::WriteAllText($Settings, $json)
}

# ============================== uninstall ==============================
if ($Uninstall) {
  foreach ($f in @($Exe, (Join-Path $BinDir 'wander.old.exe'))) {
    if (Test-Path $f) { Remove-Item $f -Force; Say-Green "removed $f" }
    else { Say-Gray "not present: $f" }
  }
  $cache = Join-Path $HOME '.cache\wander'
  if (Test-Path $cache) { Remove-Item $cache -Recurse -Force; Say-Green "removed $cache" }

  if ($Purge) {
    foreach ($d in @((Join-Path $HOME '.local\share\wander'), (Join-Path $HOME '.config\wander'))) {
      if (Test-Path $d) { Remove-Item $d -Recurse -Force; Say-Red "purged $d" }
    }
  } else {
    Say-Gray "(archive + config preserved - pass -Purge to wipe them)"
  }

  if ($CleanStatusline) {
    $obj = Read-SettingsObject
    if ($null -eq $obj) { Say-Gray "no $Settings - nothing to clean" }
    elseif (-not $obj.PSObject.Properties['statusLine']) { Say-Gray "settings.json has no statusLine - already clean" }
    elseif (-not (Is-WanderStatusline $obj.statusLine.command)) {
      Say-Red "statusLine is not wander's:"; Say-Red "  $($obj.statusLine.command)"; Say-Gray "leaving it untouched."
    } else {
      $obj.PSObject.Properties.Remove('statusLine')
      Write-SettingsObject $obj
      Say-Green "removed statusLine from $Settings"
    }
  } else {
    Say-Gray "(settings.json untouched - pass -CleanStatusline to remove the statusLine entry)"
  }

  Say-Cyan "Done. wander removed."
  exit 0
}

# ============================== install ==============================
$arch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
if ($arch -ne 'AMD64') {
  Die "Windows x64 only (detected: $arch). ARM64 has no build (deno compile has no windows-arm64 target)."
}

$tmp = Join-Path $env:TEMP ("wander-install-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  $zip = Join-Path $tmp 'wander.zip'
  if ($ZipPath) {
    if (-not (Test-Path $ZipPath)) { Die "zip not found: $ZipPath" }
    Copy-Item $ZipPath $zip
    Say-Cyan "> using local zip: $ZipPath"
  } else {
    if ($Version -ne 'latest' -and $Version -notmatch '^v') { $Version = "v$Version" }
    $asset = 'wander-x86_64-pc-windows-msvc.zip'
    if ($Version -eq 'latest') { $url = "https://github.com/$Repo/releases/latest/download/$asset" }
    else                       { $url = "https://github.com/$Repo/releases/download/$Version/$asset" }
    Say-Cyan "> downloading wander ($Version)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Download-WithBar $url $zip

    # verify against the release checksum list before touching anything (same
    # gate `wander upgrade` applies). -ZipPath skips this: offline installs
    # have no trusted SHA256SUMS.txt to compare against.
    if ($Version -eq 'latest') { $sumsUrl = "https://github.com/$Repo/releases/latest/download/SHA256SUMS.txt" }
    else                       { $sumsUrl = "https://github.com/$Repo/releases/download/$Version/SHA256SUMS.txt" }
    $sums = Join-Path $tmp 'SHA256SUMS.txt'
    $pp = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
    try { Invoke-WebRequest -UseBasicParsing -Uri $sumsUrl -OutFile $sums }
    finally { $ProgressPreference = $pp }
    $expected = $null
    foreach ($line in Get-Content $sums) {
      $parts = ($line.Trim()) -split '\s+'
      if ($parts.Length -ge 2 -and $parts[1] -eq $asset) { $expected = $parts[0].ToLowerInvariant(); break }
    }
    if (-not $expected) { Die "$asset missing from SHA256SUMS.txt" }
    $actual = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { Die "checksum mismatch for $asset (expected $expected, got $actual)" }
    Say-Green "checksum verified"
  }

  Unblock-File $zip -ErrorAction SilentlyContinue
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $src = Join-Path $tmp 'wander.exe'
  if (-not (Test-Path $src)) { Die "wander.exe not found inside the zip" }

  New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
  Copy-Item $src $Exe -Force
  Unblock-File $Exe -ErrorAction SilentlyContinue
  Say-Green "installed $Exe"
} finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# --- user PATH ---
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($null -eq $userPath) { $userPath = '' }
$onPath = ($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }).Count -gt 0
if (-not $onPath) {
  $newPath = if ($userPath.Trim() -eq '') { $BinDir } else { $userPath.TrimEnd(';') + ';' + $BinDir }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  Say-Green "added to user PATH: $BinDir"
  Say-Gray  "  (new terminals pick it up; this session is patched below)"
}
if (($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }).Count -eq 0) {
  $env:Path = $env:Path.TrimEnd(';') + ';' + $BinDir
}

# --- wire Claude Code statusline ---
if (-not $NoStatusline) {
  Say-Cyan "> wiring Claude Code statusline..."
  $obj = Read-SettingsObject
  if ($null -eq $obj) { $obj = [pscustomobject]@{} ; Say-Gray "created $Settings" }
  $existing = $null
  if ($obj.PSObject.Properties['statusLine']) { $existing = $obj.statusLine.command }
  if ($existing -eq $StatuslineCmd) {
    Say-Gray "settings.json already wired to wander statusline (no change)"
  } else {
    $go = $true
    if ($existing -and (Is-WanderStatusline $existing)) {
      # our own entry in the old backslash form — normalise silently
      Say-Gray "rewriting statusLine path with forward slashes (Git Bash compat)"
    } elseif ($existing) {
      Say-Red "settings.json already has a statusLine.command:"
      Say-Red "  $existing"
      $ans = Read-Host "Overwrite with 'wander.exe statusline'? [y/N]"
      if ($ans -notin @('y', 'Y')) { Say-Gray "skipped settings.json patch"; $go = $false }
    }
    if ($go) {
      $sl = [pscustomobject]@{ type = 'command'; command = $StatuslineCmd }
      if ($obj.PSObject.Properties['statusLine']) { $obj.statusLine = $sl }
      else { $obj | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl }
      Write-SettingsObject $obj
      Say-Green "patched $Settings"
    }
  }
}

Say-Green "Done."
if (-not $NoStatusline) { Write-Host "  Open Claude Code - your status bar now shows your practice." }
Write-Host "  Try:"
Write-Host "     wander stats          # panorama"
Write-Host "     wander bag            # cultivation / qi / stones"
Write-Host "     wander --help         # all subcommands"
