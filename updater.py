#!/usr/bin/env python3
"""Auto-updater: polls remote origin and pulls when remote HEAD changes."""
import subprocess
import time
import os
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(BASE_DIR, 'updater.log')


def write_log(msg):
    ts = datetime.utcnow().isoformat() if 'datetime' in globals() else datetime.now().isoformat()
    with open(LOG, 'a', encoding='utf-8') as f:
        f.write(f'[{ts}] {msg}\n')


def get_remote_head():
    try:
        out = subprocess.check_output(['git', 'ls-remote', 'origin', 'HEAD'], cwd=BASE_DIR)
        return out.decode().split()[0].strip()
    except Exception as e:
        write_log(f'ls-remote failed: {e}')
        return None


def get_local_head():
    try:
        out = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=BASE_DIR)
        return out.decode().strip()
    except Exception as e:
        write_log(f'rev-parse failed: {e}')
        return None


def pull():
    try:
        out = subprocess.check_output(['git', 'pull', '--ff-only'], cwd=BASE_DIR, stderr=subprocess.STDOUT)
        write_log(f'git pull output: {out.decode().strip()}')
        return True
    except Exception as e:
        write_log(f'git pull failed: {e}')
        return False


def main(poll_interval=30):
    write_log('updater started')
    last = get_local_head()
    while True:
        try:
            remote = get_remote_head()
            if remote and remote != last:
                write_log(f'remote changed {last} -> {remote}, pulling')
                if pull():
                    last = get_local_head()
            time.sleep(poll_interval)
        except KeyboardInterrupt:
            break


if __name__ == '__main__':
    main()
