import time
import os
import subprocess
import logging
from datetime import datetime

# --- Configurações do Supervisor ---
SERVICE_NAME = "reposerver"
PID_FILE = f"/var/run/{SERVICE_NAME}.pid"
APP_LOG_FILE = f"/var/log/{SERVICE_NAME}.log"
SUPERVISOR_LOG_FILE = "/var/log/supervisor.log"
CHECK_INTERVAL = 15  # segundos
RESTART_COOLDOWN = 300 # segundos (5 minutos)

# Palavras-chave de erro para procurar no log da aplicação
ERROR_KEYWORDS = ["Traceback (most recent call last)", "CRITICAL", "ERROR"]

# --- Configuração do Logging ---
logging.basicConfig(
    filename=SUPERVISOR_LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

class Supervisor:
    def __init__(self):
        self.last_restart_time = 0

    def log(self, message, level='info'):
        print(f"[{datetime.now()}] {message}") # Imprime para o console/stdout
        if level == 'info':
            logging.info(message)
        elif level == 'warning':
            logging.warning(message)
        elif level == 'error':
            logging.error(message)

    def is_service_running(self):
        """Verifica se o serviço está rodando com base no arquivo PID."""
        if not os.path.exists(PID_FILE):
            return False
        try:
            with open(PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            # A verificação de /proc/{pid} é mais confiável no Linux
            return os.path.exists(f"/proc/{pid}")
        except (IOError, ValueError):
            return False

    def restart_service(self, reason):
        """Reinicia o serviço e gerencia o cooldown."""
        current_time = time.time()
        if (current_time - self.last_restart_time) < RESTART_COOLDOWN:
            self.log(f"Tentativa de reinício ignorada devido ao cooldown. Razão: {reason}", 'warning')
            return

        self.log(f"Reiniciando o serviço '{SERVICE_NAME}'. Razão: {reason}", 'warning')
        try:
            # Usamos `service` que é o comando correto para SysVinit
            subprocess.run(["sudo", "service", SERVICE_NAME, "restart"], check=True)
            self.last_restart_time = current_time
            self.log("Comando de reinício executado com sucesso.")
        except subprocess.CalledProcessError as e:
            self.log(f"Falha ao reiniciar o serviço: {e}", 'error')
        except FileNotFoundError:
            self.log("Comando 'sudo' ou 'service' não encontrado. Verifique o PATH.", 'error')

    def analyze_logs(self):
        """Analisa as últimas linhas do log da aplicação em busca de erros."""
        if not os.path.exists(APP_LOG_FILE):
            return
        try:
            # Pega as últimas 20 linhas para análise
            result = subprocess.run(["tail", "-n", "20", APP_LOG_FILE], capture_output=True, text=True)
            for line in result.stdout.splitlines():
                if any(keyword in line for keyword in ERROR_KEYWORDS):
                    self.restart_service(f"Palavra-chave de erro encontrada no log: '{line.strip()}'")
                    # Para de verificar após encontrar o primeiro erro e tentar reiniciar
                    break
        except Exception as e:
            self.log(f"Erro ao analisar o arquivo de log: {e}", 'error')

    def run(self):
        """Loop principal do supervisor."""
        self.log("Supervisor iniciado.")
        while True:
            if not self.is_service_running():
                self.restart_service("Serviço não está rodando (PID não encontrado ou processo morto).")
            else:
                self.analyze_logs()
            
            time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    supervisor = Supervisor()
    supervisor.run()
