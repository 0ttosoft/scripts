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
    arm64|aarch64) echo "arm64" ;;
    *) log "ERROR" "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

get_os() {
  case "$(uname -s)" in
    Linux*) echo "linux" ;;
    Darwin*) echo "darwin" ;;
    *) log "ERROR" "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac
}

detect_pkg_manager() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if command -v brew &>/dev/null; then
      echo "brew"
    else
      log "ERROR" "Homebrew not found. Install it from https://brew.sh/"
      exit 1
    fi
  elif command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v yum &>/dev/null; then
    echo "yum"
  else
    log "ERROR" "No supported package manager found (apt, yum, dnf, brew)."
    exit 1
  fi
}

ARCH=$(get_arch)
OS=$(get_os)
PKG_MANAGER=$(detect_pkg_manager)

log "INFO" "🚀 Starting installation of Docker, Git, Kind, kubectl, Helm, and k9s..."
log "INFO" "Detected OS: $OS | Arch: $ARCH | Package Manager: $PKG_MANAGER"

prompt_update() {
  local name="$1"
  read -rp "Update available for $name. Do you want to update? [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

### 1. Docker ###
if [[ "$OS" == "linux" ]]; then
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
  sudo usermod -aG docker "$USER" || true
  log "INFO" "ℹ️ Logout/login or run 'newgrp docker' to apply group changes."
else
  if ! command -v docker &>/dev/null; then
    log "INFO" "📦 Installing Docker Desktop (MacOS)..."
    brew install --cask docker
  else
    log "INFO" "✅ Docker already installed (check Docker Desktop app)."
  fi
fi

### 2. Git ###
if ! command -v git &>/dev/null; then
  log "INFO" "📦 Installing Git..."
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt-get update -y
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:git-core/ppa
    sudo apt-get update -y
    sudo apt-get install -y git
  elif [[ "$PKG_MANAGER" == "brew" ]]; then
    brew install git
  else
    sudo $PKG_MANAGER install -y git
  fi

  if command -v git &>/dev/null; then
      log "INFO" "✅ Git installed successfully: $(git --version)"
  else
      log "ERROR" "Git installation failed or not found in PATH"
  fi
else
  log "INFO" "🔄 Git already installed: $(git --version)"
fi

### 3. kubectl ###
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt | tr -d 'v')
INSTALLED_KUBECTL=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' | tr -d 'v' || true)
if [[ "$INSTALLED_KUBECTL" != "$KUBECTL_VERSION" ]]; then
  if prompt_update "kubectl"; then
    log "INFO" "📦 Installing/Upgrading kubectl $KUBECTL_VERSION..."
    curl -L "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" -o kubectl
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
  else
    log "INFO" "⏭ Skipping kubectl update."
  fi
else
  log "INFO" "✅ kubectl is already up-to-date."
fi

### 4. Kind ###
KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | cut -d '"' -f4)
INSTALLED_KIND=$(kind --version 2>/dev/null | awk '{print $2}' || true)
if [[ "$INSTALLED_KIND" != "$KIND_VERSION" ]]; then
  if prompt_update "Kind"; then
    log "INFO" "📦 Installing/Upgrading Kind $KIND_VERSION..."
    curl -L "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${ARCH}" -o kind
    chmod +x kind
    sudo mv kind /usr/local/bin/
  else
    log "INFO" "⏭ Skipping Kind update."
  fi
else
  log "INFO" "✅ Kind is already up-to-date."
fi

### 5. Helm ###
HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f4)
INSTALLED_HELM=$(helm version --short --client 2>/dev/null | cut -d '+' -f1 || true)
if [[ "$INSTALLED_HELM" != "$HELM_VERSION" ]]; then
  if prompt_update "Helm"; then
    log "INFO" "📦 Installing/Upgrading Helm $HELM_VERSION..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
      brew install helm || brew upgrade helm
    else
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
  else
    log "INFO" "⏭ Skipping Helm update."
  fi
else
  log "INFO" "✅ Helm is already up-to-date."
fi

### 6. k9s ###
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f4)
INSTALLED_K9S=$(k9s version -s 2>/dev/null | head -n1 | awk '{print $2}' || true)
if [[ "$INSTALLED_K9S" != "$K9S_VERSION" ]]; then
  if prompt_update "k9s"; then
    log "INFO" "📦 Installing/Upgrading k9s $K9S_VERSION..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
      brew install derailed/k9s/k9s || brew upgrade k9s
    else
      curl -L "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${OS}_${ARCH}.tar.gz" -o k9s.tar.gz
      tar -xzf k9s.tar.gz k9s
      sudo install -o root -g root -m 0755 k9s /usr/local/bin/k9s
      rm -f k9s k9s.tar.gz
    fi
  else
    log "INFO" "⏭ Skipping k9s update."
  fi
else
  log "INFO" "✅ k9s is already up-to-date."
fi

log "INFO" ""
log "INFO" "🎉 Installation Completed! Installed Versions:"
docker --version 2>/dev/null | tee -a "$LOG_FILE" || true
git --version 2>/dev/null | tee -a "$LOG_FILE" || true
kubectl version --client --short 2>/dev/null | tee -a "$LOG_FILE" || true
kind --version 2>/dev/null | tee -a "$LOG_FILE" || true
helm version --short 2>/dev/null | tee -a "$LOG_FILE" || true
k9s version -s 2>/dev/null | head -n1 | tee -a "$LOG_FILE" || true
