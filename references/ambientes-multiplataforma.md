# Ambientes universais: Codex + Claude Code, local e SSH

## Contrato obrigatório

- A skill NÃO assume nome de projeto, cores, marca, quantidade de servidores, ferramentas, sistema operacional, orçamento ou nível técnico.
- Primeiro **descobre**, depois **propõe**, então pergunta **uma dúvida por vez**, finalmente **executa após aprovação do plano**.
- O manifesto declarativo (JSON `schema_version=1`) representa projetos e agentes habilitados. Não contém segredos, token nem chave privada. Não colocar manifestos com identificadores sensíveis em repositórios públicos.
- `codex` e `claude` podem ser usados juntos ou separadamente. Cada combinação agente × projeto, quando selecionada, gera um perfil próprio. Se o usuário preferir execução local com acesso SSH pontual, registrar `location=local`, não inventar conexão remota.
- Windows Terminal e suas cores são opcionais: no Windows geramos um fragmento pessoal; em macOS e Linux oferecer equivalentes somente após verificar o terminal utilizado. Não executar comandos Windows nesses sistemas.

## Fluxo conversacional obrigatório

1. Ler objetivo atual e contexto disponível. Nunca repetir perguntas já respondidas.
2. Executar `python scripts/ambientes.py inspecionar` para inventário **somente local**. Para investigar paletas, usar `--raiz <projeto-autoriza-leitura>`; não vasculhar pastas pessoais sem escopo.
3. Comparar projetos e repositórios com aliases `~/.ssh/config`, diretórios, código e design systems permitidos. A existência do alias SSH é indício, **não prova** de identidade da VPS. Validar servidor e identidade com o proprietário antes de qualquer escrita remota.
4. Para cada projeto, identificar: nome/ID, local ou SSH, caminho de trabalho, agente(s), classificação de dados, fontes de paleta, cor por agente, tipo de produção e permissões.
5. Na paleta: consultar primeiro tokens JSON, CSS e Tailwind do próprio projeto e devolver cores **com origem**. Cores encontradas são **sugestões**, jamais escolha silenciosa. Se não existir paleta, perguntar. Se houver múltiplas cores candidatas, pedir seleção.
6. Gerar manifesto fora da fonte universal, de preferência em arquivo privado sob controle do usuário. `python scripts/ambientes.py plano --manifesto ...` devolve pendências; perguntar **uma por vez** até ficar `pronto=true`.
7. Antes de alterar Windows, VPS ou credenciais, mostrar o plano de mudanças, os riscos, a dependência de assinatura/licença, snapshots, rollback e os testes. Solicitar aprovação para operações que alterem serviço, dados, acessos ou produção.
8. No Windows, renderizar os perfis e instalar opcionalmente com `--aplicar`; são fragmentos do Terminal no escopo do usuário, **sem editar settings.json**.
9. Em cada VPS, verificar por SSH primeiro **somente leitura**: SO e arquitetura, runtime, versão CLI, usuário, diretório, acesso às credenciais, espaço, políticas corporativas, conectividade, isolamento, dados e classificação. **Não instalar agentes como root por padrão.** Instalar somente o que faltar, após aprovação. Claude Code e Codex são produtos separados e exigem autenticação própria. Não copiar tokens/cookies e não instruir exibição de segredos.
10. Por projeto, instalar a mesma fonte da skill no diretório apropriado de cada agente; gerar AGENTS.md/CLAUDE.md adaptados **sem duplicar regras conflitantes**. Não sobrescrever arquivos existentes sem comparar e preservar o original.
11. Testar cada perfil com conexão SSH validada, `pwd`, agente disponível, diretório correto, permissões e cor. Confirmar identidade por host fingerprint e dados independentes; nunca confiar só na cor da aba.
12. Entregar manifesto, inventário, evidência por ambiente, comandos de restauração, pendências e motivos de bloqueios. Se algum teste não ocorreu, marcar como **não testado**, nunca como aprovado.

## Interface de referência para Windows

```powershell
python scripts/ambientes.py inspecionar --raiz C:\Projetos\MeuProduto
python scripts/ambientes.py plano --manifesto C:\Privado\meus-ambientes.json
python scripts/ambientes.py instalar --manifesto C:\Privado\meus-ambientes.json --launcher scripts/launch-agent.ps1
# Depois de revisar a simulação:
python scripts/ambientes.py instalar --manifesto C:\Privado\meus-ambientes.json --launcher scripts/launch-agent.ps1 --aplicar
```

`--aplicar` grava um fragmento em `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\ProvisionarVPS\profiles.json` e cópia do manifesto/launcher em `runtime` vizinho. Não altera perfis existentes. Se arquivos gerenciados mudarem, guarda versão `.bak.<sha>` para recuperação. Reexecutar sem mudança não regrava o mesmo conteúdo.

**Limitações presentes:** a primeira etapa contempla Windows Terminal e validação declarativa, não instala automaticamente os CLIs nem altera VPS. A implantação remota dos agentes e o auto-ajuste das políticas de permissões dependem de auditoria e homologação separadas. Nunca anunciar instalação/remoto aprovados sem testes reais.

## Autorizações sem desgaste

- Rotina local dentro de diretórios autorizados: privilegiar execução sandbox e permissões granulares nativas.
- Solicitações adicionais de menor risco: usar revisão automática suportada **quando habilitada**.
- Operações com produção, backup, firewall, chaves, banco, dados pessoais, deploy, exclusão ou serviços: exigir intenção e autorização inequívocas. Nunca configurar bypass irrestrito ou `sudo` permanente para diminuir confirmações.
- Registrar decisões de política por projeto, **não copiar cegamente** `settings.json` de Claude para `config.toml` do Codex.

## Critérios de aceitação

- Nenhum identificador de cliente embutido em código ou na fonte universal.
- 1 projeto/1 agente, 2 projetos/2 agentes e 3 projetos/agentes mistos produzem as combinações esperadas sem personalização manual de scripts.
- Dados insuficientes geram pendências, não cores inventadas ou SSH por adivinhação.
- Cores em formato hexadecimal `#RRGGBB`, com origem e aceitação humana.
- Idempotência na instalação dos fragmentos e rollback via backups.
- Falha de SSH mantém aba aberta com erro claro, sem fallback para outro servidor.
- Execução de produção condicionada a gate e teste.

## Fontes técnicas para revalidação periódica

- Windows Terminal fragments: https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions
- Windows Terminal cores/abas: https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance
- Claude Code setup: https://code.claude.com/docs/en/setup
- Claude Code skills: https://code.claude.com/docs/en/skills
- Claude Code permissions: https://code.claude.com/docs/en/permissions
- Codex skills: https://developers.openai.com/codex/skills/
