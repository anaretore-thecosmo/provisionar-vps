#!/usr/bin/env bash
# Auditoria READ-ONLY de uma VPS de origem. Nao altera nada no servidor.
# Uso: bash auditar-vps.sh <ssh-alias>    (ex.: bash auditar-vps.sh cosmo)
set -euo pipefail

ALIAS="${1:-}"
if [ -z "$ALIAS" ]; then
  echo "ERRO: informe o alias SSH da VPS de origem. Ex.: bash auditar-vps.sh cosmo" >&2
  exit 1
fi

echo "### Auditando '$ALIAS' (somente leitura) ###"
ssh -o BatchMode=yes -o ConnectTimeout=15 "$ALIAS" 'bash -s' <<'REMOTE'
echo "===== SISTEMA ====="
grep PRETTY /etc/os-release; uname -r
echo -n "vCPU: "; nproc
free -h | grep -E "Mem|Swap"
df -h / | tail -1
uptime

echo "===== RUNTIMES ====="
for b in node npm python3 docker git pm2 certbot; do
  printf "%-8s " "$b:"; command -v "$b" >/dev/null 2>&1 && $b --version 2>/dev/null | head -1 || echo MISSING
done
printf "nginx:   "; nginx -v 2>&1 || echo MISSING

echo "===== PM2 (apps rodando) ====="
pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{JSON.parse(d).forEach(p=>console.log(p.name,"| "+p.pm2_env.status,"| restarts:"+p.pm2_env.restart_time,"| "+Math.round((p.monit?.memory||0)/1048576)+"MB","| "+p.pm2_env.pm_cwd))}catch(e){console.log("(pm2 vazio)")}})' 2>/dev/null || echo "(pm2 ausente)"
printf "startup no boot: "; systemctl is-enabled pm2-root 2>/dev/null || echo "NAO configurado"

echo "===== SEGURANCA ====="
printf "ufw: "; ufw status 2>/dev/null | head -1 || echo "AUSENTE"
ufw status 2>/dev/null | grep -E "ALLOW|DENY" | sed 's/^/  /'
printf "fail2ban: "; systemctl is-active fail2ban 2>/dev/null || echo "AUSENTE"
printf "unattended-upgrades: "; dpkg -l 2>/dev/null | grep -q unattended-upgrades && echo INSTALADO || echo AUSENTE
echo "SSH login:"; { grep -hE "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | sort -u | sed 's/^/  /'; }
printf "swap: "; swapon --show 2>/dev/null | tail -n +2 || echo "NENHUM (0 configurado)"

echo "===== NGINX (dominios) ====="
ls /etc/nginx/sites-enabled/ 2>/dev/null | sed 's/^/  /'

echo "===== SSL (certbot) ====="
printf "autorenew: "; systemctl is-enabled certbot.timer 2>/dev/null || echo "NAO"
certbot certificates 2>/dev/null | grep -E "Certificate Name|Expiry" | sed 's/^[ \t]*/  /'

echo "===== DOCKER ====="
docker ps --format '  {{.Names}} | {{.Status}}' 2>/dev/null || echo "  (sem docker)"

echo "===== CRON (root) ====="
crontab -l 2>/dev/null | grep -vE "^#|^$" | sed 's/^/  /' || echo "  (sem cron)"

echo "===== LOGROTATE ====="
ls /etc/logrotate.d/ 2>/dev/null | tr '\n' ' '; echo
REMOTE
echo "### Fim da auditoria ###"
