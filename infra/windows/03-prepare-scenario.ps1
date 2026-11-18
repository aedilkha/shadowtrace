<#
.SYNOPSIS
  Prépare la VM Windows pour le scénario : Python, Ollama + petit modèle, données factices,
  résolution du domaine « attaquant » du lab.
.DESCRIPTION
  PowerShell en ADMINISTRATEUR, depuis la racine du repo :
    .\infra\windows\03-prepare-scenario.ps1
  Après l'installation de Python, ferme et rouvre PowerShell si "python" n'est pas reconnu, puis relance.
#>
[CmdletBinding()]
param(
  [string]$AttackerIp = "10.10.10.10",
  [string]$Model      = "qwen2.5:1.5b",
  [int]$Rows          = 12418
)
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

Write-Host "[1/6] Python 3.12 et Ollama (winget)"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  winget install --id Python.Python.3.12 -e --silent --accept-package-agreements --accept-source-agreements
}
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  winget install --id Ollama.Ollama -e --silent --accept-package-agreements --accept-source-agreements
}
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")

Write-Host "[2/6] Dépendances Python"
python -m pip install --upgrade pip
python -m pip install -r (Join-Path $RepoRoot "scenario\requirements.txt")

Write-Host "[3/6] Modèle local $Model (~1 Go)"
ollama pull $Model

Write-Host "[4/6] Données clients FACTICES"
python (Join-Path $RepoRoot "scenario\payloads\make_fake_customers.py") --out "C:\Finance\Export\clients_2026.csv" --rows $Rows

Write-Host "[5/6] Domaine du lab exfil-relay.lab -> $AttackerIp (fichier hosts)"
$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not (Select-String -Path $hosts -Pattern "exfil-relay\.lab" -Quiet)) {
  Add-Content -Path $hosts -Value "`r`n$AttackerIp`texfil-relay.lab   # ShadowTrace lab"
}

Write-Host "[6/6] Dossiers de travail"
New-Item -ItemType Directory -Force -Path "C:\ShadowTrace\logs","C:\ShadowTrace\evidence" | Out-Null

Write-Host "`nPrêt. Prends un snapshot VirtualBox 'win-ready' MAINTENANT, puis suis scenario\RUNBOOK.md." -ForegroundColor Green
