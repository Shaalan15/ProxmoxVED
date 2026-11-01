#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/community-scripts/DevScripts/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Abdelrahman Deiab (Shaalan15)
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/huggingface/chat-ui

APP="HuggingFace-Chat-UI"
var_tags="${var_tags:-ai;chat}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified

export var_openai_base_url="${var_openai_base_url:-}"
export var_openai_api_key="${var_openai_api_key:-}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/huggingface-chat-ui ]]; then
    msg_error "No Hugging Face Chat UI Installation Found!"
    exit
  fi

  if check_for_gh_release "huggingface-chat-ui" "huggingface/chat-ui"; then
    msg_info "Stopping Hugging Face Chat UI"
    systemctl stop huggingface-chat-ui
    msg_ok "Stopped Hugging Face Chat UI"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "huggingface-chat-ui" "huggingface/chat-ui" "tarball"
    NODE_VERSION="24" NODE_MODULE="dotenv-cli" setup_nodejs

    msg_info "Building Hugging Face Chat UI"
    cd /opt/huggingface-chat-ui
    $STD npm ci
    $STD npm run build
    msg_ok "Built Hugging Face Chat UI"

    msg_info "Starting Hugging Face Chat UI"
    systemctl start huggingface-chat-ui
    msg_ok "Started Hugging Face Chat UI"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}https://${IP}${CL}"
