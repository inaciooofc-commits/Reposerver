# -*- coding: utf-8 -*-

import os
import logging
from logging.handlers import RotatingFileHandler
from flask import Flask, jsonify

from config.settings import config_by_name

def create_app(config_name: str) -> Flask:
    """Factory para criar e configurar a instância da aplicação Flask."""
    app = Flask(__name__, 
              instance_relative_config=True,
              static_folder='../../frontend/static', # Aponta para o novo local de estáticos
              template_folder='../../frontend/templates') # Aponta para o novo local de templates

    # 1. Carregar configuração
    config = config_by_name[config_name]
    app.config.from_object(config)

    # 2. Garantir que os diretórios de instância e logs existam
    try:
        if not os.path.exists(app.instance_path):
            os.makedirs(app.instance_path)
        
        log_dir = os.path.join(app.root_path, '..', 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)
    except OSError as e:
        app.logger.error(f"Erro ao criar diretórios necessários: {e}")

    # 3. Configurar Logging
    log_file = os.path.join(app.root_path, '..', 'logs', 'reposerver.log')
    log_handler = RotatingFileHandler(
        log_file,
        maxBytes=10485760,  # 10 MB
        backupCount=5
    )
    log_formatter = logging.Formatter(
        '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
    )
    log_handler.setFormatter(log_formatter)
    
    if not app.debug or os.environ.get('WERKZEUG_RUN_MAIN') == 'true':
        app.logger.addHandler(log_handler)
        app.logger.setLevel(app.config['LOG_LEVEL'])
    
    app.logger.info(f"Reposerver iniciando no ambiente '{config_name}'.")

    # 4. Registrar Blueprints
    from app.api.endpoints.main_views import main_bp
    app.register_blueprint(main_bp)
    app.logger.info("Blueprint 'main' registrado.")

    # 5. Adicionar um endpoint de healthcheck/ping
    @app.route('/ping')
    def ping():
        """Endpoint simples para verificar se a aplicação está viva.""" 
        return jsonify({"status": "ok", "message": "pong"})

    app.logger.info("Aplicação criada com sucesso.")
    return app
