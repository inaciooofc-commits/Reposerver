#include <pybind11/pybind11.h>
#include <pybind11/stl.h> // Para conversão automática de std::vector, std::map, etc.
#include "parser.cpp" // Incluímos o cpp diretamente para simplificar a compilação

namespace py = pybind11;

// A macro PYBIND11_MODULE define a função que será chamada quando o módulo for importado em Python
PYBIND11_MODULE(cpp_core, m) {
    m.doc() = "Módulo C++ de alta performance para o Reposerver.";

    // Expõe a struct/classe Character para o Python
    py::class_<Character>(m, "Character")
        .def(py::init<>()) // Construtor padrão
        .def_readwrite("name", &Character::name)
        .def_readwrite("char_class", &Character::char_class)
        .def_readwrite("level", &Character::level)
        .def_readwrite("stats", &Character::stats)
        .def("__repr__", // Define uma representação em string para o objeto, útil para debugging
             [](const Character &c) {
                 return "<Character name='" + c.name + "' class='" + c.char_class + "'>";
             }
        );

    // Expõe a classe RPGParser para o Python
    py::class_<RPGParser>(m, "RPGParser")
        .def(py::init<>()) // Construtor
        .def("parse_character", &RPGParser::parse_character,
             "Analisa uma string e retorna um objeto Character",
             py::arg("data_string")); // Nomeia o argumento em Python
}
