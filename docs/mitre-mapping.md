# Mapping MITRE ATT&CK / ATLAS / OWASP LLM

| Phase | Ce qui se passe | ATT&CK | ATLAS | OWASP LLM Top 10 (2025) | Règle(s) |
|---|---|---|---|---|---|
| Shadow AI | Données internes envoyées à des IA non approuvées | T1567 Exfiltration Over Web Service | — | LLM02 Sensitive Information Disclosure | 100100 |
| IA approuvée | Usage conforme, simplement journalisé | — | — | — | 100101 |
| Exécution | Lancement d'un agent Python avec outils | T1059.006 Python | AML.T0040 AI Model Inference API Access | LLM06 Excessive Agency | 100110, 100112, 100111 |
| Accès initial | Facture piégée reçue (pièce jointe) | T1566.001 Spearphishing Attachment | — | — | 100120 |
| Injection | Instruction cachée (texte blanc 1 pt) lue par l'agent | — | AML.T0051.001 LLM Prompt Injection: Indirect | LLM01 Prompt Injection | 100121 |
| Collecte | L'agent lit le fichier clients avec son outil | T1005 Data from Local System | AML.T0053 AI Agent Tool Invocation | LLM06 Excessive Agency | 100122 |
| Exfiltration | L'agent envoie le fichier en HTTP POST | T1041 Exfiltration Over C2 Channel · T1071.001 Web Protocols | AML.T0086 Exfiltration via AI Agent Tool Invocation | LLM02 | 100123, 100130, 100131 |
| Corrélation | Injection puis sortie réseau en < 5 min | T1567 | AML.T0086 | — | **100140** |

> Vérifie les intitulés exacts des techniques ATLAS sur https://atlas.mitre.org au moment de rédiger le rapport : le référentiel évolue souvent et certaines techniques ont été renommées.

## Cadres de réponse

| Cadre | Utilisation dans le projet |
|---|---|
| NIST SP 800-61 | Structure du rapport : préparation, détection & analyse, confinement / éradication / récupération, retour d'expérience |
| ISO/IEC 27001:2022 | A.5.23 (services cloud), A.8.12 (prévention des fuites), A.5.26 (réponse aux incidents) |
| NIST AI RMF / ISO 42001 | Recommandations de gouvernance de l'IA (inventaire des IA, politique d'usage, garde-fous des agents) |
