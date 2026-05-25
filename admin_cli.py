#!/usr/bin/env python3
import json
import os
from uuid import uuid4

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(BASE_DIR, 'users.json')
CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')


def load_json(path, default):
    if not os.path.exists(path):
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(default, f, indent=2, ensure_ascii=False)
        return default
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return default


def save_json(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def create_user():
    users = load_json(DATA_FILE, {})
    username = input('Novo usuário: ').strip()
    if not username:
        print('Nome inválido')
        return
    if username in users:
        print('Usuário já existe')
        return
    password = input('Senha: ').strip()
    role = input('Função (user/admin) [user]: ').strip() or 'user'
    if role == 'admin' and not username.startswith('admin@'):
        print('Para criar administrador, o nome deve começar com "admin@"')
        return
    users[username] = {'password': password, 'role': role, 'credits': 0, 'banned': False}
    save_json(DATA_FILE, users)
    print('Usuário criado')


def toggle_ban():
    users = load_json(DATA_FILE, {})
    target = input('Usuário para ban/unban: ').strip()
    if target not in users or target == 'admin':
        print('Usuário inválido ou admin não pode ser alterado')
        return
    users[target]['banned'] = not users[target].get('banned', False)
    save_json(DATA_FILE, users)
    print(f"{target} ban status: {users[target]['banned']}")


def grant_credits():
    users = load_json(DATA_FILE, {})
    target = input('Usuário para creditar: ').strip()
    if target not in users:
        print('Usuário inválido')
        return
    try:
        amount = int(input('Quantidade: ').strip())
    except Exception:
        print('Quantidade inválida')
        return
    users[target]['credits'] = users[target].get('credits', 0) + amount
    save_json(DATA_FILE, users)
    print(f'Adicionados {amount} créditos para {target}')


def update_config_prompt():
    cfg = load_json(CONFIG_FILE, {})
    print('Config atual:')
    print(json.dumps(cfg, indent=2, ensure_ascii=False))
    key = input('Chave para atualizar (youtube_api_key/background_music/panel_title): ').strip()
    if not key:
        return
    val = input('Novo valor: ').strip()
    cfg[key] = val
    save_json(CONFIG_FILE, cfg)
    print('Config atualizada')


def main():
    actions = {
        '1': ('Criar usuário', create_user),
        '2': ('Ban/Desban', toggle_ban),
        '3': ('Adicionar créditos', grant_credits),
        '4': ('Atualizar config', update_config_prompt),
        'q': ('Sair', None),
    }
    while True:
        print('\n=== Admin CLI ===')
        for k, v in actions.items():
            print(f'{k}) {v[0]}')
        choice = input('> ').strip()
        if choice == 'q':
            break
        act = actions.get(choice)
        if not act:
            print('Opção inválida')
            continue
        try:
            act[1]()
        except Exception as e:
            print('Erro:', e)


if __name__ == '__main__':
    main()
