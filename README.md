# Company RAG: Ollama + Qwen + BGE-M3 + Open WebUI

A self-hosted assistant that answers questions from company documents. Everything runs on your own server; no data leaves it.

| Component | Role |
|---|---|
| **Ollama** | Runs the models (internal network only, not exposed) |
| **Qwen3** (`qwen3:8b` by default) | Chat / answer generation |
| **BGE-M3** (`bge-m3`) | Multilingual embeddings for document retrieval |
| **BGE-reranker-v2-m3** | Reranks retrieved chunks (hybrid search) |
| **Open WebUI** | Web frontend: chat, users, document upload, knowledge bases |

```
Browser ──► Open WebUI :3000 ──► Ollama :11434 (internal)
               │                   ├─ qwen3   (chat)
               │                   └─ bge-m3  (embeddings)
               └─ ChromaDB + uploaded files (volume: open-webui-data)
```

## Requirements

- Linux with Docker Engine and the Docker Compose plugin (v2.20+)
- **Recommended:** NVIDIA GPU with 8 GB+ VRAM, plus the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html). CPU-only works, but answers will be slow.
- About 15 GB of disk for images and models, plus space for your documents

## Installation guides

- [Arch Linux](INSTALL-ARCH.md)
- [Fedora Server](INSTALL-FEDORA.md)

## Quick start

```bash
cp .env.example .env
sed -i "s/^WEBUI_SECRET_KEY=.*/WEBUI_SECRET_KEY=$(openssl rand -hex 32)/" .env
# Edit .env: CHAT_MODEL, WEBUI_URL, WEBUI_BIND_ADDRESS, ...

# With an NVIDIA GPU:
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d

# CPU only:
docker compose up -d

# Follow the model download (first start only, several GB):
docker compose logs -f model-init
```

Then open `http://<server>:3000` and **create the first account right away. It becomes the admin.** Later sign-ups get the `pending` role until an admin approves them under *Admin Panel → Users*.

> By default the UI binds to `127.0.0.1` so it can sit behind a reverse proxy with HTTPS (see below). To reach it directly from the LAN for testing, set `WEBUI_BIND_ADDRESS=0.0.0.0`.

## Uploading company documents

**Shared knowledge bases (recommended for company documents)**
1. *Workspace → Knowledge → +* to create a collection (e.g. "HR Policies").
2. Upload files or whole folders (PDF, DOCX, XLSX, PPTX, TXT, MD, HTML, CSV, ...). They are chunked and embedded with BGE-M3.
3. Choose who can access it (private, specific groups, or public).
4. In a chat, type `#` and pick the collection, or attach it to a model permanently (below).

**One-off files in a chat:** use the paperclip (+) button in the message box.

**A "Company Assistant" model with knowledge built in:** *Workspace → Models → +*, base model `qwen3:8b`, attach your knowledge collections, add a system prompt such as *"Answer only from the provided company documents and cite the source. If the answer is not in the documents, say so."*, and set visibility. Users then just pick that model.

Use groups (*Admin Panel → Users → Groups*) to control who may upload documents and who can see which knowledge bases.

## Configuration notes

- **Settings are stored on first start.** Open WebUI saves most RAG/embedding settings in its database on first launch. Later changes to `.env` for those values do **not** take effect. Change them in *Admin Panel → Settings → Documents* instead, or set `ENABLE_PERSISTENT_CONFIG=false` to make env vars always win.
- **Changing the embedding model** (e.g. away from `bge-m3`) means existing documents must be re-embedded: *Admin Panel → Settings → Documents → Reindex*.
- **Model size:** see the VRAM guide in `.env.example`. `qwen3:14b` or `qwen3:30b-a3b` give noticeably better answers if you have the VRAM. After changing `CHAT_MODEL`, run `docker compose up -d` again and `model-init` pulls the new model.
- **Qwen3 "thinking"**: Qwen3 reasons before answering by default. For faster, shorter replies, add `/no_think` to the model's system prompt (Workspace → Models).
- **Reranker:** `BAAI/bge-reranker-v2-m3` is downloaded from Hugging Face by Open WebUI on first use (about 2.3 GB, runs on CPU in the WebUI container). To turn it off, set `ENABLE_RAG_HYBRID_SEARCH=false`.
- **Scanned PDFs / OCR:** the built-in extractor reads text layers only. For scans, add an Apache Tika or Docling container and set `CONTENT_EXTRACTION_ENGINE`.

## HTTPS reverse proxy (example: Caddy on the host)

```caddyfile
rag.example.com {
    reverse_proxy 127.0.0.1:3000
}
```

Set `WEBUI_URL=https://rag.example.com` in `.env`. With nginx, enable WebSocket upgrade headers and raise `client_max_body_size` (e.g. `100M`) for uploads.

## Operations

```bash
docker compose ps                      # status
docker compose logs -f open-webui      # logs
docker compose exec ollama ollama ps   # loaded models / GPU usage

# Update (pin versions in .env for predictable upgrades)
docker compose pull && docker compose up -d

# Back up users, chats, documents and vector DB
mkdir -p backups
docker run --rm -v company-rag_open-webui-data:/data -v "$PWD/backups":/backup \
  alpine tar czf /backup/open-webui-$(date +%F).tar.gz -C /data .

# Restore (stop first)
docker compose stop open-webui
docker run --rm -v company-rag_open-webui-data:/data -v "$PWD/backups":/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/open-webui-YYYY-MM-DD.tar.gz -C /data"
docker compose start open-webui
```

Models in `ollama-data` do not need backing up. They can be pulled again.
