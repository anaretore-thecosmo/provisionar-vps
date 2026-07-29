#!/usr/bin/env bash
# Cria um projeto ISOLADO, a prova de leigo. Impede o caso "um app parar dentro de outro".
# Uso: bash novo-projeto.sh <nome> <porta>
set -euo pipefail

NOME="${1:-}"; PORTA="${2:-}"
BASE="/var/www"
PORTAS="/root/PORTAS.md"

[ -z "$NOME" ] || [ -z "$PORTA" ] && { echo "Uso: novo-projeto.sh <nome> <porta>"; exit 1; }

# TRAVA 0: nome seguro (so letras, numeros, hifen e underscore). Bloqueia / e .. (injecao de caminho)
[[ "$NOME" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "!! Nome invalido. Use so letras, numeros, - e _."; exit 1; }
[[ "$PORTA" =~ ^[0-9]+$ ]]        || { echo "!! Porta deve ser numero."; exit 1; }

# TRAVA 1: recusa criar dentro de outro repositorio git
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "!! Voce esta DENTRO de um projeto git ($(git rev-parse --show-toplevel))."
  echo "   Saia primeiro (cd $BASE). Um projeto NUNCA nasce dentro de outro."
  exit 1
fi

DIR="$BASE/$NOME"
# TRAVA 2: nao sobrescreve projeto existente
[ -e "$DIR" ] && { echo "!! '$DIR' ja existe. Escolha outro nome."; exit 1; }

# TRAVA 3: porta ja usada?
if [ -f "$PORTAS" ] && grep -qE "^\| *$PORTA " "$PORTAS"; then
  echo "!! Porta $PORTA ja esta no PORTAS.md. Escolha outra."; exit 1
fi

mkdir -p "$DIR"
cat > "$DIR/.gitignore" <<'GI'
.env
*.key
*.pem
secrets/
node_modules/
dist/
*.log
GI
: > "$DIR/.env"
chmod 600 "$DIR/.env"

# registra a porta
[ -f "$PORTAS" ] || printf "# Registro de Portas\n\n| Porta | Projeto |\n|---|---|\n" > "$PORTAS"
echo "| $PORTA | $NOME |" >> "$PORTAS"

echo "OK. Projeto isolado criado em $DIR"
echo " - .gitignore com .env protegido"
echo " - .env vazio, permissao 600 (preencha os segredos aqui, nunca no codigo)"
echo " - porta $PORTA registrada em $PORTAS"
echo "Proximo: cd $DIR ; git init ; e suba com 'pm2 start ... --name $NOME'"
