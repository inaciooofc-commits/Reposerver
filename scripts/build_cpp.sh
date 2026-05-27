#!/bin/bash
# build_cpp.sh

# Ativa o modo de falha rápida
set -e

# Define cores para a saída
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

# Encontra o diretório raiz do projeto
PROJECT_ROOT="$( cd "$(dirname "$0")"/.. && pwd )"

# Define os caminhos de origem e destino
CPP_SOURCE_DIR="$PROJECT_ROOT/cpp_engine/src"
OUTPUT_DIR="$PROJECT_ROOT/app/services"

# Nome do módulo de saída
MODULE_NAME="cpp_core"

# Encontra o executável do Python
PYTHON_EXECUTABLE="$(sh -c 'command -v python3 || command -v python')"

# Obtém os caminhos de inclusão do pybind11 e do Python
PYBIND_INCLUDE_PATH=$($PYTHON_EXECUTABLE -m pybind11 --includes)
PYTHON_INCLUDE_PATH=$($PYTHON_EXECUTABLE-config --includes)

# Compila o código C++
OUTPUT_FILE="$OUTPUT_DIR/${MODULE_NAME}$($PYTHON_EXECUTABLE -c \"import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))\" )"

echo "=================================================="
echo "Compilando o Módulo C++..."
echo "Usando Python: $PYTHON_EXECUTABLE"
echo "Destino: $OUTPUT_FILE"
echo "=================================================="

g++ -O3 -Wall -shared -std=c++11 -fPIC $PYBIND_INCLUDE_PATH $PYTHON_INCLUDE_PATH \
    "$CPP_SOURCE_DIR/bindings.cpp" \
    -o "$OUTPUT_FILE"

echo -e "${GREEN}SUCESSO:${NC} Módulo C++ compilado em ${OUTPUT_FILE}"
