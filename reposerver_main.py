#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Main entry point for the Reposerver application."""

import os
from app.core import create_app

# Cria a aplicação usando a factory, detectando o ambiente pelo ENV
# O padrão é 'development' se a variável de ambiente não for definida
env = os.getenv("FLASK_ENV", "development")
app = create_app(env)

if __name__ == '__main__':
    # Este bloco é primariamente para desenvolvimento local.
    # Em produção, um servidor WSGI como Gunicorn será usado, apontando para 'reposerver_main:app'.
    app.run(host=app.config.get("HOST", "0.0.0.0"), 
            port=app.config.get("PORT", 5000))
