#include <pybind11/pybind11.h>
#include <pybind11/stl.h> // Necessário para conversão automática de map, vector, etc.
#include "../rpg/parser.hpp"

namespace py = pybind11;

PYBIND11_MODULE(cpp_core, m) {
    // Docstrings do módulo
    m.doc() = "Módulo C++ de alta performance para Reposerver.";

    // 1. Expondo a struct 'Character' como uma classe Python
    py::class_<Character>(m, "Character")
        .def(py::init<>()) // Construtor padrão
        .def_readwrite("name", &Character::name)
        .def_readwrite("char_class", &Character::char_class)
        .def_readwrite("level", &Character::level)
        .def_readwrite("stats", &Character::stats)
        // Adiciona uma representação de string amigável (__repr__ em Python)
        .def("__repr__",
            [](const Character &c) {
                std::string stats_str = "{";
                for(const auto& pair : c.stats) {
                    stats_str += "'" + pair.first + "': " + std::to_string(pair.second) + ", ";
                }
                if (stats_str.length() > 1) {
                    stats_str = stats_str.substr(0, stats_str.length() - 2); // remove a última vírgula e espaço
                }
                stats_str += "}";
                return "<Character name='" + c.name + "', class='" + c.char_class + 
                       "', level=" + std::to_string(c.level) + ", stats=" + stats_str + ">";
            }
        );

    // 2. Expondo a classe 'RPGParser'
    py::class_<RPGParser>(m, "RPGParser")
        .def(py::init<>()) // Construtor
        .def("parse_character", &RPGParser::parseCharacter, 
             "Analisa uma string de dados de personagem e retorna um objeto Character.",
             py::arg("data_string"));
}
