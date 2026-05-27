#include "parser.hpp"
#include <sstream>
#include <iostream>

// Função auxiliar para remover espaços em branco de uma string
std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\n\r");
    if (std::string::npos == first) {
        return str;
    }
    size_t last = str.find_last_not_of(" \t\n\r");
    return str.substr(first, (last - first + 1));
}

Character RPGParser::parseCharacter(const std::string& data) {
    Character ch;
    std::stringstream ss(data);
    std::string segment;

    while(std::getline(ss, segment, ',')) {
        std::stringstream segment_ss(segment);
        std::string key, value;
        std::getline(segment_ss, key, ':');
        std::getline(segment_ss, value);

        key = trim(key);
        value = trim(value);

        if (key == "name") {
            ch.name = value;
        } else if (key == "class") {
            ch.char_class = value;
        } else if (key == "level") {
            ch.level = std::stoi(value);
        } else if (key == "stats") {
            // Lógica para analisar o mapa de estatísticas
            value = trim(value.substr(1, value.size() - 2)); // remove chaves {}
            std::stringstream stats_ss(value);
            std::string stat_pair;
            while(std::getline(stats_ss, stat_pair, ';')){
                std::stringstream stat_pair_ss(trim(stat_pair));
                std::string stat_key, stat_value;
                std::getline(stat_pair_ss, stat_key, ':');
                std::getline(stat_pair_ss, stat_value);
                ch.stats[trim(stat_key)] = std::stoi(trim(stat_value));
            }
        }
    }
    return ch;
}
