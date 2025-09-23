#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="${HOME}/docker_git_kind_kubectl_helm_k9s_install.log"

log() {
  level="$1"
  msg="$2"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $msg" | tee -a "$LOG_FILE"
}

prompt_update() {
  tool="$1"
  read -rp "$tool is already installed. Do you want to update it? (y/N): " choice
  case "$choice" in
    y|Y) return 0 ;;  # Update
    *) return 1 ;;    # Skip
  esac
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

### 1. Docker ###
if ! command -v docker &>/dev/null; then
    log "INFO" "📦 Installing Docker..."
    if [[ "$OS" == "linux" ]]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh | tee -a "$LOG_FILE"
        rm get-docker.sh
        sudo usermod -aG docker "$USER" || true
        log "INFO" "ℹ️ Logout/login or run 'newgrp docker' to apply group changes."
    else
        brew install --cask docker
    fi
else
    if prompt_update "Docker"; then
        log "INFO" "📦 Updating Docker..."
        if [[ "$OS" == "linux" ]]; then
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh | tee -a "$LOG_FILE"
            rm get-docker.sh
        else
            brew upgrade --cask docker
        fi
    else
        log "INFO" "✅ Skipping Docker update."
    fi
fi

### 2. Git ###
if ! command -v git &>/dev/null && [[ -x /usr/bin/git ]]; then
    export PATH=$PATH:/usr/bin
    hash -r
    log "INFO" "🔧 Added /usr/bin to PATH to detect Git."
fi

if ! command -v git &>/dev/null; then
  log "INFO" "📦 Installing Git..."
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt-get update -y && sudo apt-get install -y git
  elif [[ "$PKG_MANAGER" == "brew" ]]; then
    brew install git
  else
    sudo $PKG_MANAGER install -y git
  fi
else
  if prompt_update "Git"; then
    log "INFO" "🔄 Updating Git..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
      sudo apt-get update -y && sudo apt-get install -y git
    elif [[ "$PKG_MANAGER" == "brew" ]]; then
      brew upgrade git || true
    else
      sudo $PKG_MANAGER install -y git
    fi
    export PATH=$PATH:/usr/bin:/usr/local/bin
    hash -r
  else
    log "INFO" "✅ Skipping Git update."
  fi
fi

### 3. kubectl ###
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
if ! command -v kubectl &>/dev/null; then
  log "INFO" "📦 Installing kubectl $KUBECTL_VERSION..."
  curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" -o kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  if prompt_update "kubectl"; then
    log "INFO" "📦 Updating kubectl..."
    curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" -o kubectl
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
  else
    log "INFO" "✅ Skipping kubectl update."
  fi
fi

### 4. Kind ###
KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | cut -d '"' -f4)
if ! command -v kind &>/dev/null; then
  log "INFO" "📦 Installing Kind $KIND_VERSION..."
  curl -L "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${ARCH}" -o kind
  chmod +x kind
  sudo mv kind /usr/local/bin/
else
  if prompt_update "Kind"; then
    log "INFO" "📦 Updating Kind $KIND_VERSION..."
    curl -L "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${ARCH}" -o kind
    chmod +x kind
    sudo mv kind /usr/local/bin/
  else
    log "INFO" "✅ Skipping Kind update."
  fi
fi

### 5. Helm ###
HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f4)
if ! command -v helm &>/dev/null; then
  log "INFO" "📦 Installing Helm $HELM_VERSION..."
  if [[ "$PKG_MANAGER" == "brew" ]]; then
    brew install helm
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
else
  if prompt_update "Helm"; then
    log "INFO" "📦 Updating Helm $HELM_VERSION..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
      brew upgrade helm
    else
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
  else
    log "INFO" "✅ Skipping Helm update."
  fi
fi

### 6. k9s ###
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f4)
if ! command -v k9s &>/dev/null; then
  log "INFO" "📦 Installing k9s $K9S_VERSION..."
  if [[ "$PKG_MANAGER" == "brew" ]]; then
    brew install derailed/k9s/k9s
  else
    curl -L "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${OS}_${ARCH}.tar.gz" -o k9s.tar.gz
    tar -xzf k9s.tar.gz k9s
    sudo install -o root -g root -m 0755 k9s /usr/local/bin/k9s
    rm -f k9s k9s.tar.gz
  fi
else
  if prompt_update "k9s"; then
    log "INFO" "📦 Updating k9s $K9S_VERSION..."
    if [[ "$PKG_MANAGER" == "brew" ]]; then
      brew upgrade k9s
    else
      curl -L "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${OS}_${ARCH}.tar.gz" -o k9s.tar.gz
      tar -xzf k9s.tar.gz k9s
      sudo install -o root -g root -m 0755 k9s /usr/local/bin/k9s
      rm -f k9s k9s.tar.gz
    fi
  else
    log "INFO" "✅ Skipping k9s update."
  fi
fi

log "INFO" ""
log "INFO" "🎉 Installation Completed! Installed Versions:"
docker --version 2>/dev/null | tee -a "$LOG_FILE" || true
git --version 2>/dev/null | tee -a "$LOG_FILE" || true
kubectl version --client --short 2>/dev/null | tee -a "$LOG_FILE" || true
kind --version 2>/dev/null | tee -a "$LOG_FILE" || true
helm version --short 2>/dev/null | tee -a "$LOG_FILE" || true
k9s version -s 2>/dev/null | head -n1 | tee -a "$LOG_FILE" || true
