#!/usr/bin/env bash
# Backup 3-2-1 de um projeto: banco pelo metodo correto + cifra age + saida para fora da VPS.
# Uso:
#   bash backup-projeto.sh <dir-do-projeto> <chave-publica-age>        # faz o backup cifrado
#   bash backup-projeto.sh --verificar <arquivo.age> <chave-privada>   # testa a restauracao
set -euo pipefail

# Um banco SQLite se reconhece pelo CABECALHO do arquivo, nunca pela extensao.
#
# Ate 17/08/2026 este script procurava `-name "*.db"`. Um banco chamado
# `.sqlite` ou `.sqlite3` - nome comum em projeto Node, que e a stack do Orbita -
# nao casava, e entao:
#   1) nao recebia snapshot: ia cru no tar, com o .db, o -wal e o -shm copiados
#      em momentos diferentes, sem atomicidade (o problema que o CLAUDE.md
#      descreve para o `cp`, valendo igual para o `tar`);
#   2) o --verificar nunca o abria, e respondia APROVADO sobre um banco que
#      jamais foi lido.
# Provado no ensaio de 17/08/2026: 8 KB de lixo binario chamado `dados.sqlite3`
# gerou backup sem reclamacao e o --verificar respondeu APROVADO com codigo 0.
# O mesmo lixo chamado `dados.db` foi corretamente rejeitado.
#
# Agora o nome do arquivo nao importa mais: vale o que esta dentro dele.
eh_sqlite() {
  [ -f "$1" ] || return 1
  [ "$(head -c 15 "$1" 2>/dev/null)" = "SQLite format 3" ]
}

# ...mas o nome ainda serve para UMA coisa: desconfiar.
# Trocar nome por cabecalho corrigiu o furo dos `.sqlite`/`.sqlite3`, e de quebra
# calou um alarme que existia antes: ate 17/08/2026 um `prontuarios.db` com lixo
# dentro ABORTAVA o backup; com a checagem so por cabecalho ele passou a
# atravessar em silencio, empacotado como arquivo comum, e o --verificar
# respondia APROVADO. Banco de paciente corrompido nao pode passar calado.
# Entao: cabecalho decide o que E banco; o nome decide o que MERECE BARULHO.
tem_nome_de_banco() {
  case "$1" in
    *.db|*.sqlite|*.sqlite3) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "${1:-}" = "--verificar" ]; then
  ARQ="${2:?informe o .age}"; KEY="${3:?informe a chave privada age}"
  TMP="$(mktemp -d)"
  age -d -i "$KEY" "$ARQ" | tar -xz -C "$TMP"

  # CAMINHO COMPLETO, sempre. A versao antiga imprimia `ls "$TMP"/*/`, que parecia
  # listar a raiz -- e quem conferisse apontava um nivel acima por engano. O sqlite3
  # CRIA um banco vazio em silencio quando o arquivo nao existe, e o integrity_check
  # de um banco vazio responde "ok". Ou seja: a conferencia dizia SIM para um backup
  # que nunca foi lido. Aconteceu neste servidor em 16/08/2026.
  echo "Restaurado em: $TMP"
  echo
  echo "--- arquivos (caminho completo) ---"
  find "$TMP" -type f -printf '%10s  %p\n' | sort -k2

  # todo banco encontrado e ABERTO e CONTADO, nao so listado.
  # Varre TODO arquivo do pacote e pergunta a cada um se e banco, em vez de
  # confiar no nome. Arquivo comum simplesmente nao casa e segue adiante.
  falhou=0
  achados=0
  while IFS= read -r db; do
    if ! eh_sqlite "$db"; then
      if tem_nome_de_banco "$db"; then
        echo
        echo "--- banco: $db ---"
        echo "  !! REPROVADO: tem nome de banco, mas nao ha cabecalho SQLite dentro."
        echo "     Ou o banco corrompeu, ou o nome engana. Olhe antes de confiar."
        falhou=1
      fi
      continue
    fi
    achados=$((achados + 1))
    echo
    echo "--- banco: $db ---"
    integ="$(sqlite3 "$db" 'PRAGMA integrity_check;' 2>&1 | head -1)"
    echo "  integridade : $integ"
    tabelas="$(sqlite3 "$db" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>&1)"
    echo "  tabelas     : $tabelas"
    if [ "$integ" != "ok" ] || [ "${tabelas:-0}" = "0" ]; then
      echo "  !! REPROVADO: banco vazio ou corrompido"
      falhou=1
    else
      sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null | while read -r t; do
        echo "     tabela '$t': $(sqlite3 "$db" "SELECT count(*) FROM \"$t\";" 2>/dev/null) linhas"
      done
    fi
  done < <(find "$TMP" -type f 2>/dev/null)

  echo
  if [ "$falhou" -eq 1 ]; then
    echo ">> REPROVOU. Este backup NAO restaura direito. Nao conte com ele."
    echo "   (apague $TMP depois)"
    exit 1
  fi
  # Dizer "os bancos tem conteudo" quando nenhum banco foi aberto e mentira
  # confortavel. Se nao havia banco no pacote, o texto tem que dizer isso.
  if [ "$achados" -eq 0 ]; then
    echo ">> APROVADO: abre e restaura. NENHUM banco SQLite no pacote - nao havia banco a conferir."
  else
    echo ">> APROVADO: abre, restaura, e os $achados banco(s) encontrado(s) tem conteudo."
  fi
  echo "   (apague $TMP depois)"
  exit 0
fi

DIR="${1:?informe o diretorio do projeto}"
AGE_PUB="${2:?informe a chave publica age (para cifrar)}"
command -v age >/dev/null     || { echo "age nao instalado (rode o setup-vps.sh)."; exit 1; }
command -v sqlite3 >/dev/null || echo "aviso: sqlite3 ausente, bancos SQLite serao copiados sem hot-backup."

DIR="${DIR%/}"
NOME="$(basename "$DIR")"
OUT="/root/backups"; mkdir -p "$OUT"
STAMP="$(date +%Y%m%d-%H%M)"
STAGE="$(mktemp -d)"

# 1) copia os arquivos do projeto para a area de trabalho, sem lixo
tar -c --exclude=node_modules --exclude=dist --exclude=.git \
  -C "$(dirname "$DIR")" "$NOME" | tar -x -C "$STAGE"

# 2) banco SQLite: substitui a copia crua por um snapshot consistente (.backup, nunca cp)
#    e CONFERE o snapshot. Um .backup que falhou no meio gera arquivo truncado que
#    so seria descoberto no dia da restauracao - tarde demais.
if command -v sqlite3 >/dev/null; then
  while IFS= read -r db; do
    rel="${db#"$DIR"/}"
    if ! eh_sqlite "$db"; then
      if tem_nome_de_banco "$db"; then
        echo "ERRO: '$rel' tem nome de banco, mas nao ha cabecalho SQLite dentro." >&2
        echo "      Ou o banco corrompeu, ou o nome engana. Backup ABORTADO." >&2
        exit 1
      fi
      continue
    fi
    mkdir -p "$STAGE/$NOME/$(dirname "$rel")"
    destino="$STAGE/$NOME/$rel"
    if ! sqlite3 "$db" ".backup '$destino'"; then
      echo "ERRO: snapshot do banco '$rel' falhou. Backup ABORTADO (melhor sem backup do que com backup mentiroso)." >&2
      exit 1
    fi
    integridade="$(sqlite3 "$destino" 'PRAGMA integrity_check;' 2>&1 | head -1)"
    if [ "$integridade" != "ok" ]; then
      echo "ERRO: banco '$rel' reprovou no integrity_check ($integridade). Backup ABORTADO." >&2
      exit 1
    fi
    # O tar do passo 1 copiou o -wal e o -shm crus junto. Depois do snapshot eles
    # estao velhos e nao pertencem mais a este arquivo: no restauro, o SQLite
    # tentaria reaplicar um WAL que nao e deste banco. O snapshot ja veio completo,
    # com o WAL incorporado - entao os dois somem do pacote.
    rm -f "$destino-wal" "$destino-shm"
    echo "  banco ok: $rel (integrity_check: $integridade)"
    # Varre o mesmo conjunto que o tar do passo 1 empacotou - nem mais, nem menos.
    # Antes era `-maxdepth 3 -name "*.db"`: alem de depender do nome, perdia banco
    # guardado mais fundo que tres niveis, que e onde projeto Node costuma pos-lo.
  done < <(find "$DIR" -type f \
             -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" \
             2>/dev/null)
fi

# 3) empacota
tar -czf "$STAGE/pacote.tgz" -C "$STAGE" "$NOME"

# 3b) CONFERE o pacote antes de cifrar. Depois de cifrado nao da mais para olhar
#     dentro sem a chave privada - e ela nao existe nesta maquina, de proposito.
#     Se o tar saiu truncado (disco cheio, processo morto), e AQUI que se descobre.
if ! tar -tzf "$STAGE/pacote.tgz" >/dev/null 2>&1; then
  echo "ERRO: o pacote .tgz nao abre (truncado ou corrompido). Backup ABORTADO." >&2
  exit 1
fi
ARQS="$(tar -tzf "$STAGE/pacote.tgz" | wc -l)"
if [ "$ARQS" -lt 1 ]; then
  echo "ERRO: o pacote saiu vazio. Backup ABORTADO." >&2
  exit 1
fi
echo "  pacote conferido: $ARQS entradas, abre sem erro"

# 4) cifra com age (segredos e projeto ilegiveis fora da VPS)
FINAL="$OUT/${NOME}-${STAMP}.tar.gz.age"
age -r "$AGE_PUB" -o "$FINAL" "$STAGE/pacote.tgz"

# 4b) o arquivo cifrado tem cabecalho valido de age e tamanho plausivel?
if ! head -c 100 "$FINAL" | grep -q 'age-encryption.org'; then
  echo "ERRO: o arquivo cifrado nao tem cabecalho age valido. Backup ABORTADO." >&2
  rm -f "$FINAL"; exit 1
fi
TAM="$(stat -c %s "$FINAL")"
if [ "$TAM" -lt 200 ]; then
  echo "ERRO: arquivo cifrado com apenas $TAM bytes - suspeito. Backup ABORTADO." >&2
  rm -f "$FINAL"; exit 1
fi
echo "  cifrado conferido: cabecalho age ok, $TAM bytes"
rm -rf "$STAGE"

echo "Backup cifrado: $FINAL"
echo "Regra 3-2-1, agora leve 1 copia para FORA da VPS:"
echo "  baixe no seu computador:  scp <alias>:$FINAL ."
echo "  e/ou snapshot do provedor, e/ou storage externo"
echo "Codigo importante tambem vai para GitHub privado (sem .env)."
echo "Teste periodico:  backup-projeto.sh --verificar $FINAL <chave-privada-age>"
