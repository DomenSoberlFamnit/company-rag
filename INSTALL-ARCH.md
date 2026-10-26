# Installation on Arch Linux

These steps assume a fresh Arch Linux server and an account with root access. They install Docker Engine and the Compose v2 plugin from the Arch repositories, then run this project as a dedicated service account.

## 1. Update Arch and install packages

As root, update the system and install Docker, Compose, Git, OpenSSL, and Nano:

```sh
pacman -Syu --needed docker docker-compose git openssl nano
```

Start Docker now and on future boots:

```sh
systemctl enable --now docker
```

Confirm Docker Compose is available:

```sh
docker compose version
```

## 2. Create a service user and group

Create a system group and a non-login system user. The user owns the project files and is added to Docker's `docker` group so it can run Compose:

```sh
groupadd --system company-rag
useradd --system --gid company-rag --home-dir /opt/company-rag \
  --create-home --shell /usr/bin/false company-rag
usermod --append --groups docker company-rag
```

> **Security:** membership in the `docker` group grants root-equivalent access to the host. Keep this account and its project files restricted to trusted administrators.

## 3. Put the project on the server

Clone the project into the service account's home directory. Replace `REPOSITORY_URL` with the Git URL for this project:

```sh
runuser -u company-rag -- git clone REPOSITORY_URL /opt/company-rag
```

If you have already copied or cloned the project elsewhere, move it to `/opt/company-rag` and make the service account its owner:

```sh
chown -R company-rag:company-rag /opt/company-rag
```

## 4. Configure the application

Create the environment file and generate a unique secret key:

```sh
runuser -u company-rag -- sh -c '
  cd /opt/company-rag &&
  cp .env.example .env &&
  chmod 600 .env &&
  sed -i "s/^WEBUI_SECRET_KEY=.*/WEBUI_SECRET_KEY=$(openssl rand -hex 32)/" .env
'
```

Edit the environment file and set at least the public URL and desired bind address:

```sh
runuser -u company-rag -- nano /opt/company-rag/.env
```

By default, the web UI listens only on `127.0.0.1:3000`, which is suitable when placing it behind a reverse proxy. Set `WEBUI_BIND_ADDRESS=0.0.0.0` only if you intend to expose it directly on the network; configure your firewall accordingly. Do not expose Ollama's internal port `11434`.

## 5. Start the stack

For CPU-only operation:

```sh
runuser -u company-rag -- sh -c 'cd /opt/company-rag && docker compose up -d'
```

For NVIDIA GPU operation, first install and configure a compatible NVIDIA driver and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) for Arch Linux. Then start with the GPU override:

```sh
runuser -u company-rag -- sh -c \
  'cd /opt/company-rag && docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d'
```

The first start downloads the container images and models. Follow the model initialization with:

```sh
runuser -u company-rag -- sh -c 'cd /opt/company-rag && docker compose logs -f model-init'
```

When initialization finishes, open `http://<server-address>:3000` if you configured the UI to listen on the network, or access it through your reverse proxy. Create the first account immediately; it becomes the administrator.

## 6. Check and operate the stack

Run Compose commands as the service account from the project directory:

```sh
runuser -u company-rag -- sh -c 'cd /opt/company-rag && docker compose ps'
runuser -u company-rag -- sh -c 'cd /opt/company-rag && docker compose logs -f open-webui'
```

See the main [README](README.md) for document uploads, HTTPS reverse proxy configuration, backups, and updates.
