
import os
import re
from flask import current_app
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from run import socketio

# --- Variáveis Globais ---
song_queue = []
youtube_service = None # Variável para cachear o serviço do YouTube

def get_youtube_service():
    """
    Inicializa e retorna o serviço da API do YouTube de forma preguiçosa (lazy).
    Cacheia o serviço em uma variável global para evitar reinicializações.
    """
    global youtube_service

    # Se já tentamos inicializar antes (com sucesso ou falha), retorna o resultado.
    if youtube_service is not None:
        return youtube_service if youtube_service else None

    api_key = os.getenv("YOUTUBE_API_KEY")
    if not api_key:
        current_app.logger.warning("A variável de ambiente YOUTUBE_API_KEY não está definida.")
        youtube_service = False  # Marca como falha para não tentar de novo.
        return None
    
    try:
        service = build('youtube', 'v3', developerKey=api_key)
        youtube_service = service  # Cacheia o serviço com sucesso.
        return service
    except Exception as e:
        current_app.logger.error(f"Falha ao inicializar o serviço do YouTube: {e}")
        youtube_service = False  # Marca como falha.
        return None

def get_video_id(url):
    """Extrai o ID do vídeo de uma URL do YouTube."""
    regex = r"(?:https\:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|watch\?v=|v\/|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})"
    match = re.search(regex, url)
    return match.group(1) if match else None

# --- Handlers de Socket.IO ---

@socketio.on('connect', namespace='/dashboard')
def handle_dashboard_connect():
    current_app.logger.info("Cliente conectado ao dashboard.")
    socketio.emit('queue_update', {'queue': song_queue}, namespace='/dashboard')

@socketio.on('disconnect', namespace='/dashboard')
def handle_dashboard_disconnect():
    current_app.logger.info("Cliente desconectado do dashboard.")

@socketio.on('add_to_queue', namespace='/dashboard')
def handle_add_to_queue(data):
    youtube_url = data.get('url')
    video_id = get_video_id(youtube_url)

    if not video_id:
        socketio.emit('error', {'message': 'URL do YouTube inválida.'}, namespace='/dashboard')
        return

    title = f"Vídeo ID: {video_id}"
    
    service = get_youtube_service() # Obtém o serviço (inicializa se necessário)

    if service:
        try:
            request = service.videos().list(part="snippet", id=video_id)
            response = request.execute()
            
            if response.get('items'):
                title = response['items'][0]['snippet']['title']
            else:
                socketio.emit('error', {'message': 'Vídeo não encontrado.'}, namespace='/dashboard')
                return
        except HttpError as e:
            current_app.logger.error(f"Erro na API do YouTube: {e}")
            socketio.emit('error', {'message': 'Erro ao buscar informações do vídeo.'}, namespace='/dashboard')
            return

    song_info = {'title': title, 'url': youtube_url, 'requester': 'user_id_placeholder'}
    song_queue.append(song_info)
    current_app.logger.info(f"Nova música adicionada: {title}")
    socketio.emit('queue_update', {'queue': song_queue}, namespace='/dashboard', broadcast=True)
