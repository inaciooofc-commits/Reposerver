# server.py - Main Application Entry Point

import os
import threading
import subprocess
from datetime import datetime
from flask import Flask
from authlib.integrations.flask_client import OAuth
from yt_dlp import YoutubeDL

# Centralized application configuration and utilities
from config import AppConfig
from utils import ensure_initial_files, load_json, save_status, write_log, pull_from_git, DEFAULT_STATUS

# --- Flask App Initialization ---

def create_app():
    """Creates and configures the Flask application."""
    app = Flask(__name__)
    app.secret_key = AppConfig.get('secret_key')
    app.config['SESSION_COOKIE_HTTPONLY'] = True

    # --- Global State Initialization ---
    app.queue = []
    app.current_track = None
    app.playback_thread = None
    app.player_process = None
    app.status_lock = threading.Lock()

    # --- Music Playback Logic (attached to the app context) ---
    def resolve_youtube_stream(url):
        try:
            ydl_opts = {'format': 'bestaudio/best', 'quiet': True, 'no_warnings': True, 'skip_download': True}
            with YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                title = info.get('title', url)
                stream_url = info.get('url')
                if not stream_url and info.get('formats'):
                    stream_url = info['formats'][-1].get('url')
                return stream_url, title
        except Exception as exc:
            write_log(f'Falha ao resolver YouTube: {exc}')
            return None, None

    def playback_worker():
        while app.queue:
            with app.status_lock:
                track = app.queue.pop(0)
                save_status() 
            
            write_log(f"Iniciando reprodução: {track['url']} por {track['requestor']}")
            stream_url, title = resolve_youtube_stream(track['url'])
            if not stream_url:
                write_log('Falha ao obter stream do YouTube, pulando.')
                continue

            app.current_track = {
                'title': title, 'url': track['url'], 'requestor': track['requestor'],
                'status': 'playing', 'started_at': datetime.utcnow().isoformat(),
            }
            save_status()

            try:
                app.player_process = subprocess.Popen(
                    ['mpv', '--no-video', '--really-quiet', '--audio-display=no', '--volume=72', stream_url],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
                app.player_process.wait()
                write_log(f'Faixa finalizada: {title}')
            except FileNotFoundError:
                write_log('ERRO: mpv não encontrado. A reprodução não pode continuar.')
                app.current_track['status'] = 'error'
                break
            except Exception as exc:
                write_log(f'Erro durante reprodução: {exc}')
                app.current_track['status'] = 'error'
                break
            finally:
                 app.current_track = None
                 save_status()

    app.playback_worker = playback_worker

    # --- OAuth Initialization ---
    oauth = OAuth(app)
    if AppConfig.get('google_client_id') and AppConfig.get('google_client_secret'):
        oauth.register(
            name='google',
            client_id=AppConfig.get('google_client_id'),
            client_secret=AppConfig.get('google_client_secret'),
            server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
            client_kwargs={'scope': 'openid email profile'},
        )

    # --- Blueprint Registration ---
    with app.app_context():
        from routes.auth import auth_bp
        from routes.dashboard import dashboard_bp
        from routes.admin import admin_bp
        from routes.api import api_bp

        app.register_blueprint(auth_bp)
        app.register_blueprint(dashboard_bp)
        app.register_blueprint(admin_bp)
        app.register_blueprint(api_bp)

    return app

# --- Application Execution ---
if __name__ == '__main__':
    app = create_app()
    
    with app.app_context():
        ensure_initial_files()
        if AppConfig.get('auto_update_on_start', False):
            write_log("Verificando atualizações do Git na inicialização...")
            pull_from_git()
        
        # Load the saved state
        status = load_json(STATUS_FILE, DEFAULT_STATUS)
        app.queue[:] = status.get('queue', [])
        save_status() # Save to normalize the state on startup

        # Start playback if queue is not empty
        from utils import start_playback_if_needed
        start_playback_if_needed()

    app.run(host='0.0.0.0', port=5000, debug=False)
