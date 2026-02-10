#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

SERVICE_NAME="mtproxy"
INSTALL_DIR="/opt/MTProxy"
CONFIG_DIR="/etc/mtproxy"
ENV_FILE="${CONFIG_DIR}/mtproxy.env"
RUNNER_BIN="/usr/local/bin/mtproxy-run"
SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
MT_USER="mtproxy"
PROXY_PORT="${PROXY_PORT:-443}"
STATS_PORT="${STATS_PORT:-8888}"
WORKERS="${WORKERS:-2}"

echo "[1/8] Installing dependencies..."
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git make gcc libc6-dev libssl-dev zlib1g-dev openssl

echo "[2/8] Installing/updating MTProxy source..."
if [[ -d "${INSTALL_DIR}/.git" ]]; then
  git -C "${INSTALL_DIR}" fetch --all --tags
  git -C "${INSTALL_DIR}" reset --hard origin/master
else
  git clone https://github.com/TelegramMessenger/MTProxy.git "${INSTALL_DIR}"
fi

echo "[3/8] Building MTProxy..."
make -C "${INSTALL_DIR}"
MT_BINARY="${INSTALL_DIR}/objs/bin/mtproto-proxy"

if [[ ! -x "${MT_BINARY}" ]]; then
  echo "MTProxy build failed: binary not found at ${MT_BINARY}"
  exit 1
fi

echo "[4/8] Preparing config files..."
mkdir -p "${CONFIG_DIR}"
curl -fsSL https://core.telegram.org/getProxySecret -o "${CONFIG_DIR}/proxy-secret"
curl -fsSL https://core.telegram.org/getProxyConfig -o "${CONFIG_DIR}/proxy-multi.conf"

if ! id -u "${MT_USER}" >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin "${MT_USER}"
fi

MT_SECRET="$(openssl rand -hex 16)"

PUBLIC_IP="$(curl -fsS4 https://ifconfig.me || true)"
if [[ -z "${PUBLIC_IP}" ]]; then
  PUBLIC_IP="$(hostname -I | awk '{print $1}')"
fi
if [[ -z "${PUBLIC_IP}" ]]; then
  echo "Cannot detect public IP automatically. Set manually after install in ${ENV_FILE}."
  PUBLIC_IP="YOUR_SERVER_IP"
fi

cat > "${ENV_FILE}" <<EOF
MT_PROXY_BIN=${MT_BINARY}
MT_CONFIG_DIR=${CONFIG_DIR}
MT_SECRET=${MT_SECRET}
PROXY_PORT=${PROXY_PORT}
STATS_PORT=${STATS_PORT}
MT_WORKERS=${WORKERS}
EOF

chmod 600 "${ENV_FILE}"
chmod 644 "${CONFIG_DIR}/proxy-secret" "${CONFIG_DIR}/proxy-multi.conf"

echo "[5/8] Writing MTProxy runner..."
cat > "${RUNNER_BIN}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec "${MT_PROXY_BIN}" \
  -p "${STATS_PORT}" \
  -H "${PROXY_PORT}" \
  -S "${MT_SECRET}" \
  --aes-pwd "${MT_CONFIG_DIR}/proxy-secret" "${MT_CONFIG_DIR}/proxy-multi.conf" \
  -M "${MT_WORKERS}"
EOF

chmod 755 "${RUNNER_BIN}"

echo "[6/8] Writing systemd service..."
cat > "${SYSTEMD_UNIT}" <<EOF
[Unit]
Description=Telegram MTProto Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${MT_USER}
Group=${MT_USER}
EnvironmentFile=${ENV_FILE}
ExecStart=${RUNNER_BIN}
Restart=always
RestartSec=3
NoNewPrivileges=true
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "[7/8] Starting service..."
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
systemctl --no-pager --full status "${SERVICE_NAME}" || true

TG_LINK="tg://proxy?server=${PUBLIC_IP}&port=${PROXY_PORT}&secret=${MT_SECRET}"
HTTP_LINK="https://t.me/proxy?server=${PUBLIC_IP}&port=${PROXY_PORT}&secret=${MT_SECRET}"
CONNECTION_FILE="${CONFIG_DIR}/connection.txt"

cat > "${CONNECTION_FILE}" <<EOF
SECRET=${MT_SECRET}
HTTP_LINK=${HTTP_LINK}
TG_LINK=${TG_LINK}
EOF
chmod 600 "${CONNECTION_FILE}"

echo "[8/8] Done."
echo
echo "Secret:"
echo "${MT_SECRET}"
echo
echo "Telegram link:"
echo "${HTTP_LINK}"
echo
echo "Direct tg:// link:"
echo "${TG_LINK}"
echo
echo "Saved to:"
echo "${CONNECTION_FILE}"
