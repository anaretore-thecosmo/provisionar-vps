#!/usr/bin/env bash
# ============================================================
#  SETUP DE VPS NOVA: Camadas 1 (base+seguranca) e 2 (stack)
#  Roda NA VPS nova, como root. Idempotente: pode rodar de novo.
#  NAO instala nada especifico de projeto. NAO contem segredos.
# ============================================================
set -euo pipefail

# ---- variaveis ajustaveis ----
SWAP_GB="${SWAP_GB:-2}"                 # tamanho do swap em GB
TIMEZONE="${TIMEZONE:-America/Sao_Paulo}"
NODE_MAJOR="${NODE_MAJOR:-22}"
INSTALL_DOCKER="${INSTALL_DOCKER:-no}"  # "yes" so se a VPS for usar containers
# -------------------------------

log(){ echo -e "\n\033[1;36m>>> $1\033[0m"; }

[ "$(id -u)" -eq 0 ] || { echo "Rode como root."; exit 1; }
export DEBIAN_FRONTEND=noninteractive

log "1/12  Atualizando o sistema"
apt-get update -y && apt-get upgrade -y

log "2/12  Fuso horario e locale pt-BR"
timedatectl set-timezone "$TIMEZONE" || true
apt-get install -y locales
sed -i 's/^# *pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen || true
locale-gen pt_BR.UTF-8 || true
update-locale LANG=pt_BR.UTF-8 || true

log "3/12  Ferramentas base + seguranca de segredos (age, gitleaks)"
apt-get install -y curl git ufw fail2ban unattended-upgrades ca-certificates gnupg logrotate age jq sqlite3
# gitleaks: porteiro que bloqueia commit com chave/token/senha
if ! command -v gitleaks >/dev/null; then
  GL_VER="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r .tag_name | tr -d v)"
  ARCH="$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')"
  curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin gitleaks 2>/dev/null && chmod +x /usr/local/bin/gitleaks || echo "  (gitleaks: instale manualmente se falhar)"
fi
# hook global: todo 'git commit' passa pelo gitleaks antes
git config --global core.hooksPath /root/.git-hooks
mkdir -p /root/.git-hooks
cat > /root/.git-hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
command -v gitleaks >/dev/null || exit 0
gitleaks protect --staged --redact -v || { echo "!! COMMIT BLOQUEADO: segredo detectado. Remova antes de commitar."; exit 1; }
HOOK
chmod +x /root/.git-hooks/pre-commit

log "4/12  Swap de ${SWAP_GB}GB"
if ! swapon --show | grep -q .; then
  fallocate -l "${SWAP_GB}G" /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_GB*1024))
  chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "vm.swappiness=10" > /etc/sysctl.d/99-swap.conf && sysctl -p /etc/sysctl.d/99-swap.conf
else
  echo "swap ja existe, pulando."
fi

log "5/12  Firewall (ufw): so 22, 80, 443"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp   >/dev/null
ufw allow 443/tcp  >/dev/null
ufw --force enable

log "6/12  fail2ban (protege o SSH de forca bruta)"
systemctl enable --now fail2ban

log "7/12  Atualizacoes de seguranca automaticas"
dpkg-reconfigure -f noninteractive unattended-upgrades || true
systemctl enable --now unattended-upgrades || true

log "8/12  Endurecendo o SSH (so com chave, sem senha)"
if [ -s /root/.ssh/authorized_keys ]; then
  cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'SSHC'
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin prohibit-password
SSHC
  sshd -t && systemctl reload ssh && echo "SSH endurecido."
else
  echo "!! AVISO: /root/.ssh/authorized_keys vazio. NAO desabilitei a senha para nao te trancar do lado de fora."
  echo "   Suba sua chave publica primeiro e rode este passo de novo."
fi

log "9/12  Node.js ${NODE_MAJOR} + PM2"
if ! command -v node >/dev/null || [ "$(node -v | grep -oE '[0-9]+' | head -1)" != "$NODE_MAJOR" ]; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
  apt-get install -y nodejs
fi
npm install -g pm2
pm2 startup systemd -u root --hp /root | tail -1 | bash || true

log "10/12  nginx + certbot (SSL automatico)"
apt-get install -y nginx
systemctl enable --now nginx
apt-get install -y certbot python3-certbot-nginx
systemctl enable --now certbot.timer || true

log "11/12  Log rotation dos logs de app (evita lotar o disco)"
cat > /etc/logrotate.d/apps <<'LR'
/var/log/*.log {
  weekly
  rotate 8
  compress
  missingok
  notifempty
  copytruncate
}
LR

log "12/12  Docker (opcional)"
# TRAVA DE MAQUINA: ha maquinas que recusam Docker por decisao consciente (menos
# superficie de ataque - tipico de servidor que guarda dado sensivel). Um "yes"
# digitado por engano na variavel nao pode furar essa decisao.
#
# Como marcar uma maquina destas, de dois jeitos:
#   1. arquivo /etc/vps-sem-docker
#        - vazio         -> esta maquina recusa Docker, seja qual for o hostname
#        - com hostnames -> um por linha; recusa se o hostname atual estiver la
#          (linha comecando com # e comentario)
#   2. variavel VPS_SEM_DOCKER="host1 host2"  -> recusa nesses hostnames
docker_recusado_nesta_maquina() {
  local host marcador linha
  host="$(hostname)"
  marcador=/etc/vps-sem-docker

  if [ -f "$marcador" ]; then
    # sem nenhuma linha util = marcador de presenca: vale para esta maquina
    if ! grep -qvE '^[[:space:]]*(#|$)' "$marcador"; then
      return 0
    fi
    while IFS= read -r linha; do
      linha="${linha%%#*}"
      linha="$(echo "$linha" | tr -d '[:space:]')"
      [ -n "$linha" ] && [ "$linha" = "$host" ] && return 0
    done < "$marcador"
  fi

  for linha in $VPS_SEM_DOCKER; do
    [ "$linha" = "$host" ] && return 0
  done

  return 1
}

if [ "$INSTALL_DOCKER" = "yes" ] && docker_recusado_nesta_maquina; then
  echo "!! RECUSADO: esta maquina esta marcada para nao receber Docker." >&2
  echo "   Origem da marca: /etc/vps-sem-docker ou VPS_SEM_DOCKER. Veja a decisao no RUNBOOK.md." >&2
  INSTALL_DOCKER=no
fi
if [ "$INSTALL_DOCKER" = "yes" ]; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
else
  echo "pulado (INSTALL_DOCKER=no). Menos superficie de ataque."
fi

log "PRONTO. Base e stack instaladas."
echo "Confira: node -v ; pm2 -v ; nginx -v ; ufw status ; swapon --show"
echo "Proximo: subir os apps da clinica e rodar 'certbot --nginx -d SEU.DOMINIO'."
