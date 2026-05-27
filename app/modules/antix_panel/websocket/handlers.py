from run import socketio
from flask import request
import time
import json
import threading
import os

from app.modules.antix_panel.monitoring.services import get_system_usage as obter_uso_sistema
from app.modules.antix_panel.process_manager.services import get_process_list as obter_lista_processos
from app.modules.antix_panel.docker_manager.services import get_docker_containers as obter_containers_docker

# --- Configurações de Status ---
ARQUIVO_STATUS = "/var/run/reposerver.status.json"
INTERVALO_ATUALIZACAO_STATUS = 5 # em segundos

# --- Armazenamento de estado em memória ---
tarefas_em_background = {
    "monitor_sistema": None,
    "escritor_status": None
}

# Dicionário para rastrear clientes conectados
# Estrutura: { "sid_da_sessao": { "ip": "1.2.3.4", "conectado_em": 1678886400.0 }, ... }
clientes_conectados = {}

# --- Tarefas em Background ---

def tarefa_monitorar_sistema():
    """Uma tarefa em greenlet (SocketIO) que emite estatísticas do sistema via WebSocket."""
    while True:
        estatisticas = obter_uso_sistema()
        socketio.emit('atualizacao_sistema', estatisticas, namespace='/antix')
        
        processos = obter_lista_processos()
        socketio.emit('atualizacao_processos', {'processos': processos}, namespace='/antix')

        containers = obter_containers_docker()
        socketio.emit('atualizacao_docker', {'containers': containers}, namespace='/antix')

        socketio.sleep(2) # Importante usar socketio.sleep em tarefas gerenciadas pelo socketio

def tarefa_escrever_status():
    """Uma tarefa em thread que escreve o status dos clientes conectados para um arquivo."""
    while True:
        try:
            # Prepara os dados para serem serializados
            # Faz uma cópia da lista de valores para segurança de thread
            lista_clientes = []
            for sid, dados in clientes_conectados.items():
                lista_clientes.append({
                    "ip": dados["ip"],
                    "conectado_em": dados["conectado_em"]
                })

            dados_status = {
                "clientes_conectados": lista_clientes,
                "timestamp": time.time()
            }
            
            # Escreve os dados em um arquivo temporário e depois o renomeia
            # para garantir atomicidade e evitar que o painel leia um arquivo parcialmente escrito.
            caminho_temp = ARQUIVO_STATUS + ".tmp"
            with open(caminho_temp, 'w') as f:
                json.dump(dados_status, f)
            os.rename(caminho_temp, ARQUIVO_STATUS)

        except Exception as e:
            print(f"Erro na tarefa_escrever_status: {e}")
        
        time.sleep(INTERVALO_ATUALIZACAO_STATUS) # time.sleep normal é seguro em uma thread separada

# --- Handlers de Eventos SocketIO ---

@socketio.on('connect', namespace='/antix')
def ao_conectar():
    print(f'Cliente do Painel AntiX conectado: {request.sid} de {request.remote_addr}')
    
    # Adiciona cliente ao nosso rastreador
    clientes_conectados[request.sid] = {
        "ip": request.remote_addr,
        "conectado_em": time.time()
    }

    # Inicia as tarefas em background se for a primeira conexão
    if tarefas_em_background.get("monitor_sistema") is None:
        print("Iniciando tarefa de monitoramento do sistema...")
        tarefa = socketio.start_background_task(tarefa_monitorar_sistema)
        tarefas_em_background["monitor_sistema"] = tarefa

    if tarefas_em_background.get("escritor_status") is None:
        print("Iniciando tarefa de escrita de status...")
        # Para IO, uma thread daemon padrão é eficiente e segura.
        thread_status = threading.Thread(target=tarefa_escrever_status, daemon=True)
        thread_status.start()
        tarefas_em_background["escritor_status"] = thread_status

@socketio.on('disconnect', namespace='/antix')
def ao_desconectar():
    print(f'Cliente do Painel AntiX desconectado: {request.sid}')
    # Remove cliente do nosso rastreador
    clientes_conectados.pop(request.sid, None)

@socketio.on('solicitar_dados_iniciais', namespace='/antix')
def ao_solicitar_dados_iniciais():
    estatisticas = obter_uso_sistema()
    socketio.emit('atualizacao_sistema', estatisticas, namespace='/antix')
    processos = obter_lista_processos()
    socketio.emit('atualizacao_processos', {'processos': processos}, namespace='/antix')
    containers = obter_containers_docker()
    socketio.emit('atualizacao_docker', {'containers': containers}, namespace='/antix')

@socketio.on('terminal_entrada', namespace='/antix')
def ao_receber_terminal(dados):
    comando = dados.get('data', '')
    # Simulação simples
    if comando == 'ls\r':
        resposta = 'arquivo1.txt  arquivo2.py  LEIAME.md\r\n$ '
    elif comando:
        resposta = f"comando '{(comando or \"\").strip()}' executado (simulação).\r\n$ "
    else:
        resposta = ""
    socketio.emit('terminal_saida', {'data': resposta}, namespace='/antix')
