#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <sstream>

// Estrutura para representar um personagem
struct Character {
    std::string name;
    std::string char_class;
    int level;
    std::map<std::string, int> stats;
};

class RPGParser {
public:
    // Analisa uma string formatada e retorna um objeto Character
    Character parse_character(const std::string& data_string) {
        Character character;
        std::stringstream ss(data_string);
        std::string segment;
        
        while (std::getline(ss, segment, ',')) {
            std::stringstream segment_ss(segment);
            std::string key, value;
            std::getline(segment_ss, key, ':');
            std::getline(segment_ss, value);

            // Remove espaços em branco
            key.erase(0, key.find_first_not_of(" \t\n\r"));
            key.erase(key.find_last_not_of(" \t\n\r") + 1);
            value.erase(0, value.find_first_not_of(" \t\n\r"));
            value.erase(value.find_last_not_of(" \t\n\r") + 1);

            if (key == "name") {
                character.name = value;
            } else if (key == "class") {
                character.char_class = value;
            } else if (key == "level") {
                character.level = std::stoi(value);
            } else if (key == "stats") {
                // Analisa o bloco de estatísticas
                parse_stats(value, character.stats);
            }
        }
        return character;
    }

private:
    // Função auxiliar para analisar o bloco de estatísticas
    void parse_stats(const std::string& stats_string, std::map<std::string, int>& stats_map) {
        std::stringstream ss(stats_string);
        std::string stat;
        // Remove os caracteres de abre e fecha chaves/parênteses
        std::string clean_string = stats_string.substr(stats_string.find_first_of("{(") + 1);
        clean_string = clean_string.substr(0, clean_string.find_last_of("})" ) -1);

        std::stringstream clean_ss(clean_string);

        while (std::getline(clean_ss, stat, ';')) {
            std::stringstream stat_ss(stat);
            std::string name, value_str;
            std::getline(stat_ss, name, ':');
            std::getline(stat_ss, value_str);
            
            name.erase(0, name.find_first_not_of(" \t"));
            name.erase(name.find_last_not_of(" \t") + 1);

            stats_map[name] = std::stoi(value_str);
        }
    }
};
