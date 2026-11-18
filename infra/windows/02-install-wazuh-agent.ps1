<#
.SYNOPSIS
  Installe l'agent Wazuh sur la VM Windows et ajoute la collecte Sysmon + log de l'agent IA.
.DESCRIPTION
  PowerShell en ADMINISTRATEUR, depuis la racine du repo :
    .\infra\windows\02-install-wazuh-agent.ps1 -Manager 10.10.10.10
  La version de l'agent doit être <= à celle du manager (voir infra/wazuh/install-wazuh-docker.sh).
#>
[CmdletBinding()]
param(
  [string]$Manager   = "10.10.10.10",
  [string]$Version   = "4.12.0",
  [string]$AgentName = $env:COMPUTERNAME,
  [string]$Group     = "default"
)
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$OssecDir = "${env:ProgramFiles(x86)}\ossec-agent"
$Conf     = Join-Path $OssecDir "ossec.conf"

Write-Host "[1/5] Test de joignabilité du manager $Manager"
foreach ($p in 1514, 1515) {
  if (-not (Test-NetConnection $Manager -Port $p -InformationLevel Quiet)) {
    throw "Port $p injoignable sur $Manager. Wazuh est-il lancé ? Les deux VM sont-elles sur shadowtrace-net ?"
  }
}

if (-not (Test-Path $Conf)) {
  Write-Host "[2/5] Téléchargement et installation de l'agent $Version"
  $msi = "$env:TEMP\wazuh-agent-$Version-1.msi"
  Invoke-WebRequest "https://packages.wazuh.com/4.x/windows/wazuh-agent-$Version-1.msi" -OutFile $msi
  Start-Process msiexec.exe -Wait -ArgumentList @(
    "/i", "`"$msi`"", "/q",
    "WAZUH_MANAGER=$Manager", "WAZUH_REGISTRATION_SERVER=$Manager",
    "WAZUH_AGENT_NAME=$AgentName", "WAZUH_AGENT_GROUP=$Group"
  )
} else {
  Write-Host "[2/5] Agent déjà installé, on passe à la configuration"
}

Write-Host "[3/5] Dossier du log de l'agent IA"
New-Item -ItemType Directory -Force -Path "C:\ShadowTrace\logs" | Out-Null
if (-not (Test-Path "C:\ShadowTrace\logs\agent.jsonl")) { New-Item -ItemType File "C:\ShadowTrace\logs\agent.jsonl" | Out-Null }

Write-Host "[4/5] Ajout des sources ShadowTrace dans ossec.conf"
$content = Get-Content $Conf -Raw
if ($content -match "ShadowTrace : début") {
  Write-Host "  déjà présent"
} else {
  Copy-Item $Conf "$Conf.bak-shadowtrace" -Force
  $snippet = Get-Content (Join-Path $RepoRoot "config\wazuh-agent\shadowtrace-localfile.xml") -Raw
  $idx = $content.LastIndexOf("</ossec_config>")
  $content = $content.Substring(0, $idx) + $snippet + "`r`n" + $content.Substring($idx)
  Set-Content -Path $Conf -Value $content -Encoding UTF8
  Write-Host "  ajouté (sauvegarde : ossec.conf.bak-shadowtrace)"
}

Write-Host "[5/5] (Re)démarrage du service"
Restart-Service WazuhSvc -ErrorAction SilentlyContinue
if (-not $?) { Start-Service WazuhSvc }
Start-Sleep 5
Get-Service WazuhSvc | Format-Table Name, Status
Get-Content (Join-Path $OssecDir "ossec.log") -Tail 15
Write-Host "`nVérifie dans le dashboard : Agents > $AgentName doit être 'active'." -ForegroundColor Green
