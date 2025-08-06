
# Guacamole with Docker Compose

This is a small documentation on how to run a fully working **Apache Guacamole** instance with Docker Compose. The goal of this project is to make it easy to test and deploy Guacamole.

## About Guacamole

Apache Guacamole is a clientless remote desktop gateway. It supports standard protocols like **VNC**, **RDP**, **SSH**, and **Telnet**. No client software or plugins are required — everything runs in the browser via HTML5.

See the [official project homepage](https://guacamole.incubator.apache.org/) for more information.

## Optional

To create an SSH key pair in your home directory:

```bash
ssh-keygen
```

## Prerequisites

You need a working installation of:

- Docker
- Docker Compose

## Quick Start

```bash
git clone https://github.com/rkajy/guacamole-docker-compose-debian-xfce.git
cd guacamole-docker-compose
./prepare.sh
docker compose up -d
```

Your Guacamole server will now be available at:  
📍 `https://<your-server-ip>:8443/`  
🧑 Default credentials: `guacadmin` / `guacadmin`

---

## VNC Server Setup on Debian/Ubuntu

This section explains how to configure a VNC server inside your Debian/Ubuntu machine for use with Guacamole.

### 1. Install Required Packages

```bash
sudo apt update
sudo apt install -y xfce4 xfce4-goodies tightvncserver
```

### 2. Set VNC Password

```bash
vncpasswd
```

- Use a password (max 8 characters), then confirm.
- Deny read-only password.

### 3. First Launch to Generate Config Files

```bash
vncserver :1
vncserver -kill :1
```

### 4. Configure Startup Script

Edit the file:

```bash
nano ~/.vnc/xstartup
```

Replace content with:

```bash
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
```

Then:

```bash
chmod +x ~/.vnc/xstartup
```

### 5. Create Startup Script

```bash
nano ~/start-vnc.sh
```

Content:

```bash
#!/bin/bash
vncserver -kill :1
vncserver :1 -geometry 1920x1080 -depth 24
```

Make it executable:

```bash
chmod +x ~/start-vnc.sh
./start-vnc.sh
```

### 6. Verify the Server is Running

```bash
ps aux | grep Xtightvnc
# or
vncserver -list
```

### 7. Open Required Ports in Firewall / AWS Security Group

- **5901** (VNC)
- **8080** (Guacamole)
- **22** (SSH)

⚠️ Never expose port 5901 publicly without a firewall or SSH tunneling.

### 8. Connect via Guacamole

In Guacamole, create a connection using:

- **Protocol**: VNC
- **Hostname**: `<your-EC2-IP>:5901`
- **Password**: The VNC password you set

📏 Recommended screen resolution: `1920x1080` or `1600x900`

---

## Docker Compose Breakdown

### Networking

```yaml
networks:
  guacnetwork_compose:
    driver: bridge
```

### Services

#### guacd

```yaml
guacd:
  container_name: guacd_compose
  image: guacamole/guacd
  networks:
    guacnetwork_compose:
  restart: always
  volumes:
    - ./drive:/drive:rw
    - ./record:/record:rw
```

#### PostgreSQL

```yaml
postgres:
  container_name: postgres_guacamole_compose
  environment:
    PGDATA: /var/lib/postgresql/data/guacamole
    POSTGRES_DB: guacamole_db
    POSTGRES_PASSWORD: ChooseYourOwnPasswordHere1234
    POSTGRES_USER: guacamole_user
  image: postgres
  networks:
    guacnetwork_compose:
  restart: always
  volumes:
    - ./init:/docker-entrypoint-initdb.d:ro
    - ./data:/var/lib/postgresql/data:rw
```

#### Guacamole

```yaml
guacamole:
  container_name: guacamole_compose
  depends_on:
    - guacd
    - postgres
  environment:
    GUACD_HOSTNAME: guacd
    POSTGRES_DATABASE: guacamole_db
    POSTGRES_HOSTNAME: postgres
    POSTGRES_PASSWORD: ChooseYourOwnPasswordHere1234
    POSTGRES_USER: guacamole_user
  image: guacamole/guacamole
  links:
    - guacd
  networks:
    guacnetwork_compose:
  ports:
    - 8080/tcp
  restart: always
```

#### nginx (HTTPS Reverse Proxy)

```yaml
nginx:
  container_name: nginx_guacamole_compose
  restart: always
  image: nginx
  volumes:
    - ./nginx/templates:/etc/nginx/templates:ro
    - ./nginx/ssl/self.cert:/etc/nginx/ssl/self.cert:ro
    - ./nginx/ssl/self-ssl.key:/etc/nginx/ssl/self-ssl.key:ro
  ports:
    - 8443:443
  links:
    - guacamole
  networks:
    guacnetwork_compose:
```

---

## prepare.sh

This script does the following:

- Generates the Guacamole PostgreSQL schema:

```bash
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > ./init/initdb.sql
```

- Creates a self-signed HTTPS certificate in `./nginx/ssl/`.

---

## reset.sh

To clean and reset everything:

```bash
./reset.sh
```

---

## 🔐 Disclaimer

Downloading and executing scripts from the internet may harm your computer. Always review and trust the sources before running them.
