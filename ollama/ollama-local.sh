#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="$HOME/apps"
OLLAMA_DIR="$APP_DIR/ollama"
MODEL_DIR="$APP_DIR/gemma4-e4b-uncensored"

mkdir -p "$OLLAMA_DIR" "$MODEL_DIR"

download() {
  local url="$1"
  local output="$2"

  echo "Downloading: $(basename "$output")"
  curl -fL --retry 3 --progress-bar "$url" -o "$output"
}

# Download Ollama
download \
  "https://ollama.com/download/ollama-linux-amd64.tar.zst" \
  "$OLLAMA_DIR/ollama-linux-amd64.tar.zst"

# Download the actual GGUF files, not Hugging Face HTML pages
BASE_URL="https://huggingface.co/HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive/resolve/main"

download \
  "$BASE_URL/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf" \
  "$MODEL_DIR/gemma4-e4b-uncensored.gguf"

download \
  "$BASE_URL/mmproj-Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-f16.gguf" \
  "$MODEL_DIR/mmproj.gguf"

cp ~/SourceApps/ollama/Modelfile ~/apps/gemma4-e4b-uncensored/
cp ~/SourceApps/ollama/ai-start ~/.local/bin/

echo
echo "All downloads completed successfully."
echo "Files saved under: $APP_DIR"
