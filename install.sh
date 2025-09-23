#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="${HOME}/docker_git_kind_kubectl_helm_k9s_install.log"

log() {
  level="$1"
  msg="$2"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $msg" | tee -a "$LOG_FILE"
}

get_arch() {
  case "$(uname -m)" in
    x86_64) echo "amd64" ;;
    aarch64) echo "arm64" ;;
    *) log "ERROR" "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

detect_pkg_manager() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v yum &>/dev/null; then
    echo "yum"
  else
    log "ERROR" "No supported package manager found (apt, yum, dnf)."
    exit 1
  fi
}

ARCH=$(get_arch)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
PKG_MANAGER=$(detect_pkg_manager)

log "INFO" "🚀 Starting installation of Docker, Git, Kind, kubectl, Helm, and k9s..."
log "INFO" "Detected package manager: $PKG_MANAGER"

### 1. Docker ###
DOCKER_MIN_VERSION="28."
INSTALLED_DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || true)
if [[ "$INSTALLED_DOCKER_VERSION" != "$DOCKER_MIN_VERSION"* ]]; then
  log "INFO" "📦 Installing/Upgrading Docker (Engine v28+)..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh | tee -a "$LOG_FILE"
  rm get-docker.sh
else
  log "INFO" "✅ Docker is already up-to-date."
fi

log "INFO" "👤 Adding current user to docker group..."
sudo usermod -aG docker "$USER" || true
log "INFO" "ℹ️ Logout/login or run 'newgrp docker' to apply group changes."

### 2. Git ###
if ! command -v git &>/dev/null; then
  log "INFO" "📦 Installing Git..."
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt-get update -y && sudo apt-get install -y git
  else
    sudo $PKG_MANAGER install -y git
  fi
else
  log "INFO" "🔄 Updating Git..."
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt-get update -y && sudo apt-get install -y git
  else
    sudo $PKG_MANAGER install -y git
  fi
fi

### 3. kubectl ###
KUBECTL_VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)
INSTALLED_KUBECTL=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' || true)
if [[ "$INSTALLED_KUBECTL" != "$KUBECTL_VERSION" ]]; then
  log "INFO" "📦 Installing/Upgrading kubectl $KUBECTL_VERSION..."
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
else
  log "INFO" "✅ kubectl is already up-to-date."
fi

### 4. Kind ###
KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | cut -d '"' -f4)
INSTALLED_KIND=$(kind --version 2>/dev/null | awk '{print $2}' || true)
if [[ "$INSTALLED_KIND" != "$KIND_VERSION" ]]; then
  log "INFO" "📦 Installing/Upgrading Kind $KIND_VERSION..."
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${ARCH}"
  sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
  rm kind
else
  log "INFO" "✅ Kind is already up-to-date."
fi

### 5. Helm ###
HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f4)
INSTALLED_HELM=$(helm version --short --client 2>/dev/null | cut -d '+' -f1 || true)
if [[ "$INSTALLED_HELM" != "$HELM_VERSION" ]]; then
  log "INFO" "📦 Installing/Upgrading Helm $HELM_VERSION..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  log "INFO" "✅ Helm is already up-to-date."
fi

### 6. k9s ###
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f4)
INSTALLED_K9S=$(k9s version -s 2>/dev/null | head -n1 | awk '{print $2}' || true)
if [[ "$INSTALLED_K9S" != "$K9S_VERSION" ]]; then
  log "INFO" "📦 Installing/Upgrading k9s $K9S_VERSION..."
  curl -Lo k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${OS}_${ARCH}.tar.gz"
  tar -xzf k9s.tar.gz k9s
  sudo install -o root -g root -m 0755 k9s /usr/local/bin/k9s
  rm -f k9s k9s.tar.gz
else
  log "INFO" "✅ k9s is already up-to-date."
fi

log "INFO" ""
log "INFO" "🎉 Installation Completed! Installed Versions:"
docker --version | tee -a "$LOG_FILE"
git --version | tee -a "$LOG_FILE"
kubectl version --client --short | tee -a "$LOG_FILE"
kind --version | tee -a "$LOG_FILE"
helm version --short | tee -a "$LOG_FILE"
k9s version -s | head -n1 | tee -a "$LOG_FILE"
