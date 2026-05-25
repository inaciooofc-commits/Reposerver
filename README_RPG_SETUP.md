RPG module and services

Files added:
- `rpg/engine.py` - simple SQLite-backed RPG engine (characters, actions, dice rolls)
- `zarco_bot.py` - local HTTP bot for RPG commands (runs on localhost:6000)
- `updater.py` - auto-updater that polls remote HEAD and pulls when changed
- `game.log`, `updater.log` - logs created at runtime
- `deploy/zarco.service`, `deploy/updater.service` - systemd unit templates

Quick start (local testing)

1. Instale dependências (veja `requirements.txt`) e ative seu venv.
2. Inicie o bot (em background):
```bash
python3 zarco_bot.py &
```
3. Faça um comando de teste (local):
```bash
curl -s -X POST http://127.0.0.1:6000/command -H 'Content-Type: application/json' -d '{"who":"you","text":"roll 1d20+5"}'
```

4. Veja a lista de comandos do bot:
```bash
curl -s http://127.0.0.1:6000/help
```

5. Veja a lista completa de comandos do projeto no terminal:
```bash
python3 monitor.py --commands
```
4. Inicie o updater (opcional):
```bash
python3 updater.py &
```

Systemd (production)

Copy service templates and enable:
```bash
sudo cp deploy/zarco.service /etc/systemd/system/zarco@<youruser>.service
sudo cp deploy/updater.service /etc/systemd/system/updater@<youruser>.service
sudo systemctl daemon-reload
sudo systemctl enable --now zarco@<youruser>
sudo systemctl enable --now updater@<youruser>
```

If your repository is not located at `~/Reposerver`, edit the copied service files and replace `%h/Reposerver` with the actual path to the repository.

On systems without a running systemd instance (such as some containers), service enable/start commands will be skipped by `install_and_run.sh`.

Security and access
- The bot listens on localhost only. The server (`server.py`) can forward commands to the bot via HTTP POST to `http://127.0.0.1:6000/command` (we can add an endpoint).
- For remote admin access via Termux, use SSH to your server (recommended). Do NOT expose the bot port publicly.
