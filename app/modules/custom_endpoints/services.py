# app/modules/custom_endpoints/services.py
import time

def obter_status_api():
    """Fornece um status básico de saúde da API."""
    return {
        "status": "operacional",
        "mensagem": "API de endpoints personalizados está funcionando.",
        "timestamp": int(time.time())
    }
