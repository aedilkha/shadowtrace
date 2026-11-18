#!/usr/bin/env python3
"""
ShadowTrace - Exporte les alertes Wazuh du scénario vers le JSON de la carte 3D (viz/shadowtrace-3d.html).

Sources possibles :
  --indexer https://localhost:9200   (par défaut ; identifiants admin du docker-compose)
  --alerts-file alerts.json          (fichier /var/ossec/logs/alerts/alerts.json copié depuis le manager)

Exemples (VM Ubuntu) :
  python3 tools/wazuh_to_3d.py --since 2026-11-20T09:00:00 --out viz/incident.json
  docker compose -f /opt/wazuh-docker/single-node/docker-compose.yml exec -T wazuh.manager \
      cat /var/ossec/logs/alerts/alerts.json > /tmp/alerts.json
  python3 tools/wazuh_to_3d.py --alerts-file /tmp/alerts.json --out viz/incident.json
Puis : ouvrir viz/shadowtrace-3d.html > « Charger un JSON » > viz/incident.json
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import ssl
import sys
import urllib.request
from pathlib import Path

# Rule ID -> comment la représenter dans la carte 3D
STEPS = {
    "100100": dict(phase="Shadow AI", severity="medium", title="IA non approuvée contactée",
                   tags=[{"fw": "ATT&CK", "id": "T1567", "name": "Exfiltration via service web"}]),
    "100101": dict(phase="Shadow AI", severity="info", title="IA approuvée (liste blanche)", tags=[]),
    "100110": dict(phase="Agent IA", severity="low", title="Runtime LLM local démarré", nodes=["ws", "ollama"], links=[], tags=[]),
    "100112": dict(phase="Agent IA", severity="info", title="Agent IA Python lancé", nodes=["ws", "agent"], links=["l-ws-agent"], tags=[]),
    "100111": dict(phase="Agent IA", severity="low", title="L'agent interroge le modèle local", nodes=["agent", "ollama"], links=["l-agent-ollama"], tags=[]),
    "100120": dict(phase="Injection", severity="medium", title="PDF déposé dans Downloads", nodes=["ws", "doc"], links=[], status={"doc": "suspect"},
                   tags=[{"fw": "ATT&CK", "id": "T1566.001", "name": "Pièce jointe piégée"}]),
    "100121": dict(phase="Injection", severity="critical", title="Injection de prompt dans la facture", nodes=["agent", "doc", "ollama"],
                   links=["l-agent-doc", "l-agent-ollama"], status={"doc": "malicious", "agent": "compromised"},
                   tags=[{"fw": "ATLAS", "id": "AML.T0051.001", "name": "Injection de prompt indirecte"}]),
    "100122": dict(phase="Collecte", severity="high", title="Lecture du fichier clients", nodes=["agent", "data"], links=["l-agent-data"],
                   status={"data": "exposed"}, tags=[{"fw": "ATLAS", "id": "AML.T0053", "name": "Invocation d'outil d'agent IA"}]),
    "100123": dict(phase="Exfiltration", severity="critical", title="L'agent appelle http_post", nodes=["agent", "attacker"], links=["l-exfil"],
                   status={"attacker": "malicious"}, tags=[{"fw": "ATLAS", "id": "AML.T0086", "name": "Exfiltration via outil d'agent IA"}]),
    "100130": dict(phase="Exfiltration", severity="high", title="Python résout un domaine inconnu", nodes=["agent", "attacker"], links=["l-exfil"], tags=[]),
    "100131": dict(phase="Exfiltration", severity="critical", title="Connexion sortante de l'agent", nodes=["agent", "attacker"], links=["l-exfil"],
                   status={"attacker": "malicious"}, tags=[{"fw": "ATT&CK", "id": "T1041", "name": "Exfiltration via canal C2"}]),
    "100140": dict(phase="Détection", severity="critical", title="Corrélation : agent IA détourné", nodes=["ws", "siem"], links=["l-telemetry"],
                   tags=[{"fw": "ATLAS", "id": "AML.T0086", "name": "Exfiltration via outil d'agent IA"}]),
}

BASE_NODES = [
    {"id": "ws", "label": "WS-FIN-042", "sub": "10.10.10.20 · Windows 11", "type": "endpoint"},
    {"id": "chatgpt", "label": "ChatGPT", "sub": "chatgpt.com", "type": "ai_cloud", "status": "shadow"},
    {"id": "gemini", "label": "Gemini", "sub": "gemini.google.com", "type": "ai_cloud", "status": "shadow"},
    {"id": "claude", "label": "Claude", "sub": "claude.ai", "type": "ai_cloud", "status": "approved"},
    {"id": "ollama", "label": "Ollama", "sub": "127.0.0.1:11434", "type": "ai_local", "status": "approved"},
    {"id": "agent", "label": "invoice_agent.py", "sub": "python.exe", "type": "agent"},
    {"id": "doc", "label": "Facture_Q3_Fournisseur.pdf", "sub": "Downloads", "type": "document"},
    {"id": "data", "label": "clients_2026.csv", "sub": "C:\\Finance\\Export", "type": "data"},
    {"id": "attacker", "label": "exfil-relay.lab", "sub": "10.10.10.10:8080", "type": "attacker"},
    {"id": "siem", "label": "Wazuh", "sub": "10.10.10.10", "type": "siem"},
]
BASE_LINKS = [
    {"id": "l-chatgpt", "source": "ws", "target": "chatgpt", "kind": "shadow", "label": "HTTPS 443"},
    {"id": "l-gemini", "source": "ws", "target": "gemini", "kind": "shadow", "label": "HTTPS 443"},
    {"id": "l-claude", "source": "ws", "target": "claude", "kind": "approved", "label": "HTTPS 443"},
    {"id": "l-ws-agent", "source": "ws", "target": "agent", "kind": "local", "label": "processus"},
    {"id": "l-agent-ollama", "source": "agent", "target": "ollama", "kind": "local", "label": "HTTP 11434"},
    {"id": "l-agent-doc", "source": "agent", "target": "doc", "kind": "local", "label": "read_pdf"},
    {"id": "l-agent-data", "source": "agent", "target": "data", "kind": "local", "label": "read_file"},
    {"id": "l-exfil", "source": "agent", "target": "attacker", "kind": "exfil", "label": "HTTP POST :8080"},
    {"id": "l-telemetry", "source": "ws", "target": "siem", "kind": "telemetry", "label": "Agent Wazuh · Sysmon"},
]


def fetch_indexer(url: str, user: str, pwd: str, since: str, size: int) -> list[dict]:
    q = {"size": size, "sort": [{"timestamp": "asc"}],
         "query": {"bool": {"filter": [{"term": {"rule.groups": "shadowtrace"}},
                                       {"range": {"timestamp": {"gte": since}}}]}}}
    req = urllib.request.Request(f"{url}/wazuh-alerts-*/_search", data=json.dumps(q).encode(), method="POST",
                                 headers={"Content-Type": "application/json",
                                          "Authorization": "Basic " + base64.b64encode(f"{user}:{pwd}".encode()).decode()})
    ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE  # certificat auto-signé du lab
    with urllib.request.urlopen(req, context=ctx, timeout=30) as r:
        return [h["_source"] for h in json.loads(r.read())["hits"]["hits"]]


def read_alerts_file(path: Path, since: str) -> list[dict]:
    out = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            a = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "shadowtrace" in a.get("rule", {}).get("groups", []) and a.get("timestamp", "") >= since:
            out.append(a)
    return sorted(out, key=lambda a: a["timestamp"])


def to_step(a: dict) -> dict | None:
    rid = a["rule"]["id"]
    tpl = STEPS.get(rid)
    if not tpl:
        return None
    ed = a.get("data", {}).get("win", {}).get("eventdata", {})
    step = {"time": a["timestamp"][11:19], "phase": tpl["phase"], "severity": tpl["severity"], "title": tpl["title"],
            "desc": a["rule"]["description"], "nodes": list(tpl.get("nodes", [])), "links": list(tpl.get("links", [])),
            "evidence": [{"src": f"Wazuh {rid} (niv. {a['rule']['level']})", "text": a["rule"]["description"][:140]}],
            "tags": tpl["tags"]}
    if "status" in tpl:
        step["status"] = tpl["status"]
    if rid in ("100100", "100101"):  # choisir le bon nœud IA selon le domaine
        q = ed.get("queryName", "")
        target = "chatgpt" if ("chatgpt" in q or "openai" in q) else "gemini" if "gemini" in q else "claude"
        step["nodes"], step["links"] = ["ws", target], [f"l-{target}"]
        step["title"] += f" : {q}"
    return step


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--indexer", default="https://localhost:9200")
    ap.add_argument("--user", default=os.environ.get("INDEXER_USER", "admin"))
    ap.add_argument("--password", default=os.environ.get("INDEXER_PASSWORD", "SecretPassword"))
    ap.add_argument("--alerts-file", type=Path)
    ap.add_argument("--since", default="1970-01-01T00:00:00")
    ap.add_argument("--max", type=int, default=500)
    ap.add_argument("--out", type=Path, default=Path("viz/incident.json"))
    a = ap.parse_args()

    alerts = read_alerts_file(a.alerts_file, a.since) if a.alerts_file else \
        fetch_indexer(a.indexer, a.user, a.password, a.since, a.max)
    steps, seen = [], set()
    for al in alerts:
        s = to_step(al)
        key = (al["rule"]["id"], s and s["title"])
        if s and key not in seen:  # une étape par règle (et par domaine pour le Shadow AI)
            seen.add(key)
            steps.append(s)
    if not steps:
        print("Aucune alerte ShadowTrace trouvée : vérifie --since et que le scénario a bien été joué.", file=sys.stderr)
        return 1
    host = alerts[0].get("agent", {}).get("name", "WS-FIN-042")
    incident = {"id": "INC-" + alerts[0]["timestamp"][:10].replace("-", "") + "-001",
                "title": "Agent IA local détourné par injection de prompt indirecte, exfiltration de données clients ; Shadow AI sur le même poste.",
                "host": host, "date": alerts[0]["timestamp"][:10],
                "severity": "Critique" if any(al["rule"]["level"] >= 15 for al in alerts) else "Élevée",
                "note": f"Généré depuis {len(alerts)} alertes Wazuh réelles du lab ShadowTrace"}
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps({"incident": incident, "nodes": BASE_NODES, "links": BASE_LINKS, "timeline": steps},
                                ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{len(steps)} étapes écrites dans {a.out} (à charger dans viz/shadowtrace-3d.html)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
