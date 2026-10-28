#FROM ./Gemma-4-E4B.gguf
#PARAMETER temperature 0.7
#PARAMETER num_ctx 8192
#SYSTEM You are a helpful assistant.

# ln -s ~/apps/ollama-linux-amd64/lib/ollama/llama-server ~/.local/bin/llama-server
ollama serve
ollama create gemma4-e4b-uncensored
# ollama run gemma4-e4b-uncensored --think=false
