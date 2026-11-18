#!/usr/bin/env bash
# =============================================================================
# ShadowTrace - Rejoue des événements d'exemple dans le moteur de règles Wazuh
# (API /logtest) pour vérifier chaque règle SANS avoir besoin de la VM Windows.
#     bash infra/wazuh/test-rules.sh
# Identifiants API : ceux de docker-compose.yml (API_USERNAME / API_PASSWORD).
# =============================================================================
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="${WAZUH_API:-https://localhost:55000}"
API_USER="${API_USER:-wazuh-wui}"
API_PASS="${API_PASS:-MyS3cr37P450r.*-}"
SAMPLES="$REPO_DIR/rules/tests/samples.jsonl"

TOKEN=$(curl -sk -u "$API_USER:$API_PASS" -X POST "$API/security/user/authenticate?raw=true")
[[ -n "$TOKEN" && "$TOKEN" != *error* ]] || { echo "Authentification API impossible (vérifie API_USER/API_PASS)."; exit 1; }

pass=0; fail=0; SESSION=""
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  expected=$(jq -r '.expect' <<<"$line")
  name=$(jq -r '.name' <<<"$line")
  # Une même session logtest garde la mémoire des alertes : nécessaire pour tester la corrélation 100140.
  body=$(jq -c --arg s "$SESSION" '{event: (.log|tojson), log_format: "json", location: (.location // "EventChannel")}
         + (if $s == "" then {} else {token: $s} end)' <<<"$line")
  resp=$(curl -sk -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -X PUT "$API/logtest" -d "$body")
  SESSION=$(jq -r '.data.token // empty' <<<"$resp")
  got=$(jq -r '.data.output.rule.id // "aucune"' <<<"$resp")
  if [[ "$got" == "$expected" ]]; then
    printf '  OK    %-7s %s\n' "$expected" "$name"; pass=$((pass+1))
  else
    printf '  FAIL  %-7s %s (obtenu : %s)\n' "$expected" "$name" "$got"; fail=$((fail+1))
  fi
done < "$SAMPLES"
echo "Résultat : $pass OK, $fail FAIL"
[[ $fail -eq 0 ]]
