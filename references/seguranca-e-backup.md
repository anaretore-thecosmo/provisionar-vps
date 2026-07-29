# Segurança de Rede e Backup

## Endurecimento da VPS (o setup-vps.sh já aplica; aqui está o porquê)

| Trava | O que faz | Por que importa |
|---|---|---|
| ufw (só 22/80/443) | fecha todas as portas menos as usadas | app que escuta em 0.0.0.0 fica invisível de fora |
| fail2ban | bane IP que erra senha do SSH | mata força bruta automática |
| SSH só com chave | senha desligada | senha se descobre, chave não |
| unattended-upgrades | patches de segurança automáticos | falha conhecida vira porta aberta |
| swap | memória de reserva | app que estoura RAM não derruba a VPS |
| logrotate | comprime e apaga log velho | log sem limite lota o disco e derruba tudo |
| 2FA no painel do provedor | 2º fator no login da Hostinger | de nada adianta blindar a VPS se entram pelo painel |

Portas de app sempre em `127.0.0.1` quando só o nginx consome (não `0.0.0.0`). Reduz superfície.

### Nível acima (opcional): não rodar tudo como root
O caminho simples usa `root` com chave (aceitável para 1 pessoa). Mais seguro é criar um
usuário próprio (ex.: `deploy`) com sudo, rodar os apps por ele e deixar `root` só para
administração. Vale a pena quando mais de uma pessoa acessa ou o dado é crítico. Tradeoff:
mais passos de permissão no dia a dia. Para leigo sozinho, começar no root com chave está ok.

---

## Backup: regra 3-2-1 (a que evita perder tudo)

**3** cópias, em **2** lugares diferentes, sendo **1** fora da VPS.

Para os projetos da pessoa:
1. **Na VPS**, cópia diária local (rápida de restaurar).
2. **No GitHub privado**, todo projeto IMPORTANTE tem repositório privado (código versionado).
   Segredo NÃO vai (fica no `.gitignore`); o `.env` real é cifrado à parte com `age`.
3. **Fora da VPS**, arquivo cifrado (`age`) enviado para: o computador da pessoa E/OU
   snapshot pago do provedor E/OU um storage externo. Backup na mesma máquina não é backup.

### Banco de dados
SQLite copiado com `cp` sai vazio (ignora o arquivo WAL). Sempre:
```bash
sqlite3 origem.db ".backup destino.db"
```
Postgres: `pg_dump`. Nunca `cp` de banco em uso.

### Criptografia do backup
Antes de sair da VPS, o pacote de backup é cifrado com `age`. A chave privada vive
no computador da pessoa, nunca na VPS. Roubaram a VPS? O backup roubado é ilegível.

### O teste que quase ninguém faz
**Backup que nunca foi restaurado não é backup, é esperança.**
A cada X tempo, restaurar num diretório de teste e conferir que abre. O `backup-projeto.sh`
tem modo `--verificar` que faz isso.

---

## LGPD e dado sensível (clínica)

Dado de paciente eleva o nível de tudo:
- **Criptografia em repouso** dos backups (obrigatório, não opcional).
- **VPS dedicada**, clínica não divide máquina com marketing/sites.
- **Retenção**: definir por quanto tempo guarda e quando descarta.
- **Acesso mínimo**: só quem precisa entra; cada acesso rastreável.
- **2FA** no painel e em qualquer serviço que toque o dado.
- **Alertas** de queda vão para um canal que a pessoa vê (WhatsApp/e-mail), não morrem em log.

---

## Para onde vão os alertas
O monitor de uptime só serve se avisa alguém. Configurar destino real (WhatsApp via API,
e-mail, ou Telegram). Monitor que escreve num log que ninguém lê é decoração.
