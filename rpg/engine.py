import sqlite3
import os
import json
import random
import re
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, 'rpg_data.sqlite3')
LOG_FILE = os.path.join(BASE_DIR, 'game.log')


def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('''
    CREATE TABLE IF NOT EXISTS characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        data TEXT,
        created_at TEXT
    )
    ''')
    cur.execute('''
    CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        data TEXT,
        created_at TEXT
    )
    ''')
    cur.execute('''
    CREATE TABLE IF NOT EXISTS actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        who TEXT,
        action TEXT,
        result TEXT,
        ts TEXT
    )
    ''')
    conn.commit()
    conn.close()


def _now():
    return datetime.now(timezone.utc).isoformat()


def write_log(line):
    ts = _now()
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(f'[{ts}] {line}\n')


def create_character(name, data=None):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    payload = json.dumps(data or {})
    cur.execute(
        'INSERT OR REPLACE INTO characters (name, data, created_at) VALUES (?, ?, ?)',
        (name, payload, _now()),
    )
    conn.commit()
    conn.close()
    write_log(f'create_character: {name}')
    return {'name': name, 'created': True}


def get_character(name):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('SELECT data FROM characters WHERE name=?', (name,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return json.loads(row[0] or '{}')


def list_characters():
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('SELECT name FROM characters ORDER BY name COLLATE NOCASE')
    rows = cur.fetchall()
    conn.close()
    return [row[0] for row in rows]


def delete_character(name):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('DELETE FROM characters WHERE name=?', (name,))
    deleted = cur.rowcount
    conn.commit()
    conn.close()
    write_log(f'delete_character: {name} (deleted={deleted})')
    return deleted > 0


def get_recent_actions(limit=20):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('SELECT who, action, result, ts FROM actions ORDER BY id DESC LIMIT ?', (limit,))
    rows = cur.fetchall()
    conn.close()
    actions = []
    for who, action, result, ts in rows:
        try:
            decoded = json.loads(result)
        except Exception:
            decoded = result
        actions.append({'who': who, 'action': action, 'result': decoded, 'ts': ts})
    return actions


def save_action(who, action, result):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        'INSERT INTO actions (who, action, result, ts) VALUES (?, ?, ?, ?)',
        (who, action, json.dumps(result), _now()),
    )
    conn.commit()
    conn.close()
    write_log(f'action: {who} -> {action} = {result}')


def roll_dice(expr):
    expr = expr.lower().replace(' ', '')
    total = 0
    details = []
    try:
        parts = re.split(r'(?=[+-])', expr)
        if not parts:
            raise ValueError('Expressão vazia')
        for part in parts:
            if not part:
                continue
            sign = 1
            if part[0] == '+':
                part = part[1:]
            elif part[0] == '-':
                sign = -1
                part = part[1:]
            if not part:
                continue
            if 'd' in part:
                n_str, m_str = part.split('d', 1)
                n = int(n_str) if n_str else 1
                m = int(m_str)
                if n < 1 or m < 1:
                    raise ValueError('Número de dados ou faces inválido')
                rolls = [random.randint(1, m) for _ in range(n)]
                subtotal = sum(rolls) * sign
                total += subtotal
                details.append({'dice': part, 'rolls': rolls, 'sign': sign})
            else:
                total += sign * int(part)
        return {'total': total, 'details': details}
    except Exception as exc:
        return {'error': str(exc), 'expr': expr}
