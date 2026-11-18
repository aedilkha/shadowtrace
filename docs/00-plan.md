# Plan du projet

Objectif : un projet présentable en entretien (repo propre + démo + rapport + carte 3D), en environ 2 à 3 semaines de soirs/jours de lab.

## Jalons

| # | Jalon | Livrable | Critère de « fini » |
|---|---|---|---|
| J0 | Repo « lab as code » prêt (fait depuis le portable) | Ce repo | Clonable, docs lisibles |
| J1 | Hôte prêt | VirtualBox + réseau `shadowtrace-net` | `create-lab-network.ps1` passe |
| J2 | SIEM en place | Wazuh Docker sur la VM Ubuntu | Dashboard accessible depuis l'hôte |
| J3 | Endpoint instrumenté | Windows 11 + Sysmon + agent Wazuh | Événements Sysmon visibles dans le dashboard |
| J4 | Détections | Règles 100100-100140 chargées | `wazuh-logtest` OK + chaque règle vue au moins une fois |
| J5 | Attaque rejouée | Scénario complet du RUNBOOK | Alerte 100140 (niveau 15) déclenchée |
| J6 | Enquête | Captures, timeline, IOC, artefacts | `evidence/` rempli, hashes calculés |
| J7 | Rapport | `reports/INC-...md` | Rapport complet NIST 800-61 + MITRE |
| J8 | Démo | Carte 3D alimentée par les vraies alertes + vidéo 3 min | Lien dans le README + LinkedIn |

## Ordre de travail conseillé à la maison

1. **Session 1 (~2 h)** : J1 + J2. Installer VirtualBox, créer le réseau, installer Ubuntu, lancer Wazuh. Snapshot `wazuh-clean`.
2. **Session 2 (~2 h)** : J3. Installer Windows 11, Sysmon, l'agent Wazuh. Vérifier les événements. Snapshot `win-clean`.
3. **Session 3 (~2 h)** : J4 + J5. Déployer les règles, préparer le scénario, rejouer l'attaque, ajuster les règles.
4. **Session 4 (~3 h)** : J6 + J7. Enquête et rapport.
5. **Session 5 (~2 h)** : J8. Export 3D, captures, vidéo, mise à jour du README.

## Règle d'or

Tout changement fait à la main dans une VM doit finir **dans le repo** (script, config, ou note dans `docs/`). Si la VM est perdue, on doit pouvoir tout reconstruire.

## Idées de bonus (si le temps le permet)

- Règle Sigma équivalente à chaque règle Wazuh (portabilité multi-SIEM).
- Active response Wazuh : bloquer `exfil-relay.lab` automatiquement dans le pare-feu Windows.
- Garde-fou dans l'agent (filtrage des sorties d'outils, liste blanche de domaines) et démonstration « avant / après ».
- Script de collecte d'artefacts (`tools/collect_evidence.ps1`) pour la phase forensic.
