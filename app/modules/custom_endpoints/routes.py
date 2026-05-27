# app/modules/custom_endpoints/routes.py
from flask import Blueprint, jsonify, request
from .services import obter_status_api, obter_info_sistema, controlar_servico

# Cria um "Blueprint". Pense nisso como um mini-app ou um grupo de rotas relacionadas.
custom_endpoints_bp = Blueprint(
    'custom_endpoints_bp',
    __name__,
    url_prefix='/api/custom' # Todas as rotas neste arquivo começarão com /api/custom
)

@custom_endpoints_bp.route('/status', methods=['GET'])
def rota_status():
    """Endpoint de verificação de saúde (health check)."""
    dados = obter_status_api()
    return jsonify(dados)

@custom_endpoints_bp.route('/sistema/info', methods=['GET'])
def rota_info_sistema():
    """Endpoint que retorna informações estáticas do sistema."""
    dados = obter_info_sistema()
    if "erro" in dados:
        return jsonify(dados), 500
    return jsonify(dados)

@custom_endpoints_bp.route('/servico/controle', methods=['POST'])
def rota_controle_servico():
    """
    Endpoint para controlar o serviço principal (reposerver).
    Exemplo de corpo da requisição (body):
    { "acao": "reiniciar" } 
    Ações válidas: "reiniciar", "parar", "iniciar".
    """
    dados_requisicao = request.get_json()
    if not dados_requisicao or 'acao' not in dados_requisicao:
        return jsonify({"erro": "Corpo da requisição inválido. É esperado um JSON com uma 'acao'."}), 400
    
    acao = dados_requisicao['acao']
    dados_resposta, status_code = controlar_servico(acao)
    
    return jsonify(dados_resposta), status_code
