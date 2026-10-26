#!/bin/sh
# Pulls the chat and embedding models into the shared Ollama volume.
set -eu

for model in "$CHAT_MODEL" "$EMBEDDING_MODEL"; do
  echo ">>> Pulling $model"
  ollama pull "$model"
done

echo ">>> Available models:"
ollama list
