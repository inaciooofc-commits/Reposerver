
import os
import subprocess
import sys
import argparse
import time
import signal

# --- Constantes ---
PYTHON_EXEC = "/usr/bin/python3.11"
ENTRY_POINT_SCRIPT = "reposerver_main.py" # O ponto de entrada correto!
PID_FILE = "reposerver.pid"
SRC_DIR = "cpp_engine/src"
BUILD_DIR = "cpp_engine/bindings"
WRAPPER_NAME = "pybind_wrapper"
LOG_OUT_FILE = "server.log"
LOG_ERR_FILE = "server.err.log"

# --- Funções Auxiliares ---
def print_color(text, color):
    colors = {
        "red": "\033[91m",
        "green": "\033[92m",
        "yellow": "\033[93m",
        "endc": "\033[0m",
    }
    print(f"{colors.get(color, '')}{text}{colors['endc']}")

# --- Funções de Build ---
def run_build(args):
    print_color("Iniciando processo de build do motor C++...", "yellow")
    compiler = get_compiler()
    if not compiler:
        print_color("Erro: Nenhum compilador C++ (g++ ou clang++) encontrado.", "red")
        sys.exit(1)

    try:
        pybind_includes = subprocess.check_output([PYTHON_EXEC, "-m", "pybind11", "--includes"], text=True).strip()
    except subprocess.CalledProcessError:
        print_color("Erro: pybind11 não está instalado ou não foi encontrado no path.", "red")
        sys.exit(1)

    try:
        extension_suffix = subprocess.check_output([f"{PYTHON_EXEC}-config", "--extension-suffix"], text=True).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        print_color(f"Erro: Falha ao executar \"{PYTHON_EXEC}-config\". Verifique se os pacotes de desenvolvimento do Python estão instalados.", "red")
        sys.exit(1)

    compile_command = (
        f"{compiler} -O3 -Wall -shared -std=c++11 -fPIC {pybind_includes} "
        f"{SRC_DIR}/parser.cpp {SRC_DIR}/bindings.cpp "
        f"-o {BUILD_DIR}/{WRAPPER_NAME}{extension_suffix}"
    )

    print_color(f"Executando build com o comando:", "yellow")
    print(compile_command)

    process = subprocess.run(compile_command, shell=True, capture_output=True, text=True)

    if process.returncode == 0:
        print_color("Build do motor C++ concluído com sucesso!", "green")
    else:
        print_color("Erro durante a compilação do motor C++:", "red")
        print(process.stderr)
        sys.exit(1)

# --- Funções de Gerenciamento do Servidor ---
def start_server(args):
    if os.path.exists(PID_FILE):
        print_color(f"Servidor já parece estar rodando. (PID file encontrado: {PID_FILE})", "yellow")
        return

    print_color(f"Iniciando o servidor em background via '{ENTRY_POINT_SCRIPT}'...", "green")
    try:
        log_out = open(LOG_OUT_FILE, 'w')
        log_err = open(LOG_ERR_FILE, 'w')
        process = subprocess.Popen([PYTHON_EXEC, ENTRY_POINT_SCRIPT], stdout=log_out, stderr=log_err, preexec_fn=os.setsid)
        with open(PID_FILE, "w") as f:
            f.write(str(process.pid))
        print_color(f"Servidor iniciado com sucesso. PID: {process.pid}. Logs em {LOG_OUT_FILE} e {LOG_ERR_FILE}", "green")
    except Exception as e:
        print_color(f"Falha ao iniciar o servidor: {e}", "red")
        sys.exit(1)

def stop_server(args):
    if not os.path.exists(PID_FILE):
        print_color("Servidor não parece estar rodando (PID file não encontrado).", "yellow")
        return

    with open(PID_FILE, "r") as f:
        pid = int(f.read().strip())

    print_color(f"Parando o processo do servidor (PID: {pid})...", "yellow")
    try:
        os.killpg(os.getpgid(pid), signal.SIGTERM)
        print_color("Sinal de término enviado para o grupo de processos do servidor.", "green")
    except ProcessLookupError:
        print_color("Processo do servidor não encontrado. Pode já ter sido parado.", "yellow")
    except Exception as e:
        print_color(f"Erro ao parar o servidor: {e}", "red")
    finally:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        print_color("Arquivo PID removido.", "green")

def server_status(args):
    if not os.path.exists(PID_FILE):
        print_color("Servidor está PARADO (PID file não encontrado).", "red")
        return

    with open(PID_FILE, "r") as f:
        pid = int(f.read().strip())

    try:
        os.kill(pid, 0)
    except OSError:
        print_color(f"Servidor está PARADO (processo com PID {pid} não encontrado).", "red")
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
    else:
        print_color(f"Servidor está RODANDO (PID: {pid}).", "green")

# --- Interface de Linha de Comando (CLI) ---
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Gerenciador de Engine para o projeto Reposerver.")
    subparsers = parser.add_subparsers(title="Comandos", dest="command", required=True)

    # Comando build
    build_parser = subparsers.add_parser("build", help="Compila o motor C++ e os bindings Python.")
    build_parser.set_defaults(func=run_build)

    # Comando start
    start_parser = subparsers.add_parser("start", help="Inicia o servidor web em background.")
    start_parser.set_defaults(func=start_server)

    # Comando stop
    stop_parser = subparsers.add_parser("stop", help="Para o servidor web.")
    stop_parser.set_defaults(func=stop_server)

    # Comando status
    status_parser = subparsers.add_parser("status", help="Verifica o status do servidor web.")
    status_parser.set_defaults(func=server_status)

    args = parser.parse_args()
    args.func(args)
