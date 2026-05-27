# -*- coding: utf-8 -*-

try:
    # Importa o parser C++ compilado
    from app.core.engine.cpp_core import RPGParser, Character
    CPP_AVAILABLE = True
except ImportError:
    # Fallback para uma implementação Python pura se o módulo C++ não for encontrado
    print("AVISO: Módulo C++ não encontrado. Usando fallback em Python puro.")
    CPP_AVAILABLE = False
    
    # Simula as classes para que o resto da aplicação não quebre
    class Character:
        def __init__(self):
            self.name = "N/A"
            self.char_class = "N/A"
            self.level = 0
            self.stats = {}

    class RPGParser:
        def parse_character(self, data_string: str) -> Character:
            # Implementação Python simplificada para fallback
            print("Executando parser de fallback em Python...")
            char = Character()
            # ... (a lógica de parsing Python iria aqui)
            char.name = "Fallback Character"
            return char

class RPGService:
    def __init__(self):
        self._parser = RPGParser()

    def get_character_from_string(self, data: str) -> Character:
        """Usa o parser (C++ ou Python) para converter uma string em um objeto Character."""
        if not data:
            raise ValueError("A string de dados não pode ser vazia.")
        
        character_obj = self._parser.parse_character(data)
        return character_obj

# Singleton instance
rpg_service = RPGService()
