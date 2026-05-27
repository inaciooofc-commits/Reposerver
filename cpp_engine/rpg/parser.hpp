#pragma once

#include <string>
#include <vector>
#include <map>

// Estrutura para representar um personagem de RPG
struct Character {
    std::string name;
    std::string char_class;
    int level;
    std::map<std::string, int> stats;
};

class RPGParser {
public:
    // Analisa uma string formatada e retorna um objeto Character
    // Formato esperado: "name: Aragorn, class: Ranger, level: 15, stats: {str: 18, dex: 20}"
    Character parseCharacter(const std::string& data);
};
