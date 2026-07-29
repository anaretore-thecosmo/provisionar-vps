# Onboarding do Zero (para quem nunca teve VPS)

Ler e usar SÓ quando a triagem indicar pessoa leiga / sem VPS. Para quem já tem VPS, pular.

## Glossário mínimo (explicar só o que a pessoa não souber)

- **VPS**: um computador ligado 24h na internet que você aluga. Você manda comandos nele de longe.
- **Terminal / PowerShell**: a janela onde você digita comandos, no SEU computador.
- **SSH**: a "linha telefônica" segura que liga seu terminal à VPS. `ssh apelido` entra.
- **Chave SSH**: um par de arquivos (uma pública, uma privada) que substitui senha. Mais seguro.
- **Domínio**: o nome bonito (ex.: clinica.com.br). **DNS**: a agenda que liga o nome ao IP da VPS.
- **Porta**: uma "portinha" numerada onde um app escuta (ex.: 3990).
- **PM2**: o que mantém os apps ligados e os reinicia se caírem.
- **nginx**: o porteiro que recebe visitas da internet e manda pro app certo.
- **SSL (certbot)**: o cadeado do https, renovado sozinho.

## Escolher o tamanho da VPS (recomendador)

Perguntar o perfil do projeto e recomendar:

| Perfil | Exemplo | Recomendação mínima |
|---|---|---|
| 1 site simples | landing, blog | 1 vCPU, 2GB RAM, 40GB |
| Alguns apps + 1 banco | site + API + painel | 2 vCPU, 4GB RAM, 80GB |
| Vários apps / docker | ecossistema, Supabase | 4 vCPU, 8-16GB RAM, 160GB+ |
| **Clínica (dado sensível)** | prontuário, agenda | 2-4 vCPU, 8GB RAM, 100GB, **VPS dedicada só da clínica** |

Regra: melhor sobrar um pouco que faltar. Quase todo provedor deixa aumentar depois.
Estimativa de custo: faixa de VPS 4-8GB costuma ficar entre US$ 8 e US$ 25/mês. Confirmar no provedor.
**Sempre ativar o add-on de snapshot/backup do provedor** (barato, salva a vida).

## Comprar e primeiro acesso

1. Criar conta no provedor (ex.: Hostinger) e **ativar 2FA na conta** antes de tudo.
2. Comprar a VPS com **Ubuntu 24.04 LTS**. O provedor dá: IP, usuário (`root`), senha inicial.
3. Escolher a região mais perto do público.

## Gerar a chave SSH no Windows (se não existir)

No PowerShell:
```powershell
ssh-keygen -t ed25519 -C "seu-email"   # Enter em tudo; cria id_ed25519 e id_ed25519.pub
```
Já existe se `Test-Path $HOME\.ssh\id_ed25519.pub` der True.

## Dar apelido à VPS (agenda `.ssh\config`)

```
Host clinica
    HostName SEU_IP
    User root
    IdentityFile ~/.ssh/id_ed25519
```
Depois: `ssh clinica` entra.

## Instalar a chave e endurecer

```powershell
type $HOME\.ssh\id_ed25519.pub | ssh clinica "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```
Depois disso o `setup-vps.sh` desliga a senha com segurança.

## Subir e rodar o setup na VPS

No PowerShell, mandar o script para a VPS e executar:
```powershell
scp <caminho>\setup-vps.sh clinica:/root/     # envia o arquivo
ssh clinica "bash /root/setup-vps.sh"          # roda na VPS
```
Ele instala base, segurança e stack de uma vez. Ao final, confere sozinho.

## Apontar o domínio (o passo que todo iniciante esquece)

No painel de DNS do domínio, criar um registro **A**:
- Nome: `@` (ou o subdomínio, ex.: `clinica`)
- Valor: o **IP da VPS**
Esperar propagar (minutos a horas). Só então o `certbot --nginx -d dominio` emite o https.

## Básico do Claude Code

- **Onde rodar**: para iniciante, rode no SEU computador (PowerShell) e fale com a VPS por `ssh`.
  Alternativa avançada: instalar o Claude Code DENTRO da VPS. Recomendação p/ leigo: começar no local.
- **Instalar/logar**: seguir o instalador oficial e logar com a conta (a mesma conta serve para quantas VPS quiser).
- **No dia a dia**: descrever a tarefa em português; dizer SEMPRE qual VPS ("na clínica", "no cosmo").
- **Comandos úteis** (barra): `/help`, `/config`, e as skills do próprio ecossistema por nome.
- A conta do Claude é do seu computador, não da VPS. Não precisa duplicar nada.
