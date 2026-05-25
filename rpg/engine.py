import sqlite3
import os
import json
import random
from datetime import datetime

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


def write_log(line):
    ts = datetime.utcnow().isoformat()
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(f'[{ts}] {line}\n')


def create_character(name, data=None):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    payload = json.dumps(data or {})
    cur.execute('INSERT OR REPLACE INTO characters (name, data, created_at) VALUES (?, ?, ?)', (name, payload, datetime.utcnow().isoformat()))
    conn.commit()
    conn.close()
    write_log(f'create_character: {name}')


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


def save_action(who, action, result):
    init_db()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('INSERT INTO actions (who, action, result, ts) VALUES (?, ?, ?, ?)', (who, action, json.dumps(result), datetime.utcnow().isoformat()))
    conn.commit()
    conn.close()
    write_log(f'action: {who} -> {action} = {result}')


def roll_dice(expr):
    # simple parser for XdY+Z expressions
    expr = expr.replace(' ', '')
    total = 0
    details = []
    try:
        if 'd' in expr:
            parts = expr.split('+')
            for p in parts:
                if 'd' in p:
                    n, m = p.split('d')
                    n = int(n) if n else 1
                    m = int(m)
                    rolls = [random.randint(1, m) for _ in range(n)]
                    total += sum(rolls)
                    details.append({'dice': p, 'rolls': rolls})
                else:
                    total += int(p)
            return {'total': total, 'details': details}
        else:
            total = int(expr)
            return {'total': total, 'details': []}
    except Exception as exc:
        return {'error': str(exc)}
