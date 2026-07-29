---
name: provisionar-vps
description: >-
  Do zero a uma VPS pronta, segura e organizada, seja o usuario leigo (nunca comprou VPS,
  nunca usou Claude Code/terminal) ou avancado (ja tem VPS e quer clonar/migrar). Faz TRIAGEM,
  audita a VPS de origem quando existe, cura o que deve ir para a nova, gera script de instalacao,
  checklist visual e runbook. Impoe seguranca de segredos (chaves/tokens/senhas nunca vazam,
  criptografados com age, gitleaks bloqueando commit), isolamento de projetos (um projeto nunca
  dentro de outro), backup 3-2-1 (VPS + GitHub privado + copia externa
  cifrada) e LGPD para dado sensivel (clinica). Acionar quando o usuario disser "comprar/configurar
  VPS", "nova VPS", "VPS para clinica", "clonar minha VPS", "montar servidor", "do zero ate a VPS",
  "como comeco na VPS", "migrar projetos de VPS", ou pedir seguranca/backup/organizacao de servidor.
author: Ana Retore
compartilhamento: livre
metadata:
  categoria: infraestrutura
  autoria: Ana Retore, The Cosmo
  licenca: livre para uso e redistribuicao, mantido o credito de autoria
---

# Provisionar VPS

Guia outra instancia do Claude a levar qualquer pessoa do NADA a uma VPS pronta, segura e
organizada, adaptando a profundidade a quem chama. Nunca assumir o nivel: descobrir primeiro.

## Passo 0: Triagem (SEMPRE, antes de tudo)

Fazer estas 4 perguntas e ajustar todo o resto pelas respostas:

1. **Ja tem uma VPS?** (sim -> Caminho B / nao -> Caminho A)
2. **Ja usou terminal / Claude Code?** (nunca / pouco / sim) -> define se explica cada termo ou vai direto.
3. **O que a VPS vai hospedar?** (1 site / varios apps / **clinica-dado sensivel** / loja...) -> define tamanho e nivel de seguranca. Se envolver dado de paciente/pessoal, ativar trilha LGPD.
4. **Quer entender ou quer pronto?** -> define se ensina passo a passo ou executa.

Para pessoa leiga, usar linguagem simples e o glossario. Nunca despejar termo tecnico sem explicar.

## Caminho A: Nao tem VPS (do zero)

Seguir `references/onboarding-leigo.md`: glossario -> recomendar tamanho + custo ->
comprar (Ubuntu 24.04, 2FA no painel, snapshot) -> gerar chave SSH no Windows ->
apelido `.ssh\config` -> apontar DNS (registro A) -> instalar a chave -> endurecer.
Depois cai no bloco COMUM (setup + projetos + backup). Ensinar tambem o basico do Claude Code.

## Caminho B: Ja tem VPS (clonar/migrar)

1. Rodar a auditoria (somente leitura): `bash scripts/auditar-vps.sh <alias-origem>`.
2. Curar com `references/curadoria.md`: separar em 4 caixas (REPLICA / SO DO PROJETO / FICA / MELHORIAS).
   Nunca copiar a VPS inteira. Dado sensivel nunca divide maquina.
3. Reportar as MELHORIAS encontradas (buracos da origem que a nova nasce sem).
Depois cai no bloco COMUM.

## Bloco COMUM (os dois caminhos terminam aqui)

### 1. Base + seguranca + stack: de uma vez
Subir e rodar `assets/setup-vps.sh` na VPS nova (como root). Instala: swap, ufw, fail2ban,
unattended-upgrades, logrotate, fuso pt-BR, Node+PM2 (startup), nginx, certbot, **age** (criptografia)
e **gitleaks** (bloqueia commit com segredo). Ajustar variaveis do topo (SWAP_GB, TIMEZONE, INSTALL_DOCKER).
Docker so se o projeto usar containers.

### 2. Segredos e isolamento: inegociavel (ler `references/segredos-e-isolamento.md`)
- Segredo: um `.env` por projeto (600), no `.gitignore`, gitleaks no pre-commit, backup cifrado com age. Nunca em codigo/log.
- Isolamento: criar CADA projeto com `bash scripts/novo-projeto.sh <nome> <porta>`, recusa criar dentro de outro git (previne app-dentro-de-app), registra porta no PORTAS.md, cria `.env` protegido.
- Na migracao, recriar `.env` do zero. Jamais arrastar segredo antigo.

### 3. Expor o app na internet (reverse-proxy)
Cada app escuta em `127.0.0.1:PORTA` (nunca `0.0.0.0`). Ligar a internet ao app com o
template `assets/nginx-app.conf.template`: trocar dominio e porta, ativar o site, `nginx -t`,
`systemctl reload nginx`, e emitir SSL com `certbot --nginx -d DOMINIO`.

### 4. Backup 3-2-1 (ler `references/seguranca-e-backup.md`)
`bash scripts/backup-projeto.sh <dir> <chave-publica-age>` -> banco por `sqlite3 .backup`,
pacote cifrado com age. Levar 1 copia para FORA (computador / snapshot / storage). Codigo importante
em GitHub privado (sem `.env`). Agendar no cron. Testar restauracao com `--verificar` (backup nao testado nao conta).

### 5. Entregaveis finais
- **Checklist visual**: copiar `assets/checklist-template.html`, trocar `__PROJETO__` pelo nome, preencher
  os itens conforme a curadoria, e publicar como Artifact (a pessoa marca e salva o progresso sozinho).
- **Runbook**: preencher `assets/runbook-template.md` com portas, dominios, onde-esta-cada-segredo
  (referencia, nunca o valor) e como restaurar. Salvar no projeto.

## Regras que valem sempre
- Migrar, nunca deletar: copiar -> conferir -> so entao remover. Backup verificado antes.
- Nunca imprimir valor de segredo. Redigir com awk, nunca `sed` com `=`.
- Confirmar com o usuario antes de qualquer acao que altere/derrube servico. Auditoria e leitura, pode.
- LGPD para dado sensivel: VPS dedicada, backup cifrado, 2FA, acesso minimo, retencao definida.

## Arquivos
- `scripts/auditar-vps.sh`, auditoria read-only da origem
- `scripts/novo-projeto.sh`, cria projeto isolado (anti-mistura)
- `scripts/backup-projeto.sh`, backup 3-2-1 cifrado + verificacao
- `assets/setup-vps.sh`, instala base+seguranca+stack na nova
- `assets/nginx-app.conf.template`, reverse-proxy para expor um app com SSL
- `assets/runbook-template.md`, documento vivo de operacao da VPS
- `assets/checklist-template.html`, checklist visual The Cosmo
- `references/onboarding-leigo.md`, Caminho A (glossario, comprar, DNS, Claude Code)
- `references/curadoria.md`, as 4 caixas
- `references/segredos-e-isolamento.md`, segredos + isolamento
- `references/seguranca-e-backup.md`, hardening, 3-2-1, LGPD

---
Skill autoral de **Ana Retore, The Cosmo**. Livre para uso e redistribuicao, mantido o credito de autoria.
