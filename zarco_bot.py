#!/usr/bin/env python3
"""
ZarcoBOT-RPG de mesa - simple HTTP bot for RPG commands.
Runs a small Flask app on localhost:6000 and accepts POST /command JSON {who, text}
"""
import os
import threading
import time
import json
from flask import Flask, request, jsonify
from rpg.engine import roll_dice, create_character, get_character, save_action, write_log

app = Flask('zarco_bot')

AVAILABLE_COMMANDS = [
    'roll <expr>          - exemplo: roll 1d20+5',
    'rolar <expr>         - exemplo: rolar 2d6+3',
    'create char <nome>   - cria personagem',
    'create character <nome> - cria personagem',
    'show char <nome>     - exibe personagem',
    'show character <nome> - exibe personagem',
    'qualquer texto livre  - ecoa como roleplay',
]


def parse_command(text):
    t = text.strip().lower()
    # roll command e.g. roll 1d20+5
    if t.startswith('roll ') or t.startswith('rolar '):
        expr = t.split(' ', 1)[1]
        return ('roll', expr)
    if t.startswith('create char ') or t.startswith('create character '):
        name = text.split(' ', 2)[2].strip()
        return ('create_char', name)
    if t.startswith('show char ') or t.startswith('show character '):
        name = text.split(' ', 2)[2].strip()
        return ('show_char', name)
    if t in ['help', '/help', 'commands', '/commands']:
        return ('help', '')
    # fallback: treat as chat/action
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
    return jsonify({
        'ok': True,
        'available_commands': AVAILABLE_COMMANDS,
    })


@app.route('/command', methods=['POST'])
def command():
    data = request.get_json() or {}
    who = data.get('who', 'anon')
    text = data.get('text', '')
    cmd, arg = parse_command(text)
    if cmd == 'roll':
        res = roll_dice(arg)
        save_action(who, text, res)
        return jsonify({'ok': True, 'type': 'roll', 'result': res})
    if cmd == 'create_char':
        create_character(arg, {})
        save_action(who, text, {'created': arg})
        return jsonify({'ok': True, 'created': arg})
    if cmd == 'show_char':
        ch = get_character(arg)
        return jsonify({'ok': True, 'character': ch})
    if cmd == 'help':
        return jsonify({'ok': True, 'available_commands': AVAILABLE_COMMANDS})
    # say/action
    save_action(who, text, {'message': text})
    return jsonify({'ok': True, 'echo': text})


def run():
    write_log('ZarcoBOT starting')
    app.run(host='127.0.0.1', port=6000)


if __name__ == '__main__':
    run()
