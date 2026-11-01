#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Abdelrahman Deiab (Shaalan15)
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/huggingface/chat-ui

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

if [[ -z "${var_openai_base_url:-}" ]]; then
  read -r -p "${TAB3}OpenAI-compatible base URL [https://router.huggingface.co/v1]: " var_openai_base_url || true
fi
var_openai_base_url="${var_openai_base_url:-https://router.huggingface.co/v1}"
if [[ -z "${var_openai_api_key:-}" ]]; then
  read -r -s -p "${TAB3}API key for that endpoint (Enter for none): " var_openai_api_key || true
  echo
fi

msg_info "Installing Dependencies"
$STD apt install -y \
  libgomp1 \
  nginx
msg_ok "Installed Dependencies"

MONGO_VERSION="8.0" setup_mongodb
NODE_VERSION="24" NODE_MODULE="dotenv-cli" setup_nodejs
fetch_and_deploy_gh_release "huggingface-chat-ui" "huggingface/chat-ui" "tarball"

msg_info "Building Hugging Face Chat UI"
cd /opt/huggingface-chat-ui
$STD npm ci
$STD npm run build
msg_ok "Built Hugging Face Chat UI"

msg_info "Configuring Hugging Face Chat UI"
cat <<EOF >/opt/huggingface-chat-ui.env
OPENAI_BASE_URL=${var_openai_base_url}
OPENAI_API_KEY=${var_openai_api_key}
MONGODB_URL=mongodb://127.0.0.1:27017
HOST=127.0.0.1
EOF
chmod 600 /opt/huggingface-chat-ui.env
msg_ok "Configured Hugging Face Chat UI"

msg_info "Configuring Nginx"
create_self_signed_cert "huggingface-chat-ui"
# HTTPS because the session cookie is Secure by default and adding MCP servers needs crypto.randomUUID()
cat <<'EOF' >/etc/nginx/sites-available/huggingface-chat-ui
server {
    listen 80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl default_server;
    http2 on;
    server_name _;

    ssl_certificate /etc/ssl/huggingface-chat-ui/huggingface-chat-ui.crt;
    ssl_certificate_key /etc/ssl/huggingface-chat-ui/huggingface-chat-ui.key;
    client_max_body_size 15M;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_buffering off;
    }
}
EOF
nginx_enable_site "huggingface-chat-ui"
msg_ok "Configured Nginx"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/huggingface-chat-ui.service
[Unit]
Description=Hugging Face Chat UI
After=network.target mongod.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/huggingface-chat-ui
ExecStart=/usr/bin/dotenv -e /opt/huggingface-chat-ui.env -e .env -- /usr/bin/node --dns-result-order=ipv4first build
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now huggingface-chat-ui
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
