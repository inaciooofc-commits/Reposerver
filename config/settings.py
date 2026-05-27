# -*- coding: utf-8 -*-

import os
import logging

class Config:
    """Configuração base. Contém valores que são compartilhados por todos os ambientes."""
    # Chave secreta para assinar sessões e tokens. DEVE ser alterada em produção.
    SECRET_KEY = os.getenv('SECRET_KEY', 'uma-chave-secreta-padrao-deve-ser-alterada')
    
    # Configuração de Logging
    LOG_LEVEL = logging.INFO

    # Desativa o sistema de tracking de modificações do SQLAlchemy, que será removido.
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Configurações personalizadas da aplicação
    APP_NAME = "Reposerver"
    APP_VERSION = "2.0.0-alpha"

    @staticmethod
    def init_app(app):
        """Inicializações específicas da aplicação podem ser feitas aqui."""
        pass

class DevelopmentConfig(Config):
    """Configuração para o ambiente de desenvolvimento."""
    DEBUG = True
    LOG_LEVEL = logging.DEBUG
    
    # Em desenvolvimento, usamos um banco de dados SQLite simples.
    SQLALCHEMY_DATABASE_URI = os.getenv('DEV_DATABASE_URI', 'sqlite:///../instance/reposerver-dev.db')

class TestingConfig(Config):
    """Configuração para o ambiente de testes."""
    TESTING = True
    DEBUG = True
    LOG_LEVEL = logging.WARNING

    # Usa um banco de dados em memória para os testes serem rápidos e isolados.
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    
class ProductionConfig(Config):
    """Configuração para o ambiente de produção."""
    DEBUG = False
    TESTING = False
    LOG_LEVEL = logging.INFO

    # Em produção, a URI do banco de dados DEVE ser fornecida via variável de ambiente.
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URI', 'sqlite:///../instance/reposerver.db')

    @classmethod
    def init_app(cls, app):
        Config.init_app(app)
        # Em produção, podemos adicionar inicializações mais robustas, como 
        # enviar logs por email para administradores em caso de erro.
        # (Exemplo de código para isso seria adicionado aqui)

# Dicionário que mapeia nomes de configuração para suas respectivas classes.
config_by_name = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    
    # Default
    'default': DevelopmentConfig
}
