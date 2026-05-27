# -*- coding: utf-8 -*-

import os
from app.core import create_app

# Obtém o nome da configuração do ambiente, com 'development' como padrão.
env_name = os.getenv('FLASK_ENV', 'development')

# Cria a instância da aplicação Flask usando a factory.
app = create_app(env_name)

if __name__ == '__main__':
    # Executa a aplicação.
    # O host '0.0.0.0' torna o servidor acessível na rede local.
    # O modo de depuração e recarregamento será controlado pela configuração do Flask.
    app.run(host='0.0.0.0')
