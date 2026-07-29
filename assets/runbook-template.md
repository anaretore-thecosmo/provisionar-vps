# Runbook da VPS: __PROJETO__

Documento vivo. Quem assume a VPS (voce, um tecnico, um futuro eu) se orienta so por aqui.
NUNCA escrever o valor de um segredo aqui. So dizer ONDE ele mora.

## Identidade
- Provedor / plano:
- IP:
- Dominio(s):
- Sistema: Ubuntu 24.04 LTS
- Data do provisionamento:

## Acesso
- Apelido SSH (no .ssh\config):
- Usuario:
- 2FA ativo no painel do provedor? (sim/nao)

## Projetos nesta VPS (isolados, um por pasta em /var/www)
| Projeto | Porta | Dominio | Nome no PM2 | Repo GitHub |
|---|---|---|---|---|
|  |  |  |  |  |

## Segredos (ONDE estao, nunca o valor)
- Cada projeto le do seu proprio /var/www/<projeto>/.env (permissao 600).
- Chave privada `age` (decifra os backups): guardada em ____ (FORA da VPS, ex.: computador da dona).
- Chave publica `age` (cifra os backups):

## Backup (3-2-1)
- Script: /usr/local/bin/backup-projeto.sh (ou onde ficou), rodando no cron as ____.
- Copia 1 (VPS): /root/backups/
- Copia 2 (GitHub privado): codigo versionado, sem .env.
- Copia 3 (fora): ____ (computador / snapshot do provedor / storage).
- Ultimo teste de restauracao (--verificar): ____

## Monitor e alertas
- Monitor de uptime: (script / servico)
- Alertas caem em: ____ (WhatsApp / e-mail / Telegram)

## Como restaurar um projeto
1. Baixar o backup .age mais recente.
2. `age -d -i <chave-privada> arquivo.age | tar -xz -C /var/www/`
3. Recriar/entrar em /var/www/<projeto>, `npm install`, subir com pm2.
4. Reativar nginx do dominio e `certbot --nginx -d <dominio>`.

## Historico de decisoes
- (data) o que foi decidido e por que.
