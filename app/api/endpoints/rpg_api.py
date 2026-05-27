# -*- coding: utf-8 -*-

from flask import Blueprint, request, jsonify
from app.services.rpg_service import rpg_service

rpg_api_bp = Blueprint('rpg_api', __name__, url_prefix='/api/rpg')

@rpg_api_bp.route('/parse', methods=['POST'])
def parse_character():
    """Recebe uma string de personagem via POST e a retorna como um objeto JSON."""
    data = request.json
    if not data or 'character_string' not in data:
        return jsonify({"error": "A chave 'character_string' é obrigatória."}), 400

    try:
        char_string = data['character_string']
        character = rpg_service.get_character_from_string(char_string)
        
        # Converte o objeto Character (que pode ser C++ ou Python) para um dicionário
        response_data = {
            "name": character.name,
            "class": character.char_class,
            "level": character.level,
            "stats": character.stats
        }
        return jsonify(response_data)

    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        # Log do erro aqui seria uma boa prática
        return jsonify({"error": f"Ocorreu um erro interno: {e}"}), 500
