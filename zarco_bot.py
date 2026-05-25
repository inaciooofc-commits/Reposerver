#!/usr/bin/env python3
"""
ZarcoBOT-RPG de mesa - simple HTTP bot for RPG commands.
Runs a small Flask app on localhost:6000 and accepts POST /command JSON {who, text}
"""
import json
from flask import Flask, request, jsonify
from rpg.engine import (
    init_db,
    roll_dice,
    create_character,
    get_character,
    list_characters,
    delete_character,
    save_action,
    write_log,
    get_recent_actions,
)

app = Flask('zarco_bot')

AVAILABLE_COMMANDS = [
    'roll <expr>                    - exemplo: roll 1d20+5',
    'rolar <expr>                   - exemplo: rolar 2d6+3',
    'create char <nome>             - cria personagem',
    'create character <nome>        - cria personagem',
    'show char <nome>               - exibe personagem',
    'show character <nome>          - exibe personagem',
    'list chars                     - lista personagens',
    'list characters                - lista personagens',
    'delete char <nome>             - remove personagem',
    'delete character <nome>        - remove personagem',
    'status                         - mostra status do bot',
    'help | /help | commands        - mostra esta ajuda',
    'qualquer texto livre           - ecoa como roleplay',
]


def parse_command(text):
    t = text.strip().lower()
    if t.startswith('roll ') or t.startswith('rolar '):
        return ('roll', text.split(' ', 1)[1])
    if t.startswith('create char ') or t.startswith('create character '):
        return ('create_char', text.split(' ', 2)[2].strip())
    if t.startswith('show char ') or t.startswith('show character '):
        return ('show_char', text.split(' ', 2)[2].strip())
    if t in ['list chars', 'list characters', 'chars', 'characters']:
        return ('list_chars', '')
    if t.startswith('delete char ') or t.startswith('delete character '):
        return ('delete_char', text.split(' ', 2)[2].strip())
    if t in ['help', '/help', 'commands', '/commands']:
        return ('help', '')
    if t in ['status', '/status', 'bot status']:
        return ('status', '')
    return ('say', text)


@app.route('/', methods=['GET'])
def home():
    return jsonify({
        'ok': True,
        'message': 'ZarcoBOT RPG is online. Use POST /command with JSON {who, text}.',
        'help': '/help',
    })


@app.route('/help', methods=['GET'])
def help_route():
    return jsonify({'ok': True, 'available_commands': AVAILABLE_COMMANDS})


@app.route('/status', methods=['GET'])
def status_route():
    return jsonify({'ok': True, 'status': 'online', 'available_commands': len(AVAILABLE_COMMANDS)})


@app.route('/command', methods=['POST'])
def command():
    data = request.get_json() or {}
    who = data.get('who', 'anon')
    text = data.get('text', '')
    cmd, arg = parse_command(text)

    if cmd == 'roll':
        res = roll_dice(arg)
        save_action(who, text, res)
        return jsonify({'ok': True, 'type': 'roll', 'result': res, 'message': f'{who} rolled {arg}.'})

    if cmd == 'create_char':
        result = create_character(arg, {})
        save_action(who, text, result)
        return jsonify({'ok': True, 'type': 'create_char', 'created': arg, 'message': f'Personagem "{arg}" criado.'})

    if cmd == 'show_char':
        character = get_character(arg)
        if not character:
            return jsonify({'ok': False, 'error': f'Personagem "{arg}" não encontrado.'}), 404
        return jsonify({'ok': True, 'type': 'show_char', 'character': character})

    if cmd == 'list_chars':
        characters = list_characters()
        return jsonify({'ok': True, 'type': 'list_chars', 'characters': characters})

    if cmd == 'delete_char':
        removed = delete_character(arg)
        if not removed:
            return jsonify({'ok': False, 'error': f'Personagem "{arg}" não existe.'}), 404
        save_action(who, text, {'deleted': arg})
        return jsonify({'ok': True, 'type': 'delete_char', 'deleted': arg, 'message': f'Personagem "{arg}" removido.'})

    if cmd == 'status':
        characters = list_characters()
        recent = get_recent_actions(10)
        return jsonify({'ok': True, 'type': 'status', 'characters': characters, 'recent_actions': recent})

    if cmd == 'help':
        return jsonify({'ok': True, 'available_commands': AVAILABLE_COMMANDS})

    save_action(who, text, {'message': text})
    return jsonify({'ok': True, 'type': 'say', 'echo': text, 'message': f'{who} disse: {text}'})


def run():
    init_db()
    write_log('ZarcoBOT starting')
    app.run(host='127.0.0.1', port=6000)


if __name__ == '__main__':
    run()
