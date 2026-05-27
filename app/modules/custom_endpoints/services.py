# app/modules/custom_endpoints/services.py
import time
import platform
import subprocess

def obter_status_api():
    """Fornece um status básico de saúde da API."""
    return {
        "status": "operacional",
        "mensagem": "API de endpoints personalizados está funcionando.",
        "timestamp": int(time.time())
    }

def obter_info_sistema():
    """Coleta e retorna informações estáticas sobre o sistema host."""
    try:
        info = {
            "sistema_operacional": f"{platform.system()} {platform.release()}",
            "distribuicao": ' '.join(platform.dist()) if hasattr(platform, 'dist') else 'N/A', # Obsoleto em Python 3.8+
            "arquitetura": platform.machine(),
            "versao_python": platform.python_version(),
            "nome_maquina": platform.node()
        }
        return info
    except Exception as e:
        return {"erro": f"Falha ao obter informações do sistema: {e}"}

def controlar_servico(acao):
    """
    Executa uma ação de controle no serviço 'reposerver'.
    Ações válidas: 'reiniciar', 'parar', 'iniciar'.
    """
    if acao not in ['reiniciar', 'parar', 'iniciar']:
        return {"status": "falha", "erro": "Ação inválida. Use 'reiniciar', 'parar' ou 'iniciar'."}, 400

    comando = ["sudo", "service", "reposerver", acao]
    
    try:
        # Usamos check=True para lançar uma exceção se o comando falhar
        resultado = subprocess.run(comando, check=True, capture_output=True, text=True)
        mensagem_sucesso = f"Serviço 'reposerver' foi instruído a '{acao}' com sucesso."
        return {"status": "sucesso", "mensagem": mensagem_sucesso, "output": resultado.stdout}, 200
    except FileNotFoundError:
        return {"status": "falha", "erro": "Comando 'sudo' ou 'service' não encontrado."}, 500
    except subprocess.CalledProcessError as e:
        # O comando foi encontrado, mas retornou um código de erro
        erro_detalhado = f"Comando falhou com código {e.returncode}. Output: {e.stderr}"
        return {"status": "falha", "erro": erro_detalhado}, 500
