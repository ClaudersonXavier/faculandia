#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${1:-${GODOT:-godot}}"

if ! command -v "$GODOT_BIN" &> /dev/null; then
    echo "Erro: Executável do Godot ('$GODOT_BIN') não foi encontrado no PATH." >&2
    echo "Dica: Defina a variável GODOT apontando para o binário (ex: make run GODOT=/caminho/godot)." >&2
    exit 1
fi

echo "Verificando e gerando cache/assets do Godot em '$PROJECT_DIR'..."
"$GODOT_BIN" --path "$PROJECT_DIR" --headless --editor --quit

CACHE_FILE="$PROJECT_DIR/.godot/global_script_class_cache.cfg"
if [ -f "$CACHE_FILE" ]; then
    echo "Sucesso: Cache global de classes e assets inicializados com sucesso!"
else
    echo "Aviso: A importação foi executada, mas '$CACHE_FILE' não foi encontrado." >&2
    exit 1
fi
