#!/usr/bin/env python3
"""Perfil universal Codex/Claude + Windows Terminal. Sem dependências externas.

Nenhum comando altera VPS. 'inspecionar' e 'plano' são somente leitura.
'gerar' grava um fragmento local; 'instalar' exige --aplicar explícito.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import sys
import tempfile
import uuid
from pathlib import Path

AGENTES = {'codex': 'codex', 'claude': 'claude'}
CORES = re.compile(r'#[0-9a-fA-F]{6}\b')
ALIAS = re.compile(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,80}$')
ID = re.compile(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,60}$')
REMOTO = re.compile(r'^/[a-zA-Z0-9_./-]+$')
TOKEN_FILES = {'tokens.json', 'theme.json', 'brand.json', 'design-system.json',
               'globals.css', 'variables.css', 'styles.css', 'tailwind.config.js',
               'tailwind.config.ts', 'theme.css'}
IGNORAR = {'.git', '.next', 'node_modules', 'dist', 'build', '.venv', '.ssh',
           '.codex', '.claude', 'secrets', 'backups'}
NAMESPACE = uuid.UUID('f65ddb7e-706b-4499-8a50-40313caf510a')
ARQUIVOS_SKILL = ('SKILL.md', 'scripts', 'references', 'assets')


class Erro(Exception):
    pass


def ler_json(arquivo: Path):
    try:
        return json.loads(arquivo.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        raise Erro(f'Não foi possível ler JSON em {arquivo}: {exc}') from exc


def gravar_atomico(arquivo: Path, dados: bytes):
    arquivo.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=arquivo.parent, prefix='.provisionar-', delete=False) as f:
        tmp = Path(f.name)
        try:
            f.write(dados)
            f.flush()
            os.fsync(f.fileno())
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
    try:
        tmp.replace(arquivo)
    finally:
        tmp.unlink(missing_ok=True)


def json_bytes(obj):
    return (json.dumps(obj, indent=2, ensure_ascii=False) + '\n').encode('utf-8')


def validar(dados: dict, cores_obrigatorias: bool = False) -> list[str]:
    problemas = []
    if not isinstance(dados, dict) or dados.get('schema_version') != 1:
        return ['schema_version precisa ser 1']
    projetos = dados.get('projects')
    if not isinstance(projetos, list) or not projetos:
        return ['projects precisa ser uma lista não vazia']
    vistos = set()
    for indice, p in enumerate(projetos):
        pre = f'projects[{indice}]'
        if not isinstance(p, dict):
            problemas.append(f'{pre} deve ser um objeto')
            continue
        pid = p.get('id', '')
        if not isinstance(pid, str) or not ID.fullmatch(pid):
            problemas.append(f'{pre}.id: informe id seguro (letras/números/_/-)')
        elif pid in vistos:
            problemas.append(f'{pre}.id duplicado: {pid}')
        vistos.add(pid)
        if not isinstance(p.get('name'), str) or not p['name'].strip():
            problemas.append(f'{pre}.name: nome do projeto não informado')
        local = p.get('location')
        if local not in ('ssh', 'local'):
            problemas.append(f'{pre}.location: escolha ssh ou local')
        caminho = p.get('workdir', '')
        if not isinstance(caminho, str) or not caminho:
            problemas.append(f'{pre}.workdir: informe diretório inicial')
        elif local == 'ssh' and (not REMOTO.fullmatch(caminho) or '..' in caminho.split('/')):
            problemas.append(f'{pre}.workdir: caminho remoto deve ser absoluto e sem caracteres de shell')
        elif local == 'local' and not (Path(caminho).is_absolute() or re.match(r'^[A-Za-z]:[\\/]', caminho)):
            problemas.append(f'{pre}.workdir: caminho local deve ser absoluto')
        if local == 'ssh' and (not isinstance(p.get('ssh_alias'), str) or not ALIAS.fullmatch(p['ssh_alias'])):
            problemas.append(f'{pre}.ssh_alias: é obrigatório um alias seguro já verificado')
        agentes = p.get('agents')
        if not isinstance(agentes, dict) or not agentes:
            problemas.append(f'{pre}.agents: escolha codex, claude ou ambos')
            continue
        for agente, cfg in agentes.items():
            if agente not in AGENTES:
                problemas.append(f'{pre}.agents.{agente}: agente não suportado')
                continue
            if not isinstance(cfg, dict):
                problemas.append(f'{pre}.agents.{agente}: deve ser objeto')
                continue
            cor = cfg.get('color')
            if cor is not None and (not isinstance(cor, str) or not CORES.fullmatch(cor)):
                problemas.append(f'{pre}.agents.{agente}.color: use #RRGGBB')
            if cores_obrigatorias and not cor:
                problemas.append(f'{pre}.agents.{agente}.color: escolha uma cor após consultar a paleta')
        if p.get('sensitivity', 'standard') not in ('standard', 'sensitive'):
            problemas.append(f'{pre}.sensitivity: standard ou sensitive')
    return problemas


def encontrar_paletas(raizes: list[str], max_files: int = 30) -> list[dict]:
    """Só arquivos conhecidos, pequenos, dentro das pastas explicitamente apontadas."""
    achados = []
    for origem in raizes:
        raiz = Path(origem).expanduser()
        if not raiz.exists():
            continue
        arquivos = [raiz] if raiz.is_file() else []
        if raiz.is_dir():
            for base, pastas, files in os.walk(raiz, followlinks=False):
                nivel = len(Path(base).relative_to(raiz).parts)
                pastas[:] = [p for p in pastas if p not in IGNORAR and not p.startswith('.')]
                if nivel > 3:
                    pastas[:] = []
                    continue
                arquivos.extend(Path(base) / name for name in files if name in TOKEN_FILES)
                if len(arquivos) >= max_files:
                    break
        for arq in arquivos[:max_files]:
            if arq.name not in TOKEN_FILES or arq.is_symlink():
                continue
            try:
                if arq.stat().st_size > 128 * 1024:
                    continue
                conteudo = arq.read_text(encoding='utf-8')
            except (OSError, UnicodeError):
                continue
            cores = list(dict.fromkeys(c.upper() for c in CORES.findall(conteudo)))[:12]
            if cores:
                achados.append({'arquivo': str(arq), 'cores_sugeridas': cores})
            if len(achados) >= max_files:
                return achados
    return achados


def aliases_ssh() -> list[str]:
    arq = Path.home() / '.ssh' / 'config'
    if not arq.is_file():
        return []
    try:
        linhas = arq.read_text(encoding='utf-8').splitlines()
    except (OSError, UnicodeError):
        return []
    encontrados = []
    for linha in linhas:
        termos = linha.strip().split()
        if termos and termos[0].lower() == 'host':
            encontrados.extend(t for t in termos[1:] if ALIAS.fullmatch(t))
    return sorted(set(encontrados))


def inspecionar(raizes: list[str]):
    return {'sistema': platform.system(),
            'ferramentas': {x: bool(shutil.which(x)) for x in ('codex', 'claude', 'ssh', 'git', 'python', 'wt')},
            'ssh_aliases': aliases_ssh(),
            'paletas_encontradas': encontrar_paletas(raizes),
            'observacao': 'Somente leitura. SSH aliases não comprovam conexão nem identidade da VPS.'}


def planejar(dados, base: Path):
    problemas = validar(dados, cores_obrigatorias=False)
    sugestoes = {}
    for p in dados.get('projects', []) if isinstance(dados.get('projects'), list) else []:
        if not isinstance(p, dict):
            continue
        fontes = p.get('palette_sources', [])
        if not isinstance(fontes, list):
            fontes = []
        caminhos = [str((base / s).resolve()) if not Path(s).is_absolute() else s for s in fontes if isinstance(s, str)]
        sugestoes[p.get('id', '?')] = encontrar_paletas(caminhos)
        agentes = p.get('agents') or {}
        if isinstance(agentes, dict):
            for agente, cfg in agentes.items():
                if agente in AGENTES and isinstance(cfg, dict) and not cfg.get('color'):
                    problemas.append(f"{p.get('id', '?')}.{agente}: definir cor; sugestões acima são hipóteses, não aprovações")
    return {'pronto': not problemas, 'pendencias': problemas, 'sugestoes_paleta': sugestoes,
            'pergunte_uma_por_vez': True, 'alteracoes_executadas': False}


def perfis(dados, manifesto: str, launcher: str):
    erros = validar(dados, cores_obrigatorias=True)
    if erros:
        raise Erro('Configuração incompleta: ' + '; '.join(erros))
    if '"' in manifesto + launcher:
        raise Erro('Caminho contém aspas inválidas para o terminal')
    saida = []
    for p in dados['projects']:
        for agente, cfg in p['agents'].items():
            titulo = ('CODEX' if agente == 'codex' else 'CODE') + ' | ' + p['name'].upper()
            chave = 'provisionar-vps:' + p['id'] + ':' + agente
            guid = '{' + str(uuid.uuid5(NAMESPACE, chave)) + '}'
            comando = (f'powershell.exe -NoLogo -NoProfile -NoExit -File "{launcher}" '
                       f'-Manifest "{manifesto}" -ProjectId "{p["id"]}" -AgentId "{agente}"')
            saida.append({'guid': guid, 'name': titulo, 'tabTitle': titulo,
                          'tabColor': cfg['color'].upper(), 'suppressApplicationTitle': True,
                          'commandline': comando, 'startingDirectory': '%USERPROFILE%',
                          'elevate': False})
    return {'profiles': saida}


def instalar(manifesto: Path, launcher: Path, destino: Path, aplicar: bool):
    dados = ler_json(manifesto)
    if validar(dados, cores_obrigatorias=True):
        raise Erro('Manifesto incompleto; execute plano primeiro')
    if not launcher.is_file():
        raise Erro('Launcher launch-agent.ps1 ausente')
    runtime = destino.parent / 'runtime'
    runtime_manifest = runtime / 'ambientes.json'
    runtime_launcher = runtime / 'launch-agent.ps1'
    fragmento = perfis(dados, str(runtime_manifest), str(runtime_launcher))
    encoded = json_bytes(fragmento)
    if not aplicar:
        return {'modo': 'simulacao', 'destino': str(destino), 'perfis': fragmento['profiles'],
                'alteracoes_executadas': False}
    for arq in (destino, runtime_manifest, runtime_launcher):
        if arq.is_symlink():
            raise Erro(f'Symlink recusado por segurança: {arq}')
    materiais = [(runtime_manifest, json_bytes(dados)),
                 (runtime_launcher, launcher.read_bytes()), (destino, encoded)]
    mudanças = []
    for arq, conteudo in materiais:
        antigo = arq.read_bytes() if arq.is_file() else None
        if antigo == conteudo:
            continue
        if antigo is not None:
            versao = hashlib.sha256(antigo).hexdigest()[:12]
            backup = arq.with_name(arq.name + '.bak.' + versao)
            if not backup.exists():
                gravar_atomico(backup, antigo)
        gravar_atomico(arq, conteudo)
        mudanças.append(str(arq))
    return {'modo': 'aplicado', 'alterados': mudanças, 'destino': str(destino),
            'perfis': len(fragmento['profiles']), 'homologacao_remota': 'PENDENTE'}


def main():
    pa = argparse.ArgumentParser(description='Configuração universal Codex + Claude Code (sem execução remota)')
    sub = pa.add_subparsers(dest='cmd', required=True)
    i = sub.add_parser('inspecionar', help='Leitura local, sem alterações')
    i.add_argument('--raiz', action='append', default=[])
    p = sub.add_parser('plano', help='Pendências, perguntas e sugestões de paleta')
    p.add_argument('--manifesto', required=True, type=Path)
    g = sub.add_parser('gerar', help='Renderiza fragmento JSON sem aplicar')
    g.add_argument('--manifesto', required=True, type=Path)
    g.add_argument('--launcher', required=True)
    g.add_argument('--saida', required=True, type=Path)
    a = sub.add_parser('instalar', help='Instala perfis pessoais sem editar settings.json')
    a.add_argument('--manifesto', required=True, type=Path)
    a.add_argument('--launcher', required=True, type=Path)
    a.add_argument('--destino', type=Path, help='Local de teste; no Windows usa Fragments por padrão')
    a.add_argument('--aplicar', action='store_true', help='Obrigatório para qualquer gravação')
    args = pa.parse_args()
    try:
        if args.cmd == 'inspecionar':
            res = inspecionar(args.raiz)
        elif args.cmd == 'plano':
            res = planejar(ler_json(args.manifesto), args.manifesto.resolve().parent)
        elif args.cmd == 'gerar':
            res = perfis(ler_json(args.manifesto), str(args.manifesto.resolve()), args.launcher)
            gravar_atomico(args.saida, json_bytes(res))
            res = {'fragmento_gerado': str(args.saida), 'perfis': len(res['profiles']),
                   'alteracao_do_windows_terminal': False}
        else:
            if args.destino is None:
                if sys.platform != 'win32' or not os.environ.get('LOCALAPPDATA'):
                    raise Erro('Instalação automática de perfis exige Windows; use --destino para ensaio')
                args.destino = Path(os.environ['LOCALAPPDATA']) / 'Microsoft/Windows Terminal/Fragments/ProvisionarVPS/profiles.json'
            res = instalar(args.manifesto, args.launcher, args.destino, args.aplicar)
        print(json.dumps(res, indent=2, ensure_ascii=False))
    except Erro as exc:
        print(json.dumps({'erro': str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
