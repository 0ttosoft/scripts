# scripts

### To delete all shell command history from an Ubuntu server (for Bash and Zsh) as well as clear user activity logs
```bash
curl -sL https://raw.githubusercontent.com/0ttosoft/scripts/main/remove-shell-history.sh | bash
```
```bash
history -c
history -w
rm -f ~/.bash_history
```
---
### Docker, Git, Kind, kubectl installation
```bash
curl -sL https://raw.githubusercontent.com/0ttosoft/scripts/main/install.sh | bash
```
