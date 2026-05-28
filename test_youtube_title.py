
import socketio
import time
import os
from app.utils import get_youtube_title

# --- Teste Unitário ---
def test_get_title():
    # Este teste requer uma chave de API do YouTube válida.
    # Certifique-se de que a variável de ambiente YOUTUBE_API_KEY está definida.
    if not os.getenv("YOUTUBE_API_KEY"):
        print("AVISO: YOUTUBE_API_KEY não definida. Pulando o teste unitário test_get_title().")
        return

    url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    title = get_youtube_title(url)
    print(f"URL: {url}")
    print(f"Título obtido: {title}")
    assert title == "Rick Astley - Never Gonna Give You Up (Official Music Video)"
    print("Teste unitário de get_youtube_title passou!")

# --- Teste de Integração ---
def test_socketio_integration():
    sio = socketio.Client()
    test_passed = False
    error_occurred = False

    @sio.event
    def connect():
        print("Conectado ao servidor!")
        print("Enviando evento 'add_to_queue' para o namespace /dashboard...")
        sio.emit("add_to_queue", 
                 {"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}, 
                 namespace='/dashboard')

    @sio.on('queue_update', namespace='/dashboard')
    def queue_update(data):
        nonlocal test_passed
        print(f"Fila recebida: {data}")
        expected_title = "Rick Astley - Never Gonna Give You Up (Official Music Video)"
        found = any(song.get("title") == expected_title for song in data.get('queue', []))
        assert found, f"O título esperado '{expected_title}' não foi encontrado na fila."
        print("Teste de integração Socket.IO passou!")
        test_passed = True
        sio.disconnect()

    @sio.event
    def connect_error(data):
        nonlocal error_occurred
        print(f"Falha na conexão: {data}")
        error_occurred = True

    @sio.event
    def disconnect():
        print("Desconectado do servidor.")

    try:
        print("Iniciando teste de integração Socket.IO...")
        sio.connect("http://localhost:5000", namespaces=['/dashboard'])
        sio.wait() # Espera até a desconexão
    except Exception as e:
        print(f"Erro no teste de integração: {e}")
        error_occurred = True

    if not test_passed or error_occurred:
        print("O teste de integração Socket.IO falhou.")
        # Levanta uma exceção para que a execução do script falhe
        raise AssertionError("O teste de integração Socket.IO falhou.")

if __name__ == "__main__":
    try:
        # Primeiro, executa o teste unitário
        test_get_title()
    except Exception as e:
        print(f"O teste unitário falhou: {e}")
        # Decide se deve parar ou continuar em caso de falha no teste unitário
        # Por enquanto, vamos parar para garantir que a lógica base está correta.
        exit(1)

    print("\n" + "="*30 + "\n")

    # O teste de integração só será executado se o servidor estiver rodando.
    # Este script pode ser executado em um terminal, enquanto o servidor roda em outro.
    print("Para executar o teste de integração, inicie o servidor com:")
    print("nix-shell .idx/dev.nix --run \"python run.py\"")
    print("E então, em outro terminal, descomente a linha abaixo e execute este script:")
    # test_socketio_integration()
