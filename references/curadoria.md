# Curadoria (interpretar a auditoria e decidir o que vai)

Depois de rodar `auditar-vps.sh`, separar TUDO em 4 caixas. Esta é a inteligência da skill:
não copiar a VPS inteira, e sim o que faz sentido para o NOVO objetivo.

## Caixa 1: REPLICA (o alicerce, vai sempre)
Base + segurança + stack, independente do projeto:
ufw, fail2ban, SSH só-chave, unattended-upgrades, swap, logrotate, certbot,
Node, PM2 (com startup), nginx, git, gitleaks, age, fuso pt-BR.
Tudo isso o `setup-vps.sh` instala de uma vez.

## Caixa 2: SÓ DO NOVO PROJETO (traz do que existe, filtrado)
Apenas os apps/domínios do ecossistema-alvo. Ex.: para uma VPS de clínica,
só a API da clínica, o site da clínica e os domínios clínicos. Cada um migrado como projeto
ISOLADO (ver segredos-e-isolamento.md), com `.env` recriado do zero (nunca copiar segredo antigo).

## Caixa 3: FICA (não vai de jeito nenhum)
Todo o resto da VPS de origem que pertence a OUTROS ecossistemas.
Misturar aqui é recriar o caos. Dado sensível (clínica) nunca divide máquina com o resto.

## Caixa 4: MELHORIAS (o que a origem NÃO tem e a nova nasce com)
A auditoria revela buracos. Reportar sempre os que aparecerem, ex. comuns:
- swap ausente na origem -> nova nasce com swap
- backup só na própria VPS -> nova nasce com 3-2-1 e cifra age
- segredo em texto puro / sem gitleaks -> nova nasce com as 5 travas
- sem logrotate -> nova nasce com
- sem 2FA no painel -> orientar ativar
- alerta de monitor sem destino -> configurar canal real

## Regra de migração (nunca deletar)
Migrar = copiar -> conferir (checksum/abre?) -> só então considerar remover a origem.
Jamais apagar antes de o novo estar de pé e verificado. Backup verificado antes de qualquer remoção.

## Entregáveis ao final
1. Checklist visual (assets/checklist-template.html) preenchido com os itens desta curadoria.
2. `setup-vps.sh` (base+stack) pronto para rodar na nova.
3. Runbook: documento final com o que foi feito, portas, domínios, onde está cada segredo
   (referência, nunca o valor), e como restaurar. Modelo estilo DECISOES.md.
