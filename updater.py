#!/usr/bin/env python3
"""
Updater script: Fetches and pulls changes from the git remote origin.
This script is intended to be run as a one-shot command.
"""
import subprocess
import os
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(BASE_DIR, 'updater.log')

def write_log(msg):
    """Writes a message to the log file and prints it to stdout."""
    ts = datetime.now(timezone.utc).isoformat()
    log_entry = f'[{ts}] {msg}\n'
    print(msg)
    with open(LOG, 'a', encoding='utf-8') as f:
        f.write(log_entry)

def run_command(command):
    """Runs a shell command and returns its output or raises an exception."""
    return subprocess.check_output(command, cwd=BASE_DIR, stderr=subprocess.STDOUT)

def main():
    """Main update logic."""
    write_log('Update process started by command.')

    try:
        # Fetch the latest changes from origin
        write_log("Fetching from remote 'origin'...")
        run_command(['git', 'fetch', 'origin'])

        local_head = run_command(['git', 'rev-parse', '@']).decode().strip()
        remote_head = run_command(['git', 'rev-parse', '@{u}']).decode().strip()
        base = run_command(['git', 'merge-base', '@', '@{u}']).decode().strip()

        if local_head == remote_head:
            write_log("Already up-to-date. No changes to pull.")
        elif local_head == base:
            write_log("New changes detected. Attempting to pull...")
            pull_output = run_command(['git', 'pull', 'origin', '--ff-only']).decode()
            write_log("Pull successful.")
            write_log(f"Git output:\n{pull_output}")
            write_log("Update complete. Please restart any running services if necessary.")
        elif remote_head == base:
            write_log("Local changes detected that are not on remote. Please push your changes before updating.")
        else:
            write_log("Diverged branches. Please resolve conflicts manually.")

    except subprocess.CalledProcessError as e:
        error_message = f"An error occurred during the update process: {e}"
        error_output = e.output.decode()
        write_log(f"{error_message}\nOutput:\n{error_output}")
    except Exception as e:
        write_log(f"An unexpected error occurred: {e}")

if __name__ == '__main__':
    main()
