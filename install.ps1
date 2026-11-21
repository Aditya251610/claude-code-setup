<#
.SYNOPSIS
  claude-code-setup installer for Windows (PowerShell 5.1 and 7). The same setup as install.sh.

.DESCRIPTION
  irm https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.ps1 | iex
  With options:
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.ps1))) -Lang python,rust -Style terse

  Safe to re-run. Backs up anything it replaces. Needs no admin rights. Skills are copied, not symlinked
  (symlinks on Windows need Developer Mode or admin rights), so re-run the installer to update them.

.PARAMETER DryRun       Show what would change, change nothing.
.PARAMETER NoModelPin   Do not set the default model and effort in settings.json.
.PARAMETER NoMods       Skip the mods (plugins).
.PARAMETER Lang         Language guardrails and playbooks: python,rust,go,cpp,ts
.PARAMETER Style        Output style to install and select: terse
.PARAMETER Lsp          Language-server plugins: python,rust,cpp,go,ts
.PARAMETER Version      A tagged release (for example v0.2.1) instead of the latest main.
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$NoModelPin,
  [switch]$NoMods,
  [string]$Lang = "",
  [string]$Style = "",
  [string]$Lsp = "",
  [string]$Version = ""
)
$ErrorActionPreference = 'Stop'

$RepoUrl = if ($env:CCS_REPO) { $env:CCS_REPO } else { 'https://github.com/Aditya251610/claude-code-setup' }
$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HomeDir '.claude' }
$Dest = if ($env:CCS_HOME) { $env:CCS_HOME } elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'claude-code-setup' } else { Join-Path $HomeDir '.local/share/claude-code-setup' }
$Manifest = Join-Path $ClaudeDir '.claude-code-setup.manifest'
$Begin = '<!-- claude-code-setup:begin -->'
$End = '<!-- claude-code-setup:end -->'
$Mark = 'managed by claude-code-setup'
$Marker = '.ccs-managed'
$Pin = -not $NoModelPin
if (-not $Version) { $Version = if ($env:CCS_VERSION) { $env:CCS_VERSION } else { 'main' } }
$NewEntries = New-Object System.Collections.ArrayList

function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "!!  $m" -ForegroundColor Yellow }
function Die($m)  { throw $m }
function Act($desc, [scriptblock]$do) { if ($DryRun) { Write-Host "    [dry-run] $desc" } else { & $do } }
function Utf8NoBom { New-Object System.Text.UTF8Encoding $false }
function Write-Text($p, $text) { [System.IO.File]::WriteAllText($p, $text, (Utf8NoBom)) }
function Read-Text($p) { if (Test-Path -LiteralPath $p) { [System.IO.File]::ReadAllText($p) } else { '' } }
function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# Manifest lines are "kind<TAB>path<TAB>extra", the same format install.sh writes.
function Record($kind, $path, $extra = '') { if (-not $DryRun) { [void]$NewEntries.Add("$kind`t$path`t$extra") } }
function Merge-Manifest {
  if ($DryRun -or $NewEntries.Count -eq 0) { return }
  $old = @(); if (Test-Path -LiteralPath $Manifest) { $old = @(Get-Content -LiteralPath $Manifest) }
  $seen = @{}; $out = New-Object System.Collections.ArrayList
  foreach ($l in (@($old) + @($NewEntries))) {
    if (-not $l) { continue }
    $f = $l -split "`t"
    $key = if ($f.Count -ge 2) { $f[0] + "`t" + $f[1] } else { $l }
    if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; [void]$out.Add($l) }
  }
  Write-Text $Manifest (($out -join "`n") + "`n")
}

function Read-Json($p) {
  $raw = Read-Text $p
  if ($raw.Trim()) { return ($raw | ConvertFrom-Json) }
  return (New-Object psobject)
}
function Has-Prop($o, $n) { ($null -ne $o) -and ($o.PSObject.Properties.Name -contains $n) }
function Set-Prop($o, $n, $v) { Add-Member -InputObject $o -NotePropertyName $n -NotePropertyValue $v -Force }
function Write-Json($p, $o) { Write-Text $p ($o | ConvertTo-Json -Depth 32) }

$script:BackupDir = Join-Path $ClaudeDir ('backups/claude-code-setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
function Backup($p) {
  if (-not (Test-Path -LiteralPath $p)) { return }
  $rel = $p.Substring($ClaudeDir.Length).TrimStart('\', '/')
  $to = Join-Path $script:BackupDir $rel
  Act "back up $p" { New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null; Copy-Item -Recurse -Force -LiteralPath $p -Destination $to }
}

# A skill is a folder: copy it and drop a marker so uninstall only ever removes our own copies.
function Install-SkillDir($from, $to, $label) {
  if ((Test-Path -LiteralPath $to) -and -not (Test-Path -LiteralPath (Join-Path $to $Marker))) {
    Warn "skill '$label' already exists and is not ours; left alone"; return
  }
  Act "copy skill $label" {
    if (Test-Path -LiteralPath $to) { Remove-Item -Recurse -Force -LiteralPath $to }
    New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
    Copy-Item -Recurse -Force -LiteralPath $from -Destination $to
    Write-Text (Join-Path $to $Marker) "$Mark`n"
  }
  Write-Host "    copy    skill $label"
  Record 'dir' $to
}
function Install-File($from, $to, $label) {
  if ((Test-Path -LiteralPath $to) -and -not ((Read-Text $to) -match [regex]::Escape($Mark))) {
    Warn "'$label' already exists and is not ours; left alone"; return $false
  }
  if ((Test-Path -LiteralPath $to) -and ((Read-Text $to) -eq (Read-Text $from))) { Write-Host "    ok      $label" }
  else { Backup $to; Act "copy $label" { New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null; Copy-Item -Force -LiteralPath $from -Destination $to }; Write-Host "    copy    $label" }
  Record 'file' $to
  return $true
}

try {
  if ($env:OS -ne 'Windows_NT') { Write-Host "(not Windows: running in test mode on $([System.Environment]::OSVersion.Platform))" }
  Say "System: $(if ($env:OS -eq 'Windows_NT') { 'windows' } else { 'non-windows (test)' }), PowerShell $($PSVersionTable.PSVersion)"

  # -- Source: this checkout, or download a copy --
  $Here = $PSScriptRoot
  if ($Here -and (Test-Path -LiteralPath (Join-Path $Here '.ccs-root'))) { $Src = $Here }
  else {
    $Src = $Dest
    $ref = if ($Version -eq 'main' -or $Version -eq 'master') { "heads/$Version" } else { "tags/$Version" }
    $url = if ($env:CCS_ZIP) { $env:CCS_ZIP } else { ($RepoUrl.TrimEnd('/') -replace '\.git$', '') + "/archive/refs/$ref.zip" }
    Say "Downloading claude-code-setup ($Version) to $Dest"
    if ($DryRun) { Write-Host "    [dry-run] download $url and unpack it into $Dest"; Write-Host "(dry run: nothing downloaded, so the file list below is not shown)"; return }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('ccs.' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      $zip = Join-Path $tmp 'src.zip'
      if ($url -match '^file://') { Copy-Item -LiteralPath ([Uri]$url).LocalPath -Destination $zip }
      elseif (Test-Path -LiteralPath $url) { Copy-Item -LiteralPath $url -Destination $zip }
      else { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip }
      Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'x') -Force
      $top = @(Get-ChildItem -LiteralPath (Join-Path $tmp 'x') -Directory)
      if ($top.Count -ne 1 -or -not (Test-Path -LiteralPath (Join-Path $top[0].FullName '.ccs-root'))) { Die "the download is not a claude-code-setup release" }
      New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
      $old = "$Dest.old.$PID"
      if (Test-Path -LiteralPath $Dest) { Move-Item -LiteralPath $Dest -Destination $old }
      Move-Item -LiteralPath $top[0].FullName -Destination $Dest
      if (Test-Path -LiteralPath $old) { Remove-Item -Recurse -Force -LiteralPath $old }
    } finally { Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $Src '.ccs-root'))) { Die "Not a claude-code-setup checkout: $Src" }
  if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null }

  # -- Skills (copies) --
  Say "Skills -> $(Join-Path $ClaudeDir 'skills')"
  foreach ($d in (Get-ChildItem -LiteralPath (Join-Path $Src 'skills') -Directory)) {
    Install-SkillDir $d.FullName (Join-Path $ClaudeDir "skills/$($d.Name)") $d.Name
  }

  # -- Agents (copies) --
  Say "Agents -> $(Join-Path $ClaudeDir 'agents')"
  foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $Src 'agents') -Filter *.md)) {
    [void](Install-File $f.FullName (Join-Path $ClaudeDir "agents/$($f.Name)") $f.Name)
  }

  # -- Languages (opt-in): rule + playbook skill, kept separate per language --
  if ($Lang) {
    Say "Languages -> rules and skills ($Lang)"
    $hints = @{
      python     = @(@('python', 'winget install Python.Python.3.13'), @('ruff', 'uv tool install ruff   (or: pip install --user ruff)'), @('pytest', 'uv tool install pytest   (or: pip install --user pytest)'))
      rust       = @(,@('cargo', 'winget install Rustlang.Rustup   then: rustup component add clippy rustfmt rust-analyzer'))
      go         = @(,@('go', 'winget install GoLang.Go'))
      cpp        = @(@('clang++', 'winget install LLVM.LLVM   (or Visual Studio Build Tools)'), @('cmake', 'winget install Kitware.CMake'))
      typescript = @(@('node', 'winget install OpenJS.NodeJS'), @('tsc', 'npm i -g typescript'))
    }
    foreach ($l0 in ($Lang -split ',')) {
      $l = $l0.Trim()
      if ($l -eq 'ts') { $l = 'typescript' } elseif ($l -eq 'c' -or $l -eq 'c++') { $l = 'cpp' }
      if (@('python', 'rust', 'go', 'cpp', 'typescript') -notcontains $l) { Warn "unknown language '$l' (use python, rust, go, cpp, ts)"; continue }
      [void](Install-File (Join-Path $Src "langs/$l/rule.md") (Join-Path $ClaudeDir "rules/$l.md") "rule  $l")
      Install-SkillDir (Join-Path $Src "langs/$l/skill") (Join-Path $ClaudeDir "skills/$l-best-practices") "$l-best-practices"
      foreach ($h in $hints[$l]) { if (-not (Have $h[0])) { Write-Host "    missing: $($h[0])  ($($h[1]))" } }
    }
  }

  # -- CLAUDE.md: a managed block, the rest is untouched --
  Say "Instructions -> $(Join-Path $ClaudeDir 'CLAUDE.md') (managed block)"
  $cm = Join-Path $ClaudeDir 'CLAUDE.md'
  if ($DryRun) { Write-Host "    [dry-run] insert/replace the block between $Begin and $End" }
  else {
    Backup $cm
    $cur = Read-Text $cm
    $rx = '(?s)' + [regex]::Escape($Begin) + '.*?' + [regex]::Escape($End) + '\r?\n?'
    $cur = [regex]::Replace($cur, $rx, '').TrimEnd()
    $block = "$Begin`n" + (Read-Text (Join-Path $Src 'CLAUDE.md')).TrimEnd() + "`n$End`n"
    Write-Text $cm ($(if ($cur) { "$cur`n`n" } else { '' }) + $block)
    Record 'block' $cm
  }

  # -- settings.json: merged, never replaced --
  Say "Settings -> $(Join-Path $ClaudeDir 'settings.json') (merge)"
  $sj = Join-Path $ClaudeDir 'settings.json'
  if ($DryRun) { Write-Host "    [dry-run] merge settings/settings.base.json (model pin: $(if ($Pin) { 'yes' } else { 'no' }))" }
  else {
    if ((Test-Path -LiteralPath $sj) -and -not (Read-Text $sj).Trim()) { Remove-Item -LiteralPath $sj }
    try { $s = Read-Json $sj } catch { Die "$sj is not valid JSON; fix it and re-run (nothing was changed in it)." }
    $b = Read-Json (Join-Path $Src 'settings/settings.base.json')
    Backup $sj
    # Remember what you had before, so uninstall never deletes your own choice (the first run decides).
    $had = $null
    if (Test-Path -LiteralPath $Manifest) {
      foreach ($l in (Get-Content -LiteralPath $Manifest)) { $f = $l -split "`t"; if ($f[0] -eq 'settings' -and $f[1] -eq $sj) { $had = $f[2] -replace '^pin=\d+\s*', ''; break } }
    }
    if ($null -eq $had) { $had = "had_model=$(if (Has-Prop $s 'model') { 1 } else { 0 }) had_effort=$(if (Has-Prop $s 'effortLevel') { 1 } else { 0 })" }
    if ($Pin) { Set-Prop $s 'model' $b.model; Set-Prop $s 'effortLevel' $b.effortLevel }
    $envObj = if (Has-Prop $s 'env') { $s.env } else { New-Object psobject }
    foreach ($p in $b.env.PSObject.Properties) { if (-not (Has-Prop $envObj $p.Name)) { Set-Prop $envObj $p.Name $p.Value } }
    Set-Prop $s 'env' $envObj
    $perm = if (Has-Prop $s 'permissions') { $s.permissions } else { New-Object psobject }
    $deny = @(); if (Has-Prop $perm 'deny') { $deny = @($perm.deny) }
    foreach ($d in $b.permissions.deny) { if ($deny -notcontains $d) { $deny += $d } }
    Set-Prop $perm 'deny' ([object[]]$deny)
    Set-Prop $s 'permissions' $perm
    Write-Json $sj $s
    Record 'settings' $sj ("pin=$(if ($Pin) { 1 } else { 0 }) $had")
  }

  # -- Output style (opt-in) --
  if ($Style) {
    if ($Style -ne 'terse') { Warn "unknown style '$Style' (available: terse)" }
    else {
      Say "Output style -> $(Join-Path $ClaudeDir 'output-styles/terse.md')"
      $ok = Install-File (Join-Path $Src 'output-styles/terse.md') (Join-Path $ClaudeDir 'output-styles/terse.md') 'terse.md'
      if ($ok) {
        if ($DryRun) { Write-Host "    [dry-run] select it as the default (outputStyle) unless you already chose one" }
        else {
          $s = Read-Json $sj
          if (-not (Has-Prop $s 'outputStyle')) { Set-Prop $s 'outputStyle' 'Terse'; Write-Json $sj $s; Record 'outputstyle' $sj; Write-Host "    selected as your default style (change it any time with /output-style)" }
          else { Write-Host "    you already have an output style set; left it. Switch with /output-style" }
        }
      }
    }
  }

  # -- Mods (plugins) --
  $mp = Join-Path $Src '.claude-plugin/marketplace.json'
  if (-not $NoMods -and (Test-Path -LiteralPath $mp)) {
    Say "Mods"
    if (Have 'claude') {
      Act "claude plugin marketplace add $Src" { & claude plugin marketplace add $Src 2>&1 | Out-Host }
      foreach ($p in (Read-Json $mp).plugins) {
        Act "claude plugin install $($p.name)@claude-code-setup" {
          & claude plugin install "$($p.name)@claude-code-setup" --scope user 2>&1 | Out-Host
          if ($LASTEXITCODE -eq 0) { Record 'plugin' "$($p.name)@claude-code-setup" } else { Warn "could not install mod $($p.name)" }
        }
      }
      Act "claude plugin uninstall token-weather@claude-code-setup (only if installed)" { & claude plugin uninstall 'token-weather@claude-code-setup' --scope user *> $null }
    } else { Warn "'claude' not found on PATH; skipped mods. Re-run after installing Claude Code." }
  }

  # -- Language servers (opt-in) --
  if ($Lsp) {
    Say "Language servers: $Lsp"
    $servers = @{
      python = @('pyright-lsp', 'npm i -g pyright'); rust = @('rust-analyzer-lsp', 'rustup component add rust-analyzer')
      cpp = @('clangd-lsp', 'winget install LLVM.LLVM'); go = @('gopls-lsp', 'go install golang.org/x/tools/gopls@latest')
      ts = @('typescript-lsp', 'npm i -g typescript typescript-language-server')
    }
    foreach ($l0 in ($Lsp -split ',')) {
      $l = $l0.Trim()
      if (-not $servers.ContainsKey($l)) { Warn "unknown language '$l'"; continue }
      if (Have 'claude') {
        Act "claude plugin install $($servers[$l][0])@claude-plugins-official" {
          & claude plugin install "$($servers[$l][0])@claude-plugins-official" --scope user 2>&1 | Out-Host
          if ($LASTEXITCODE -eq 0) { Record 'plugin' "$($servers[$l][0])@claude-plugins-official" } else { Warn "could not install $($servers[$l][0])" }
        }
      }
      Write-Host "    server for $l (run yourself): $($servers[$l][1])"
    }
  }

  Say ("Done." + $(if ($DryRun) { ' (dry run, nothing was changed)' } else { '' }) + " Backups, if any: $script:BackupDir")
  Say "Restart Claude Code, then check '/plugin' and '/agents'. Remove everything with: & '$(Join-Path $Dest 'uninstall.ps1')'"
}
finally { Merge-Manifest }
