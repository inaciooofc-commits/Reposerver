from run import socketio
from flask import request
import time
import json
import threading
import os

from app.modules.antix_panel.monitoring.services import get_system_usage
from app.modules.antix_panel.process_manager.services import get_process_list
from app.modules.antix_panel.docker_manager.services import get_docker_containers

# --- Configurações de Status ---
STATUS_FILE_PATH = "/var/run/reposerver.status.json"
STATUS_UPDATE_INTERVAL = 5 # em segundos

# --- Armazenamento de estado em memória ---
background_tasks = {
    "system_monitor": None,
    "status_writer": None
}

# Dicionário para rastrear clientes conectados
# Estrutura: { a_sid: { "ip": "1.2.3.4", "connected_at": 1678886400.0 }, ... }
connected_clients = {}

# --- Tarefas em Background ---

def system_monitor_task():
    """Uma tarefa em greenlet (SocketIO) que emite estatísticas do sistema via WebSocket."""
    while True:
        stats = get_system_usage()
        socketio.emit('system_update', stats, namespace='/antix')
        
        procs = get_process_list()
        socketio.emit('process_update', {'processes': procs}, namespace='/antix')

        containers = get_docker_containers()
        socketio.emit('docker_update', {'containers': containers}, namespace='/antix')

        socketio.sleep(2) # Importante usar socketio.sleep em tarefas gerenciadas pelo socketio

def status_writer_task():
    """Uma tarefa em thread que escreve o status dos clientes conectados para um arquivo."""
    while True:
        try:
            # Prepara os dados para serem serializados
            # Faz uma cópia da lista de valores para segurança de thread
            client_list = list(connected_clients.values())
            status_data = {
                "connected_clients": client_list,
                "timestamp": time.time()
            }
            
            # Escreve os dados em um arquivo temporário e depois o renomeia
            # para garantir atomicidade e evitar que o painel leia um arquivo parcialmente escrito.
            temp_path = STATUS_FILE_PATH + ".tmp"
            with open(temp_path, 'w') as f:
                json.dump(status_data, f)
            os.rename(temp_path, STATUS_FILE_PATH)

        except Exception as e:
            print(f"Erro no status_writer_task: {e}")
        
        time.sleep(STATUS_UPDATE_INTERVAL) # time.sleep normal é seguro em uma thread separada

# --- Handlers de Eventos SocketIO ---

@socketio.on('connect', namespace='/antix')
def on_connect():
    print(f'Anti X Panel client connected: {request.sid} from {request.remote_addr}')
    
    # Adiciona cliente ao nosso rastreador
    connected_clients[request.sid] = {
        "ip": request.remote_addr,
        "connected_at": time.time()
    }

    # Inicia as tarefas em background se for a primeira conexão
    if background_tasks.get("system_monitor") is None:
        print("Iniciando tarefa de monitoramento do sistema...")
        task = socketio.start_background_task(system_monitor_task)
        background_tasks["system_monitor"] = task

    if background_tasks.get("status_writer") is None:
        print("Iniciando tarefa de escrita de status...")
        # Para IO, uma thread daemon padrão é eficiente e segura.
        status_thread = threading.Thread(target=status_writer_task, daemon=True)
        status_thread.start()
        background_tasks["status_writer"] = status_thread

@socketio.on('disconnect', namespace='/antix')
def on_disconnect():
    print(f'Anti X Panel client disconnected: {request.sid}')
    # Remove cliente do nosso rastreador
    connected_clients.pop(request.sid, None)

@socketio.on('request_initial_data', namespace='/antix')
def on_request_initial_data():
    stats = get_system_usage()
    socketio.emit('system_update', stats, namespace='/antix')
    procs = get_process_list()
    socketio.emit('process_update', {'processes': procs}, namespace='/antix')
    containers = get_docker_containers()
    socketio.emit('docker_update', {'containers': containers}, namespace='/antix')

@socketio.on('terminal_in', namespace='/antix')
def on_terminal_in(data):
    command = data.get('data', '')
    # Simulação simples
    if command == 'ls\r':
        response = 'file1.txt  file2.py  README.md\r\n$ '
    elif command:
        response = f"comando '{(command or \"\").strip()}' executado (simulação).\r\n$ "
    else:
        response = ""
    socketio.emit('terminal_out', {'data': response}, namespace='/antix')
