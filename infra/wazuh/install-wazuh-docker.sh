#!/usr/bin/env bash
# =============================================================================
# ShadowTrace - Installe Wazuh (manager + indexer + dashboard) en Docker single-node
# A lancer sur la VM Ubuntu Server 24.04 (st-wazuh, 10.10.10.10) :
#     sudo bash infra/wazuh/install-wazuh-docker.sh
# Idempotent : relançable sans risque.
# Version : vérifie la dernière sur https://github.com/wazuh/wazuh-docker/releases
#     sudo WAZUH_VERSION=4.12.0 bash infra/wazuh/install-wazuh-docker.sh
# =============================================================================
set -euo pipefail

WAZUH_VERSION="${WAZUH_VERSION:-4.12.0}"
INSTALL_DIR="${INSTALL_DIR:-/opt/wazuh-docker}"
INDEXER_HEAP="${INDEXER_HEAP:-1g}"   # 1g suffit pour le lab (VM de 5 Go)

log() { printf '\n\033[1;36m[ShadowTrace]\033[0m %s\n' "$*"; }
[[ $EUID -eq 0 ]] || { echo "Lance avec sudo."; exit 1; }

log "1/6 Paquets de base + Docker"
apt-get update -y
apt-get install -y ca-certificates curl git jq python3 docker.io docker-compose-v2
systemctl enable --now docker
if [[ -n "${SUDO_USER:-}" ]]; then usermod -aG docker "$SUDO_USER"; fi

log "2/6 Réglage noyau requis par l'indexer (vm.max_map_count)"
sysctl -w vm.max_map_count=262144
grep -q '^vm.max_map_count' /etc/sysctl.conf || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf

log "3/6 Récupération de wazuh-docker v${WAZUH_VERSION}"
if [[ ! -d "$INSTALL_DIR/.git" ]]; then
  git clone --depth 1 -b "v${WAZUH_VERSION}" https://github.com/wazuh/wazuh-docker.git "$INSTALL_DIR"
else
  echo "Déjà cloné dans $INSTALL_DIR"
fi
cd "$INSTALL_DIR/single-node"

log "4/6 Limite mémoire de l'indexer à ${INDEXER_HEAP}"
sed -i -E "s/-Xms[0-9]+[gm] -Xmx[0-9]+[gm]/-Xms${INDEXER_HEAP} -Xmx${INDEXER_HEAP}/" docker-compose.yml

log "5/6 Certificats TLS internes"
if [[ ! -d config/wazuh_indexer_ssl_certs ]] || [[ -z "$(ls -A config/wazuh_indexer_ssl_certs 2>/dev/null | grep -v '^\.')" ]]; then
  docker compose -f generate-indexer-certs.yml run --rm generator
else
  echo "Certificats déjà générés."
fi

log "6/6 Démarrage de la stack"
docker compose up -d

log "Attente du dashboard (2-4 min au premier démarrage)..."
for i in $(seq 1 60); do
  if curl -sk -o /dev/null -w '%{http_code}' https://localhost:443 | grep -qE '200|302'; then break; fi
  sleep 5
done
docker compose ps

IP=$(hostname -I | awk '{print $1}')
cat <<EOF

=====================================================================
 Wazuh est lancé.
 Dashboard depuis l'HÔTE : https://localhost:8443   (redirection NAT)
 Dashboard depuis la VM  : https://${IP}
 Identifiants par défaut : admin / SecretPassword
   -> à changer (docs/02-lab-build.md, section "Mots de passe")
 Prochaine étape : sudo bash infra/wazuh/deploy-rules.sh
=====================================================================
EOF
