#!/usr/bin/env bash
# =============================================================================
# ShadowTrace - Déploie les règles custom dans le manager Wazuh (Docker)
#     sudo bash infra/wazuh/deploy-rules.sh
# Relance ce script à chaque modification de rules/*.xml.
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_DIR="${COMPOSE_DIR:-/opt/wazuh-docker/single-node}"
SVC="wazuh.manager"
dc() { docker compose -f "$COMPOSE_DIR/docker-compose.yml" "$@"; }

echo "[1/4] Vérification des groupes Sysmon utilisés comme parents"
for g in sysmon_event1 sysmon_event3 sysmon_event_11 sysmon_event_22; do
  if dc exec -T "$SVC" grep -rqs "$g" /var/ossec/ruleset/rules/; then
    echo "  OK  $g"
  else
    echo "  !!  groupe $g introuvable dans le ruleset Wazuh : adapter rules/shadowtrace_rules.xml"
  fi
done

echo "[2/4] Copie des règles"
for f in "$REPO_DIR"/rules/*.xml; do
  dc cp "$f" "$SVC:/var/ossec/etc/rules/$(basename "$f")"
  echo "  -> $(basename "$f")"
done
dc exec -T "$SVC" chown -R wazuh:wazuh /var/ossec/etc/rules/
dc exec -T "$SVC" chmod 660 /var/ossec/etc/rules/*.xml

echo "[3/4] Test de syntaxe (wazuh-analysisd -t)"
if ! dc exec -T "$SVC" /var/ossec/bin/wazuh-analysisd -t; then
  echo "ERREUR de syntaxe : corrige le XML puis relance. Le manager n'a PAS été redémarré."
  exit 1
fi

echo "[4/4] Redémarrage du manager"
dc exec -T "$SVC" /var/ossec/bin/wazuh-control restart
echo
echo "Règles déployées. Teste-les avec :"
echo "  bash infra/wazuh/test-rules.sh"
