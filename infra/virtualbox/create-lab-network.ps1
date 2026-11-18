<#
.SYNOPSIS
  Crée le réseau NAT VirtualBox du lab ShadowTrace + redirections de ports vers la VM Wazuh.
.DESCRIPTION
  A lancer sur l'HÔTE (ton PC de bureau), dans PowerShell, après avoir installé VirtualBox.
  Idempotent : peut être relancé sans casser l'existant.
.EXAMPLE
  .\infra\virtualbox\create-lab-network.ps1
#>
[CmdletBinding()]
param(
  [string]$NetName  = "shadowtrace-net",
  [string]$Cidr     = "10.10.10.0/24",
  [string]$WazuhIp  = "10.10.10.10"
)
$ErrorActionPreference = "Stop"

$vbm = Join-Path $env:ProgramFiles "Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $vbm)) { throw "VBoxManage introuvable ($vbm). Installe VirtualBox d'abord." }

# 1. Vérifications de l'hôte
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$virt  = (Get-CimInstance Win32_Processor | Select-Object -First 1).VirtualizationFirmwareEnabled
Write-Host "RAM hôte : $ramGB Go | Virtualisation activée dans le BIOS : $virt"
if ($ramGB -lt 15) { Write-Warning "Moins de 16 Go : mets 4 Go par VM au lieu de 5." }
if (-not $virt)   { Write-Warning "Active VT-x / AMD-V (SVM) dans le BIOS avant de continuer." }

# 2. Réseau NAT
$existing = & $vbm natnetwork list 2>$null | Select-String -SimpleMatch "Name:        $NetName"
if (-not $existing) {
  & $vbm natnetwork add --netname $NetName --network $Cidr --enable --dhcp on
  Write-Host "Réseau $NetName créé ($Cidr)."
} else {
  Write-Host "Réseau $NetName déjà présent."
}

# 3. Redirections de ports hôte -> VM Wazuh (le dashboard sera sur https://localhost:8443)
$rules = @(
  "wazuh-dashboard:tcp:[]:8443:[$WazuhIp]:443",
  "wazuh-api:tcp:[]:55000:[$WazuhIp]:55000",
  "wazuh-indexer:tcp:[]:9200:[$WazuhIp]:9200",
  "wazuh-ssh:tcp:[]:2222:[$WazuhIp]:22"
)
foreach ($r in $rules) {
  $name = $r.Split(":")[0]
  & $vbm natnetwork modify --netname $NetName --port-forward-4 delete $name 2>$null | Out-Null
  & $vbm natnetwork modify --netname $NetName --port-forward-4 $r
  Write-Host "Redirection : $r"
}

Write-Host "`nOK. Prochaine étape : .\infra\virtualbox\create-vms.ps1 (ou création manuelle, voir docs/01-host-setup.md)"
