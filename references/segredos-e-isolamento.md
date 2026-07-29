# Segredos e Isolamento de Projetos

Duas fontes de caos que a skill previne SEMPRE, e com atenção redobrada para leigos:
1. Segredos (chaves, tokens, senhas) vazando ou em texto puro.
2. Projetos se misturando (ex.: um app parar dentro da pasta de outro).

---

## Parte 1: Segredos nunca vazam e ficam criptografados

### Regra de ouro
Segredo nunca entra no código, nunca entra no git, nunca é impresso em log.
Vive em UM lugar só, com permissão fechada, e o backup dele é criptografado.

### As 5 travas (a skill instala/verifica todas)

1. **Um `.env` por projeto, permissão 600**
   Cada projeto lê do seu próprio `.env` (nunca hardcode). `chmod 600 .env` = só o dono lê.
   Nunca um `.env` compartilhado entre projetos diferentes.

2. **`.gitignore` obrigatório com `.env`**
   Todo projeto nasce com `.env`, `*.key`, `*.pem`, `secrets/` no `.gitignore`.
   Sem isso, o segredo vai pro GitHub no primeiro commit.

3. **`gitleaks` como pré-commit (a trava que faltava)**
   Um "porteiro" que escaneia CADA commit e BLOQUEIA se achar chave/token/senha.
   É o que impede o vazamento antes de acontecer, não depois. Instalado pelo setup.

4. **Segredos criptografados em repouso com `age`**
   O backup dos segredos (e de projetos importantes) é cifrado com `age` antes de sair da VPS.
   Chave `age` gerada uma vez, guardada FORA da VPS (no seu computador). Sem ela, o arquivo é lixo pra quem roubar.
   ```bash
   age-keygen -o ~/.age-key.txt              # gera a chave (rode 1x, guarde offline)
   age -r <sua-chave-publica> -o segredo.age .env   # cifra
   age -d -i ~/.age-key.txt segredo.age > .env      # decifra
   ```

5. **Nunca imprimir segredo em log/terminal**
   `pm2 env`, `printenv`, `echo $TOKEN` vazam em log. Ao redigir para mostrar algo,
   mascarar com awk, nunca `sed` com `=`. Logs de app nunca logam o `.env`.

### Rotação
Se um segredo já vazou (foi pro git, apareceu em log, foi compartilhado): ele está morto.
Rotacionar = gerar um novo no provedor e trocar em todo lugar. Trocar a chave, não esconder o vazamento.

---

## Parte 2: Projetos nunca se misturam

### A causa do caos (um app parar dentro de outro)
Sem uma convenção, um projeto é clonado/criado dentro da pasta de outro. Aí:
git de um vira git do outro, deploy de um sobe arquivo do outro, backup mistura tudo.
Leigo não percebe e não sabe desfazer.

### A convenção (a skill impõe, o script `novo-projeto.sh` garante)

1. **Um projeto = uma pasta de primeiro nível.** Nunca aninhar.
   ```
   /var/www/
     ├── app-api/        <- projeto
     ├── app-site/       <- projeto
     └── app-painel/     <- projeto (IRMAO dos outros, JAMAIS dentro deles)
   ```
   Regra simples pro leigo: "se você entrou num projeto, você NÃO cria outro projeto aí dentro. Volta pra /var/www primeiro."

2. **Um projeto = um repositório git.** Antes de `git init` ou `git clone`, conferir que a pasta atual NÃO está dentro de outro git (`git rev-parse --show-toplevel`). O script recusa se estiver.

3. **Um projeto = um nome no PM2 = um domínio no nginx = uma porta.**
   Nada de dois apps com o mesmo nome ou a mesma porta.

4. **Registro de portas** (`/root/PORTAS.md`): tabela viva de porta -> projeto.
   Antes de subir um app, olhar a tabela. Evita colisão e diz o que é cada porta.

5. **Isolamento de dados sensíveis por ecossistema.** Projeto de clínica (dado de paciente)
   fica numa VPS só dele, nunca junto de projeto de marketing/site. Separação física, não só de pasta.

### O que `novo-projeto.sh` cria (padrão à prova de leigo)
Recusa criar dentro de outro git. Senão, cria a pasta em /var/www, com:
`.gitignore` (com .env), `.env` 600, entrada sugerida de PM2 e de porta no PORTAS.md.
Assim o projeto já nasce isolado e seguro, sem a pessoa precisar saber de nada disso.
