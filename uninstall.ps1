<#
.SYNOPSIS
  Removes what install.ps1 added: skill copies, agent and rule files, the CLAUDE.md block, our settings
  entries and our plugins. Your other settings and files stay.
.DESCRIPTION
  & "$env:LOCALAPPDATA\claude-code-setup\uninstall.ps1"
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HomeDir '.claude' }
$Manifest = Join-Path $ClaudeDir '.claude-code-setup.manifest'
$Begin = '<!-- claude-code-setup:begin -->'
$End = '<!-- claude-code-setup:end -->'
$Mark = 'managed by claude-code-setup'
$Marker = '.ccs-managed'
$Here = if ($PSScriptRoot) { $PSScriptRoot } elseif ($env:CCS_HOME) { $env:CCS_HOME } elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'claude-code-setup' } else { Join-Path $HomeDir '.local/share/claude-code-setup' }

function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Utf8NoBom { New-Object System.Text.UTF8Encoding $false }
function Write-Text($p, $text) { [System.IO.File]::WriteAllText($p, $text, (Utf8NoBom)) }
function Read-Text($p) { if (Test-Path -LiteralPath $p) { [System.IO.File]::ReadAllText($p) } else { '' } }
function Has-Prop($o, $n) { ($null -ne $o) -and ($o.PSObject.Properties.Name -contains $n) }
function Remove-Prop($o, $n) { if (Has-Prop $o $n) { [void]$o.PSObject.Properties.Remove($n) } }
function Write-Json($p, $o) { Write-Text $p ($o | ConvertTo-Json -Depth 32) }

if (-not (Test-Path -LiteralPath $Manifest)) { Write-Host "Nothing recorded at $Manifest; nothing to remove."; return }

foreach ($line in (Get-Content -LiteralPath $Manifest)) {
  if (-not $line) { continue }
  $f = $line -split "`t"
  $kind = $f[0]; $path = if ($f.Count -ge 2) { $f[1] } else { '' }; $rest = if ($f.Count -ge 3) { $f[2] } else { '' }
  switch ($kind) {
    'dir' {
      if ((Test-Path -LiteralPath (Join-Path $path $Marker))) { Remove-Item -Recurse -Force -LiteralPath $path; Write-Host "    removed $path" }
    }
    'file' {
      if ((Test-Path -LiteralPath $path) -and ((Read-Text $path) -match [regex]::Escape($Mark))) { Remove-Item -Force -LiteralPath $path; Write-Host "    removed $path" }
    }
    'block' {
      if (Test-Path -LiteralPath $path) {
        $rx = '(?s)\r?\n?' + [regex]::Escape($Begin) + '.*?' + [regex]::Escape($End) + '\r?\n?'
        Write-Text $path ([regex]::Replace((Read-Text $path), $rx, "`n"))
        Write-Host "    removed instructions block from $path"
      }
    }
    'settings' {
      $base = Join-Path $Here 'settings/settings.base.json'
      if ((Test-Path -LiteralPath $path) -and (Test-Path -LiteralPath $base)) {
        $s = (Read-Text $path) | ConvertFrom-Json
        $b = (Read-Text $base) | ConvertFrom-Json
        $pinned = $rest -match 'pin=1'
        # Our deny rules always go. model and effortLevel go only if we pinned them, you had none before, and they still hold our value.
        if ((Has-Prop $s 'permissions') -and (Has-Prop $s.permissions 'deny')) {
          $keep = @($s.permissions.deny | Where-Object { $b.permissions.deny -notcontains $_ })
          $s.permissions.deny = [object[]]$keep
        }
        if (Has-Prop $s 'env') {
          foreach ($p in $b.env.PSObject.Properties) { if ((Has-Prop $s.env $p.Name) -and $s.env.($p.Name) -eq $p.Value) { Remove-Prop $s.env $p.Name } }
        }
        if ($pinned -and $rest -notmatch 'had_model=1' -and (Has-Prop $s 'model') -and $s.model -eq $b.model) { Remove-Prop $s 'model' }
        if ($pinned -and $rest -notmatch 'had_effort=1' -and (Has-Prop $s 'effortLevel') -and $s.effortLevel -eq $b.effortLevel) { Remove-Prop $s 'effortLevel' }
        Write-Json $path $s
        Write-Host "    removed our entries from $path (your other settings are untouched)"
      }
    }
    'outputstyle' {
      if (Test-Path -LiteralPath $path) {
        $s = (Read-Text $path) | ConvertFrom-Json
        if ((Has-Prop $s 'outputStyle') -and $s.outputStyle -eq 'Terse') { Remove-Prop $s 'outputStyle'; Write-Json $path $s; Write-Host "    cleared the Terse output style from $path" }
      }
    }
    'plugin' {
      if (Get-Command claude -ErrorAction SilentlyContinue) {
        & claude plugin uninstall $path *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "    uninstalled plugin $path" }
      }
    }
  }
}
Remove-Item -Force -LiteralPath $Manifest
Say "Done. Backups made by the installer are in $(Join-Path $ClaudeDir 'backups') if you want to restore anything."
