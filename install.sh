#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="${HOME}/docker_kind_kubectl_install.log"

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

log "INFO" "🚀 Starting Docker, Git, Kind, kubectl installation..."

# 1. Docker (Engine v28+)
DOCKER_MIN_VERSION="28."
INSTALLED_DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | tr -d '\n\t\r ' || true)
if [[ "$INSTALLED_DOCKER_VERSION" != "$DOCKER_MIN_VERSION"* ]]; then
  log "INFO" "📦 Installing/Upgrading Docker (Engine v28+)..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh | tee -a "$LOG_FILE"
  rm get-docker.sh
else
  log "INFO" "✅ Docker is already latest or up-to-date."
fi

# Docker group addition and session refresh
log "INFO" "👤 Adding current user to docker group..."
sudo usermod -aG docker "$USER"
if command -v newgrp &>/dev/null; then
  # Only works interactively, so inform user
  log "INFO" "If you have just been added to the docker group, please log out and log in again, or start a new shell (newgrp docker) to use docker without sudo."
else
  log "WARN" "newgrp not available. Please log out and log in again for docker group changes to apply."
fi

# 2. Git (latest from git-core PPA)
INSTALLED_GIT_VERSION=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tr -d '\n\t\r ' || echo "")
if ! command -v git &>/dev/null; then
  log "INFO" "📦 Git not found. Installing via git-core PPA..."
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update -y
  sudo apt-get install -y git
  INSTALLED_GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tr -d '\n\t\r ')
  log "INFO" "✅ Git $INSTALLED_GIT_VERSION installed."
else
  log "INFO" "📦 Checking for Git updates via git-core PPA..."
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update -y
  sudo apt-get install -y git
  INSTALLED_GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tr -d '\n\t\r ')
  log "INFO" "✅ Git is now $INSTALLED_GIT_VERSION (latest from PPA)."
fi

# 3. Kind (v0.30.0)
REQUIRED_KIND_VERSION="0.30.0"
INSTALLED_KIND_VERSION=$(kind --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tr -d '\n\t\r ' || true)
if [[ "$INSTALLED_KIND_VERSION" != "$REQUIRED_KIND_VERSION" ]]; then
  log "INFO" "📦 Installing/Upgrading Kind to $REQUIRED_KIND_VERSION..."
  KIND_ARCH=$(get_arch)
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-${KIND_ARCH}"
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind | tee -a "$LOG_FILE"
  log "INFO" "✅ Kind $REQUIRED_KIND_VERSION installed/updated."
else
  log "INFO" "✅ Kind is already at $REQUIRED_KIND_VERSION."
fi

# 4. kubectl (latest, with checksum validation & whitespace-trim logic)
LATEST_KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt | tr -d '\n\t\r ')
INSTALLED_KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tr -d '\n\t\r ' || echo "")
if [[ "$INSTALLED_KUBECTL_VERSION" != "$LATEST_KUBECTL_VERSION" && "$LATEST_KUBECTL_VERSION" != "" ]]; then
  log "INFO" "📦 Installing/Upgrading kubectl to $LATEST_KUBECTL_VERSION..."
  KUBECTL_ARCH=$(get_arch)
  url="https://dl.k8s.io/release/${LATEST_KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"
  curl -LO "$url"
  curl -LO "$url.sha256"
  if echo "$(<kubectl.sha256) kubectl" | sha256sum --check; then
    log "INFO" "kubectl checksum OK."
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl | tee -a "$LOG_FILE"
    rm -f kubectl kubectl.sha256
    log "INFO" "✅ kubectl $LATEST_KUBECTL_VERSION installed/updated."
  else
    log "ERROR" "kubectl checksum failed!"
    rm -f kubectl kubectl.sha256
    exit 1
  fi
else
  log "INFO" "✅ kubectl is already at latest ($LATEST_KUBECTL_VERSION)."
fi

log "INFO" ""
log "INFO" "🔍 Installed Versions:"
docker --version | tee -a "$LOG_FILE"
git --version | tee -a "$LOG_FILE"
kind --version | tee -a "$LOG_FILE"
kubectl version --client --output=yaml | tee -a "$LOG_FILE"
log "INFO" ""
log "INFO" "🎉 Docker, Git, Kind, and kubectl installation complete!"
