#!/usr/bin/env bash
set -euo pipefail

echo "🚨 Removing shell history and major log files..."

# Remove shell history for current user
history -c || true
history -w || true
rm -f ~/.bash_history ~/.zsh_history || true

# Remove history for all users (excluding system users)
for dir in /home/* /root; do
  if [ -d "$dir" ]; then
    sudo rm -f "$dir/.bash_history" "$dir/.zsh_history" 2>/dev/null || true
  fi
done

# Remove major system log files
sudo rm -f /var/log/auth.log /var/log/syslog /var/log/kern.log /var/log/wtmp /var/log/btmp 2>/dev/null || true

# Truncate all .log files in /var/log/
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null

echo "✅ Shell history and log files removed."
