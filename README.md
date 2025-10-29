
# Guacamole with Docker Compose

This is a small documentation on how to run a fully working **Apache Guacamole** instance with Docker Compose. The goal of this project is to make it easy to test and deploy Guacamole.

## About Guacamole

Apache Guacamole is a clientless remote desktop gateway. It supports standard protocols like **VNC**, **RDP**, **SSH**, and **Telnet**. No client software or plugins are required — everything runs in the browser via HTML5.

See the [official project homepage](https://guacamole.incubator.apache.org/) for more information.

## Prerequisites

You need a working installation of:

- Docker
- Docker Compose

## Set up SSH connection in your virtual machine

In your Virtualbox network setting, follow this:

### Option 1:

<img width="655" height="340" alt="image" src="https://github.com/user-attachments/assets/9cdc5ac9-ae94-4471-9866-40cdc7cf9898" />

- Go to Adapter 1
- Enable Network Adapter
- Attached to: Bridged Adapter
- Name: en0 Ethernet
- Press OK

### Option 2:

- Shut down the VM
- Go to Settings -> Network -> Adapter 1
- Put NAT on Attached to:
- Then click Advanced -> Port Fowarding

- Add those rules:
<img width="819" height="171" alt="image" src="https://github.com/user-attachments/assets/33bf7113-e6a2-4136-8e7c-2d4cc9ea2c65" />

- Then connect with, randandri is the username

```bash
ssh radandri@127.0.0.1 -p 4242
```

Install:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

Update this file:

```bash
sudo nano /etc/ssh/sshd_config
```

And:

- Disable root SSH connection: PermitRootLogin no
- Change default's port: (eg: Port 4242)

- restart service:

```bash
sudo system restart ssh
```
- actual status:

```bash
sudo systemctl status ssh
```

Connet from your host machine
```bash
ssh <username>@<IP_VM>
```

### To check your VM's IP adress
```bash
ip a | grep inet
```

## Quick Start

```bash
git clone https://github.com/rkajy/guacamole-docker-compose-debian-xfce.git
cd guacamole-docker-compose
./prepare.sh
docker compose up -d
```

Your Guacamole server will now be available at:  
📍 `https://<your-server-ip>:8443/guacamole/#/`  
🧑 Default credentials: `guacadmin` / `guacadmin`

---

## VNC Server Setup on Debian/Ubuntu

This section explains how to configure a VNC server inside your Debian/Ubuntu machine for use with Guacamole.

### 1. Install Required Packages

```bash
sudo apt update
sudo apt install -y xfce4 xfce4-goodies tightvncserver dbus-x11 x11-xserver-utils
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
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
export DISPLAY=:1
xrdb $HOME/.Xresources
dbus-launch startxfce4 &
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
Option 1:

```bash
ps aux | grep Xtightvnc
# or
vncserver -list
```

Option 2:

```bash
ss -tlnp | grep 590
```

Then:

you should have this line:

```bash
LISTEN 0 5 0.0.0.0:5901...
```

To see VNC's log:

```bash
cat ~/.vnc/$(hostname):1.log
```
### 7. Open Required Ports in Firewall / AWS Security Group

- **5901** (VNC)
- **8080** (Guacamole)
- **22** (SSH)

if needed because you got this error message "Connection refused", run:

```bash
sudo ufw allow 5901/tcp
```

⚠️ Never expose port 5901 publicly without a firewall or SSH tunneling.

### 8. Connect via Guacamole

From your web browser:

```bash
http://<VM_IP_ADRESS>:8081/guacamole/#/
```

In Guacamole, the default login and password is:

```bash
guacadmin
guacadmin
```

Create your own user then delete the user guacadmin

Create a connection using:

**EDIT CONNECTION**:

- **Name**: Debian GUI
- **Location**:ROOT
- **Protocol**: VNC

**PARAMETERS**:

Network:

- **Hostname**: `<your-EC2-IP>`
- **Port**: 5901

Authentification:

- **Username**: (empty)
- **Password**: `<The VNC password you set>`

**CLIPBOARD**

Encoding: UTF-8

📏 Recommended screen resolution: `1920x1080` or `1600x900`

### 9. Remove local graphical interface if you use local VM

- Delete "Display manager" local (GDM,LightDM,etc.)
- You have to keep XFCE4 because of VNC

Disable graphical environnement:

```bash
sudo systemctl disable lightdm
sudo systemctl set-default multi-user.target
```

Delete heavy and unused packages, be carreful don't delete XFCE4 and dbus-x11 otherwise VNC can't show the GUI

```bash
sudo apt purge gdm3 lightdm gnome-shell gnome-session* xorg* --auto-remove
```

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
