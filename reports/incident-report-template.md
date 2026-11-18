# Rapport d'incident · INC-AAAA-MMJJ-001

> Copie ce fichier en `reports/INC-AAAA-MMJJ-001.md` et remplace tout ce qui est entre `<...>`.
> Structure : NIST SP 800-61. Ton : factuel, chaque affirmation renvoie à une preuve (§ 9).

| Champ | Valeur |
|---|---|
| Identifiant | INC-<AAAA-MMJJ>-001 |
| Titre | Agent IA local détourné par injection de prompt indirecte, exfiltration de données clients |
| Sévérité | <Critique / Élevée> (justification : <données personnelles, volume, IBAN>) |
| Statut | <Ouvert / Confiné / Clos> |
| Poste / utilisateur | WS-FIN-042 / j.martin |
| Détecté le / par | <date heure UTC> / Wazuh règle 100140 |
| Analyste | Alvi <nom> |
| Classification | TLP:AMBER (exercice de lab, données factices) |

## 1. Résumé exécutif (5 lignes max, pour un manager)

<Que s'est-il passé, quel impact, est-ce maîtrisé, que faut-il décider.>

## 2. Chronologie

| Heure (UTC) | Événement | Source | Règle / preuve |
|---|---|---|---|
| <09:02:11> | Accès à chatgpt.com depuis chrome.exe | Sysmon EID 22 | 100100 · E-01 |
| <...> | <...> | <...> | <...> |
| <09:14:27> | POST de <n> octets vers exfil-relay.lab:8080 | Sysmon EID 3 + log agent | 100140 · E-05 |
| <09:31:40> | Poste confiné | Analyste | — |

## 3. Périmètre et impact

- **Données exposées** : <fichier, nombre de lignes, types de champs>.
- **Systèmes touchés** : <...>.
- **Usage Shadow AI** : <services, fichiers envoyés, volumes>.
- **Obligations** : en situation réelle, analyse RGPD art. 33 (notification CNIL / APD sous 72 h) à évaluer avec le DPO.

## 4. Analyse technique

### 4.1 Vecteur initial
<Comment la facture est arrivée, son hash, où se cache l'instruction (capture Ctrl+A).>

### 4.2 Mécanisme de l'injection
<Pourquoi l'agent a obéi : contenu non fiable dans le prompt, outils sans restriction, pas de liste blanche. Extrait du log agent.>

### 4.3 Exfiltration
<Destination, protocole, volume, hash du fichier reçu côté attaquant = hash de l'original ?>

### 4.4 Shadow AI
<Ce qui a été vu, ce qui n'a pas pu être vu (contenu chiffré HTTPS), limites de la détection DNS.>

## 5. Mapping MITRE

| Tactique | Technique (ATT&CK / ATLAS) | Observé |
|---|---|---|
| <...> | <...> | <...> |

## 6. Indicateurs de compromission (IOC)

| Type | Valeur | Contexte |
|---|---|---|
| Domaine | exfil-relay.lab | Destination d'exfiltration |
| IP:port | 10.10.10.10:8080 | idem |
| SHA-256 | <...> | Facture_Q3_Fournisseur.pdf |
| Chaîne | « ignore les consignes précédentes » | Charge d'injection |

## 7. Réponse

- **Confinement** : <arrêt du process, règle pare-feu, isolement>.
- **Éradication** : <suppression du PDF, désactivation de l'agent>.
- **Récupération** : <remise en service avec --guardrails, vérification>.

## 8. Retour d'expérience et recommandations

| # | Recommandation | Priorité | Responsable |
|---|---|---|---|
| 1 | Traiter tout contenu de document comme non fiable (séparation données / instructions) | Haute | Équipe dev agent |
| 2 | Liste blanche des outils et destinations de l'agent, moindre privilège sur les fichiers | Haute | Dev + Sécu |
| 3 | Politique d'usage de l'IA + liste des services approuvés, communiquée aux équipes | Moyenne | RSSI / DPO |
| 4 | Proxy / CASB : bloquer ou alerter sur les IA non approuvées | Moyenne | Infra |
| 5 | Journaliser les prompts et appels d'outils des agents (comme ici) | Moyenne | Dev |

**Ce qui a bien marché / ce qui manquait dans la détection :** <honnêteté = crédibilité en entretien>.

## 9. Preuves

| ID | Fichier | SHA-256 | Collecté par / quand |
|---|---|---|---|
| E-01 | sysmon.evtx | <...> | <...> |
| E-02 | agent.jsonl | <...> | <...> |
| E-03 | Facture_Q3_Fournisseur.pdf | <...> | <...> |
| E-04 | receptions.jsonl (côté attaquant) | <...> | <...> |
| E-05 | Captures dashboard Wazuh | — | <...> |

## Annexe · Rejeu 3D

`viz/incident.json` généré par `tools/wazuh_to_3d.py`, visualisable dans `viz/shadowtrace-3d.html`.
