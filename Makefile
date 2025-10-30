# ================================
# 🧩 CONFIGURATION AUTOMATIQUE
# ================================

# Charger le fichier .env s’il existe
ifneq (,$(wildcard .env))
	include .env
	export $(shell sed 's/=.*//' .env)
endif

ENV_FILE = .env
# Détection automatique d’IP si non définie dans .env
HOST_IP ?= $(shell ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)

# Valeurs par défaut (si absentes du .env)
VM_IP ?= $(HOST_IP)
VNC_PORT ?= 5901
GUAC_PORT ?= 8081
SSH_PORT ?= 4242
VM_USER = radandri
VNC_PASS = radandri

# ================================
# ⚙️ COMMANDES PRINCIPALES
# ================================

help:
	@echo ""
	@echo "===== 🧭 Makefile Guacamole + VNC Manager ====="
	@echo "Available commands:"
	@echo "  make up           -> Démarre les conteneurs Guacamole"
	@echo "  make down         -> Stoppe et supprime les conteneurs"
	@echo "  make restart      -> Redémarre Guacamole proprement"
	@echo "  make status       -> Liste les conteneurs actifs"
	@echo "  make connect      -> Affiche l’URL Guacamole et info SSH"
	@echo "  make ssh          -> Se connecte à la VM en SSH"
	@echo "  make vnc          -> Teste la connexion VNC directe"
	@echo "  make env          -> Affiche les variables d’environnement chargées"
	@echo "================================================"
	@echo ""

# ================================
# 🚀 DOCKER / GUACAMOLE
# ================================

install:
	bash prepare.sh
	make up
	make setup-vnc

up:
	@echo "📦 Démarrage des conteneurs Guacamole..."
	docker compose up -d
	@echo ""
	@echo "🌐 Accès Guacamole : http://$(HOST_IP):$(GUAC_PORT)/guacamole"
	@echo "🧩 Utilisateur par défaut : guacadmin / guacadmin"
	@echo ""

down:
	@echo "🛑 Arrêt et suppression des conteneurs..."
	docker compose down

restart: down up

status:
	@echo "📋 Liste des conteneurs actifs :"
	docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"

# ================================
# 🔐 CONNEXION VM / VNC
# ================================

ssh:
	@echo "🔑 Connexion SSH à la VM $(VM_IP) sur le port $(SSH_PORT)..."
	@ssh radandri@$(VM_IP) -p $(SSH_PORT)

setup-vnc:
	@echo "🚀 Installation de VNC Server et XFCE dans la VM ..."
	sudo apt update -y
	sudo apt install -y tightvncserver xfce4 xfce4-goodies dbus-x11
	@echo "✅ Installation terminée."
	@echo "🔧 Configuration du fichier xstartup..."
	mkdir -p ~/.vnc
	echo '#!/bin/bash' > ~/.vnc/xstartup
	echo 'xrdb "$$HOME/.Xresources"' >> ~/.vnc/xstartup
	echo 'startxfce4 &' >> ~/.vnc/xstartup
	chmod +x ~/.vnc/xstartup
	@echo "✅ Fichier ~/.vnc/xstartup créé."
	@echo "💡 Lance le serveur avec : make start-vnc"
	echo "$(VNC_PASS)" | vncpasswd -f > ~/.vnc/passwd
	chmod 600 ~/.vnc/passwd

status-vnc:
	ss -tlnp | grep $(VNC_PORT)

restart-vnc:
	vncserver -kill :1 2>/dev/null 
	vncserver :1 -geometry 1920x1080 -depth 24

connect:
	@echo ""
	@echo "================== 🌍 INFORMATIONS =================="
	@echo "Guacamole :   http://$(HOST_IP):$(GUAC_PORT)/guacamole"
	@echo "VM SSH :      ssh radandri@$(VM_IP) -p $(SSH_PORT)"
	@echo "VNC :         $(VM_IP):$(VNC_PORT)"
	@echo "====================================================="
	@echo ""

# ================================
# 🧰 OUTILS / DEBUG
# ================================

env:
	@echo "===== 🌱 Variables d'environnement chargées ====="
	@echo "HOST_IP  = $(HOST_IP)"
	@echo "VM_IP    = $(VM_IP)"
	@echo "VNC_PORT = $(VNC_PORT)"
	@echo "GUAC_PORT= $(GUAC_PORT)"
	@echo "SSH_PORT = $(SSH_PORT)"
	@echo "==============================================="

update-env:
	@echo "🔄 Mise à jour du fichier $(ENV_FILE) avec HOST_IP=$(HOST_IP)"
	@if [ -f $(ENV_FILE) ]; then \
		sed -i "s/^HOST_IP=.*/HOST_IP=$(HOST_IP)/" $(ENV_FILE) || echo "HOST_IP=$(HOST_IP)" >> $(ENV_FILE); \
	else \
		echo "HOST_IP=$(HOST_IP)" > $(ENV_FILE); \
	fi

# Mets à jour .env puis lance tes conteneurs
run: update-env
	docker compose --env-file $(ENV_FILE) up -d

clean-docker:
	@echo "🧹 Suppression des conteneurs, volumes et images orphelins..."
	bash reset.sh
	docker compose down -v --remove-orphans
	docker system prune -f
	docker stop $(docker ps -aq) 2>/dev/null
	docker rm -f $(docker ps -aq) 2>/dev/null


optimize-vm:
	@echo "🚀 Nettoyage de la VM (désactivation interface graphique)..."
	sudo systemctl disable lightdm || true
	sudo systemctl set-default multi-user.target
	sudo apt purge -y gdm3 lightdm gnome-shell gnome-session* xorg* --auto-remove || true
	sudo apt autoremove -y
	sudo apt autoclean
	@echo "✅ Interface graphique désactivée et VM optimisée."

.PHONY: help install up down restart status ssh setup-vnc status-vnc restart-vnc connect env update-env run clean-docker optimize-vm
