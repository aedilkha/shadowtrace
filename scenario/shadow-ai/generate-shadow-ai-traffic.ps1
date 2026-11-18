<#
.SYNOPSIS
  Génère le trafic « Shadow AI » du scénario (à lancer en tant qu'utilisateur, pas besoin d'admin).
.DESCRIPTION
  Ouvre ChatGPT et Gemini (non approuvés) puis Claude (approuvé) dans les navigateurs,
  comme le ferait le comptable. Sysmon journalise les requêtes DNS (EID 22) et connexions (EID 3).
  Pour la partie « fichier envoyé à Gemini », fais-le à la main avec un fichier FACTICE
  (ex. le budget généré ci-dessous) : c'est plus réaliste et ça se voit bien en capture d'écran.
#>
param([int]$PauseSec = 20)

$budget = "$env:USERPROFILE\Documents\budget_2027_v3.csv"
"poste,montant`nmarketing,120000`nIT,340000`nRH,95000" | Set-Content $budget -Encoding UTF8
Write-Host "Fichier factice pour la démo Gemini : $budget"

Write-Host "1) ChatGPT dans Chrome/Edge (Shadow AI) -> règle 100100 attendue"
Start-Process "https://chatgpt.com"
Start-Sleep $PauseSec

Write-Host "2) Gemini dans Edge (Shadow AI) -> règle 100100 attendue"
Start-Process "msedge.exe" "https://gemini.google.com"
Start-Sleep $PauseSec

Write-Host "3) Claude (IA approuvée) -> règle 100101 (niveau 3, pas d'alerte)"
Start-Process "https://claude.ai"
Start-Sleep 5
Write-Host "Terminé. Vérifie dans le dashboard : rule.groups: shadow_ai"
