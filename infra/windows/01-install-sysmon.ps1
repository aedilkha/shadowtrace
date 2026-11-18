<#
.SYNOPSIS
  Installe Sysmon avec la config SwiftOnSecurity + les ajouts ShadowTrace.
.DESCRIPTION
  A lancer dans la VM Windows (WS-FIN-042), PowerShell en ADMINISTRATEUR, depuis la racine du repo :
    Set-ExecutionPolicy -Scope Process Bypass -Force
    .\infra\windows\01-install-sysmon.ps1
  Relançable : si Sysmon est déjà installé, la config est simplement mise à jour (-c).
#>
[CmdletBinding()]
param(
  [string]$WorkDir   = "C:\ShadowTrace\sysmon",
  [string]$BaseUrl   = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml",
  [string]$SysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
)
$ErrorActionPreference = "Stop"
$RepoRoot  = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Additions = Join-Path $RepoRoot "config\sysmon\shadowtrace-additions.xml"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# 1. Téléchargements
Write-Host "[1/4] Téléchargement de Sysmon et de la config SwiftOnSecurity"
Invoke-WebRequest $SysmonUrl -OutFile "$WorkDir\Sysmon.zip"
Expand-Archive "$WorkDir\Sysmon.zip" -DestinationPath $WorkDir -Force
Invoke-WebRequest $BaseUrl -OutFile "$WorkDir\sysmonconfig-base.xml"

# 2. Fusion des ajouts ShadowTrace
Write-Host "[2/4] Application des ajouts ShadowTrace"
[xml]$cfg = Get-Content "$WorkDir\sysmonconfig-base.xml" -Raw
[xml]$add = Get-Content $Additions -Raw

function Add-Includes([string]$EventName) {
  $target = $cfg.SelectSingleNode("//$EventName[@onmatch='include']")
  if (-not $target) { Write-Warning "Bloc $EventName include introuvable"; return }
  foreach ($n in $add.ShadowTraceAdditions.$EventName.ChildNodes) {
    if ($n.NodeType -ne "Element") { continue }
    $target.AppendChild($cfg.ImportNode($n, $true)) | Out-Null
    Write-Host "  + $EventName : $($n.LocalName) $($n.condition) $($n.InnerText)"
  }
}
Add-Includes "NetworkConnect"
Add-Includes "FileCreate"

$dnsExclude = $cfg.SelectSingleNode("//DnsQuery[@onmatch='exclude']")
if ($dnsExclude) {
  $patterns = $add.ShadowTraceAdditions.DnsQueryUnexclude.Pattern
  foreach ($n in @($dnsExclude.ChildNodes)) {
    if ($n.NodeType -ne "Element") { continue }
    foreach ($p in $patterns) {
      if ($n.InnerText -match $p) {
        $dnsExclude.RemoveChild($n) | Out-Null
        Write-Host "  - DnsQuery : exclusion retirée ($($n.InnerText))"
        break
      }
    }
  }
}
$final = "$WorkDir\sysmonconfig-shadowtrace.xml"
$cfg.Save($final)

# 3. Installation ou mise à jour
Write-Host "[3/4] Installation / mise à jour de Sysmon"
$exe = "$WorkDir\Sysmon64.exe"
if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) {
  & $exe -c $final
} else {
  & $exe -accepteula -i $final
}

# 4. Vérification
Write-Host "[4/4] Vérification"
Get-Service Sysmon64 | Format-Table Name, Status
Resolve-DnsName chatgpt.com -ErrorAction SilentlyContinue | Out-Null
Start-Sleep 2
$ev = Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 50 |
      Where-Object { $_.Id -eq 22 -and $_.Message -match "chatgpt" } | Select-Object -First 1
if ($ev) { Write-Host "OK : la requête DNS chatgpt.com est bien journalisée (EID 22)." -ForegroundColor Green }
else     { Write-Warning "Pas encore d'EID 22 pour chatgpt.com : réessaie dans un navigateur, puis regarde l'Observateur d'événements." }
Write-Host "Config appliquée : $final (copie-la dans config/sysmon/ si tu veux la versionner)"
