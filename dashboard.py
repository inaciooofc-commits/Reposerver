
import json
import psutil
from flask import Flask, jsonify, render_template_string
import subprocess
import os

app = Flask(__name__)

# --- Configurações ---
MAIN_APP_PID_FILE = "/var/run/reposerver.pid"
MAIN_APP_LOG_FILE = "/var/log/reposerver.log"
MAIN_APP_STATUS_FILE = "/var/run/reposerver.status.json"
LOG_LINES_TO_SHOW = 50

# --- Template HTML/JS para o Painel ---
DASHBOARD_TEMPLATE = """
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Painel de Controle do Servidor</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; background-color: #121212; color: #e0e0e0; margin: 0; padding: 20px; }
        .container { max-width: 1200px; margin: auto; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background-color: #1e1e1e; border: 1px solid #333; border-radius: 8px; padding: 20px; }
        .card h2 { margin-top: 0; border-bottom: 2px solid #333; padding-bottom: 10px; font-size: 1.2em; color: #00bcd4; }
        .status-dot { height: 15px; width: 15px; border-radius: 50%; display: inline-block; }
        .status-ok { background-color: #4CAF50; }
        .status-error { background-color: #F44336; }
        pre { background-color: #000; padding: 10px; border-radius: 5px; white-space: pre-wrap; word-wrap: break-word; font-family: "Courier New", Courier, monospace; max-height: 400px; overflow-y: auto; }
        .stats-item { display: flex; justify-content: space-between; margin-bottom: 10px; }
        .progress-bar { background-color: #444; border-radius: 5px; height: 20px; width: 100%; }
        .progress-bar div { background-color: #00bcd4; height: 100%; border-radius: 5px; text-align: right; color: #000; padding-right: 5px; box-sizing: border-box; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Painel de Controle do Servidor</h1>
        <div class="grid">
            <div class="card">
                <h2>Status do Sistema</h2>
                <div class="stats-item">
                    <span>Uso de CPU</span>
                    <span id="cpu_usage_text">--%</span>
                </div>
                <div class="progress-bar"><div id="cpu_usage_bar" style="width:0%;"></div></div>
                <div class="stats-item" style="margin-top: 15px;">
                    <span>Uso de Memória</span>
                    <span id="mem_usage_text">--%</span>
                </div>
                <div class="progress-bar"><div id="mem_usage_bar" style="width:0%;"></div></div>
            </div>

            <div class="card">
                <h2>Servidor Principal (reposerver)</h2>
                <div class="stats-item">
                    <span>Status</span>
                    <div><span id="app_status_dot" class="status-dot"></span> <span id="app_status_text">--</span></div>
                </div>
                <div class="stats-item">
                    <span>PID</span>
                    <span id="app_pid">--</span>
                </div>
            </div>

            <div class="card">
                <h2>Clientes Conectados</h2>
                <ul id="connected_clients"><li>--</li></ul>
            </div>
        </div>

        <div class="card" style="margin-top: 20px;">
            <h2>Logs do Servidor ({{ LOG_LINES_TO_SHOW }} últimas linhas)</h2>
            <pre id="log_content">Carregando logs...</pre>
        </div>
    </div>

    <script>
        function fetchData() {
            fetch('/api/data')
                .then(response => response.json())
                .then(data => {
                    // CPU e Memória
                    document.getElementById('cpu_usage_bar').style.width = data.cpu_percent + '%';
                    document.getElementById('cpu_usage_text').innerText = data.cpu_percent.toFixed(1) + '%';
                    document.getElementById('mem_usage_bar').style.width = data.memory_percent + '%';
                    document.getElementById('mem_usage_text').innerText = data.memory_percent.toFixed(1) + '%';
                    
                    // Status da App
                    const appStatusDot = document.getElementById('app_status_dot');
                    appStatusDot.className = 'status-dot ' + (data.main_app_status.running ? 'status-ok' : 'status-error');
                    document.getElementById('app_status_text').innerText = data.main_app_status.running ? 'Rodando' : 'Parado';
                    document.getElementById('app_pid').innerText = data.main_app_status.pid || '--';

                    // Logs
                    document.getElementById('log_content').innerText = data.log_content || 'Nenhum log encontrado ou erro ao ler.';
                    
                    // Clientes
                    const clientsList = document.getElementById('connected_clients');
                    clientsList.innerHTML = '';
                    if (data.connected_clients && data.connected_clients.length > 0) {
                        data.connected_clients.forEach(client => {
                            const li = document.createElement('li');
                            li.innerText = client.ip + ' (Conectado desde: ' + new Date(client.connected_at).toLocaleString() + ')';
                            clientsList.appendChild(li);
                        });
                    } else {
                        clientsList.innerHTML = '<li>Nenhum cliente conectado.</li>';
                    }
                })
                .catch(error => console.error('Erro ao buscar dados:', error));
        }

        setInterval(fetchData, 3000); // Atualiza a cada 3 segundos
        fetchData(); // Carga inicial
    </script>
</body>
</html>
"""

def get_process_status(pidfile):
    if os.path.exists(pidfile):
        try:
            with open(pidfile, 'r') as f:
                pid = int(f.read().strip())
            if psutil.pid_exists(pid):
                return {"running": True, "pid": pid}
        except (IOError, ValueError):
            pass
    return {"running": False, "pid": None}

def get_log_content(logfile, lines):
    try:
        # Usamos 'tail' pois é eficiente para pegar o final de arquivos grandes.
        result = subprocess.run(['tail', '-n', str(lines), logfile], capture_output=True, text=True)
        return result.stdout
    except FileNotFoundError:
        return f"Arquivo de log não encontrado em {logfile}"
    except Exception as e:
        return f"Erro ao ler o arquivo de log: {e}"

def get_connected_clients(status_file):
    if os.path.exists(status_file):
        try:
            with open(status_file, 'r') as f:
                return json.load(f).get('connected_clients', [])
        except (IOError, json.JSONDecodeError):
            pass
    return []

@app.route('/')
def dashboard():
    return render_template_string(DASHBOARD_TEMPLATE, LOG_LINES_TO_SHOW=LOG_LINES_TO_SHOW)

@app.route('/api/data')
def api_data():
    data = {
        "cpu_percent": psutil.cpu_percent(),
        "memory_percent": psutil.virtual_memory().percent,
        "main_app_status": get_process_status(MAIN_APP_PID_FILE),
        "log_content": get_log_content(MAIN_APP_LOG_FILE, LOG_LINES_TO_SHOW),
        "connected_clients": get_connected_clients(MAIN_APP_STATUS_FILE)
    }
    return jsonify(data)

if __name__ == '__main__':
    # Este modo de execução é apenas para teste. Em produção, usaremos Gunicorn.
    app.run(host='0.0.0.0', port=5001, debug=True)
