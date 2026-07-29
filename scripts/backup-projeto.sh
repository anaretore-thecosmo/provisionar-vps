#!/usr/bin/env bash
# Backup 3-2-1 de um projeto: banco pelo metodo correto + cifra age + saida para fora da VPS.
# Uso:
#   bash backup-projeto.sh <dir-do-projeto> <chave-publica-age>        # faz o backup cifrado
#   bash backup-projeto.sh --verificar <arquivo.age> <chave-privada>   # testa a restauracao
set -euo pipefail

if [ "${1:-}" = "--verificar" ]; then
  ARQ="${2:?informe o .age}"; KEY="${3:?informe a chave privada age}"
  TMP="$(mktemp -d)"
  age -d -i "$KEY" "$ARQ" | tar -xz -C "$TMP"
  echo "Restaurado em $TMP. Conteudo:"; ls -la "$TMP"/*/ 2>/dev/null || ls -la "$TMP"
  echo ">> Backup abre e restaura. Verificado. (apague $TMP depois)"
  exit 0
fi

DIR="${1:?informe o diretorio do projeto}"
AGE_PUB="${2:?informe a chave publica age (para cifrar)}"
command -v age >/dev/null     || { echo "age nao instalado (rode o setup-vps.sh)."; exit 1; }
command -v sqlite3 >/dev/null || echo "aviso: sqlite3 ausente, bancos .db serao copiados sem hot-backup."

DIR="${DIR%/}"
NOME="$(basename "$DIR")"
OUT="/root/backups"; mkdir -p "$OUT"
STAMP="$(date +%Y%m%d-%H%M)"
STAGE="$(mktemp -d)"

# 1) copia os arquivos do projeto para a area de trabalho, sem lixo
tar -c --exclude=node_modules --exclude=dist --exclude=.git \
  -C "$(dirname "$DIR")" "$NOME" | tar -x -C "$STAGE"

# 2) banco SQLite: substitui a copia crua por um snapshot consistente (.backup, nunca cp)
if command -v sqlite3 >/dev/null; then
  find "$DIR" -maxdepth 3 -name "*.db" 2>/dev/null | while read -r db; do
    rel="${db#"$DIR"/}"
    mkdir -p "$STAGE/$NOME/$(dirname "$rel")"
    sqlite3 "$db" ".backup '$STAGE/$NOME/$rel'" 2>/dev/null || true
  done
fi

# 3) empacota e cifra com age (segredos e projeto ilegiveis fora da VPS)
tar -czf "$STAGE/pacote.tgz" -C "$STAGE" "$NOME"
FINAL="$OUT/${NOME}-${STAMP}.tar.gz.age"
age -r "$AGE_PUB" -o "$FINAL" "$STAGE/pacote.tgz"
rm -rf "$STAGE"

echo "Backup cifrado: $FINAL"
echo "Regra 3-2-1, agora leve 1 copia para FORA da VPS:"
echo "  baixe no seu computador:  scp <alias>:$FINAL ."
echo "  e/ou snapshot do provedor, e/ou storage externo"
echo "Codigo importante tambem vai para GitHub privado (sem .env)."
echo "Teste periodico:  backup-projeto.sh --verificar $FINAL <chave-privada-age>"
