# 02 · Construire le lab pas à pas

Chaque étape finit par une **vérification** et un **snapshot**. Ne passe pas à la suivante tant que la vérification n'est pas verte.

---

## Étape A · VM Ubuntu « st-wazuh » (~30 min)

1. Démarre `st-wazuh`, installe Ubuntu Server :
   - Réseau : édite l'interface en **manuel (IPv4)** : sous-réseau `10.10.10.0/24`, adresse `10.10.10.10`, passerelle `10.10.10.1`, DNS `10.10.10.1`.
   - Coche **Install OpenSSH server**. Nom de machine : `wazuh`. Pas de « snaps » supplémentaires.
2. Après le redémarrage, connecte-toi depuis l'hôte (plus confortable pour copier-coller) :
   ```powershell
   ssh -p 2222 <ton_user>@localhost
   ```
3. Clone le repo et installe Wazuh :
   ```bash
   git clone https://github.com/aedilkha/shadowtrace && cd shadowtrace
   sudo bash infra/wazuh/install-wazuh-docker.sh
   ```
4. **Vérification** : sur l'hôte, ouvre https://localhost:8443 (accepte le certificat auto-signé), connecte-toi `admin` / `SecretPassword`.
5. Déploie et teste les règles :
   ```bash
   sudo bash infra/wazuh/deploy-rules.sh
   sudo apt-get install -y jq && bash infra/wazuh/test-rules.sh
   ```
   **Vérification** : `Résultat : N OK, 0 FAIL`. S'il y a des FAIL, garde la sortie : c'est exactement le genre de chose qu'on débogue ensemble.
6. Snapshot VirtualBox : `wazuh-ready`.

### Mots de passe

Pour le lab, les mots de passe par défaut suffisent tant que tout reste en réseau NAT. Pour la démo publique (captures), change au moins celui d'`admin` : procédure officielle « Change the password of Wazuh users » de la doc wazuh-docker (section *single-node*). **Ne commite jamais** de mot de passe dans le repo.

---

## Étape B · VM Windows « st-ws-fin-042 » (~45 min)

1. Installe Windows 11 Enterprise (éval.). Compte local : `j.martin` (crée-le comme compte local : « Je n'ai pas Internet » / options de connexion > compte hors ligne).
2. Réseau : Paramètres > Réseau > Ethernet > Modifier l'attribution IP > Manuel : IP `10.10.10.20`, masque `255.255.255.0`, passerelle `10.10.10.1`, DNS `10.10.10.1`.
3. Renomme le PC en `WS-FIN-042` (Paramètres > Système > Informations), redémarre.
4. Installe les additions invité VirtualBox (menu Périphériques), redémarre.
5. Installe Git (`winget install Git.Git`), puis dans PowerShell **admin** :
   ```powershell
   cd C:\ ; git clone https://github.com/aedilkha/shadowtrace ; cd C:\shadowtrace
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\infra\windows\01-install-sysmon.ps1
   .\infra\windows\02-install-wazuh-agent.ps1 -Manager 10.10.10.10
   ```
6. **Vérification** : dashboard > *Agents* : `WS-FIN-042` est **Active**. Puis *Threat Hunting* > filtre `data.win.system.providerName: Microsoft-Windows-Sysmon` : des événements arrivent.
7. Snapshot : `win-clean`.

## Étape C · Préparer le scénario (~20 min)

```powershell
.\infra\windows\03-prepare-scenario.ps1
```
**Vérification** : `ollama list` montre `qwen2.5:1.5b`, `C:\Finance\Export\clients_2026.csv` existe, `ping exfil-relay.lab` répond depuis 10.10.10.10.
Snapshot : `win-ready`.

## Étape D · Rejouer l'attaque

Suis [scenario/RUNBOOK.md](../scenario/RUNBOOK.md).

## Étape E · Enquêter et rédiger

- Modèle de rapport : [reports/incident-report-template.md](../reports/incident-report-template.md)
- Mapping : [mitre-mapping.md](mitre-mapping.md)

## Budget RAM pendant le rejeu

| | RAM |
|---|---|
| st-wazuh (Docker : indexer 1 Go de heap + manager + dashboard) | 5 Go |
| st-ws-fin-042 (Windows + Ollama qwen2.5:1.5b ~1,5 Go) | 5 Go |
| Hôte | ~6 Go |

Si ça swappe : passe la VM Windows à 4 Go et utilise `--mode simulate` (pas besoin d'Ollama).
