import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ARQ = Path(__file__).resolve().parents[1] / 'scripts' / 'ambientes.py'
spec = importlib.util.spec_from_file_location('ambientes', ARQ)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def dados(n=1, agentes=None):
    agentes = agentes or {'claude': {'color': '#007755'}, 'codex': {'color': '#AABBCC'}}
    return {'schema_version': 1, 'projects': [
        {'id': f'projeto{i}', 'name': f'Projeto {i}', 'location': 'ssh',
         'ssh_alias': f'servidor{i}', 'workdir': f'/home/deploy/proj{i}',
         'agents': agentes} for i in range(n)]}


class AmbientesTeste(unittest.TestCase):
    def test_quatro_perfis_personalizados(self):
        p = mod.perfis(dados(2), 'C:\\manifest.json', 'C:\\launcher.ps1')['profiles']
        self.assertEqual(len(p), 4)
        self.assertEqual({x['tabColor'] for x in p}, {'#007755', '#AABBCC'})
        self.assertEqual({x['name'] for x in p}, {'CODE | PROJETO 0', 'CODEX | PROJETO 0',
                                                 'CODE | PROJETO 1', 'CODEX | PROJETO 1'})
        self.assertEqual(p[0]['guid'], mod.perfis(dados(2), 'a', 'b')['profiles'][0]['guid'])

    def test_um_agente_ou_tres_projetos(self):
        p = mod.perfis(dados(3, {'claude': {'color': '#102030'}}), 'a', 'b')
        self.assertEqual(len(p['profiles']), 3)

    def test_pendencias_cor_sem_presumir(self):
        d = dados()
        d['projects'][0]['agents']['codex'].pop('color')
        plano = mod.planejar(d, Path('/tmp'))
        self.assertFalse(plano['pronto'])
        self.assertIn('definir cor', str(plano['pendencias']))
        with self.assertRaises(mod.Erro):
            mod.perfis(d, 'a', 'b')

    def test_rejeita_alias_e_caminho_inseguros(self):
        d = dados()
        d['projects'][0]['ssh_alias'] = 'srv;rm'
        d['projects'][0]['workdir'] = '/srv/../../root'
        self.assertTrue(any('ssh_alias' in x for x in mod.validar(d)))
        self.assertTrue(any('workdir' in x for x in mod.validar(d)))

    def test_rejeita_id_duplicado(self):
        d = dados(2)
        d['projects'][1]['id'] = 'projeto0'
        self.assertTrue(any('duplicado' in x for x in mod.validar(d)))

    def test_paleta_escopo(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            (p / 'tokens.json').write_text('{"primary":"#123456","secondary":"#ABCDEF"}')
            (p / '.env').write_text('TOKEN=#111111')
            encontrados = mod.encontrar_paletas([tmp])
            self.assertEqual(encontrados[0]['cores_sugeridas'], ['#123456', '#ABCDEF'])
            self.assertNotIn('#111111', json.dumps(encontrados))

    def test_instalacao_explicitamente_controlada_idempotente(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            manifesto = p / 'ambientes.json'
            manifesto.write_text(json.dumps(dados()))
            launcher = p / 'launch-agent.ps1'
            launcher.write_text('Write-Host "Teste"')
            target = p / 'Fragments' / 'profiles.json'
            dry = mod.instalar(manifesto, launcher, target, False)
            self.assertEqual(dry['modo'], 'simulacao')
            self.assertFalse(target.exists())
            first = mod.instalar(manifesto, launcher, target, True)
            self.assertEqual(len(first['alterados']), 3)
            second = mod.instalar(manifesto, launcher, target, True)
            self.assertEqual(second['alterados'], [])
            self.assertEqual(len(mod.ler_json(target)['profiles']), 2)

    def test_backup_se_versao_mudar(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            m = p / 'manifest.json'; m.write_text(json.dumps(dados()))
            s = p / 'launcher.ps1'; s.write_text('Write-Host "ok"')
            t = p / 'Frag' / 'profiles.json'
            mod.instalar(m, s, t, True)
            d = dados(); d['projects'][0]['agents']['claude']['color'] = '#334455'
            m.write_text(json.dumps(d))
            mod.instalar(m, s, t, True)
            self.assertGreaterEqual(len(list(t.parent.glob('profiles.json.bak.*'))), 1)


if __name__ == '__main__':
    unittest.main()
