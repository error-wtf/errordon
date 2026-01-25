# Errordon Tutorials & Troubleshooting

## Inhaltsverzeichnis

1. [Schnellstart](#1-schnellstart)
2. [Häufige Fehler](#2-häufige-fehler)
3. [Docker Build](#3-docker-build)
4. [Datenbank](#4-datenbank)
5. [Nginx & SSL](#5-nginx--ssl)
6. [Admin Account](#6-admin-account)
7. [Matrix Terminal](#7-matrix-terminal)
8. [Ollama AI](#8-ollama-ai)

---

## 1. Schnellstart

### Automatische Installation

```bash
curl -sSL "https://raw.githubusercontent.com/error-wtf/errordon/master/deploy/interactive-install.sh" -o install.sh
chmod +x install.sh
./install.sh
```

### Voraussetzungen

| Komponente | Minimum | Empfohlen |
|------------|---------|-----------|
| CPU | 4 Kerne | 8+ Kerne |
| RAM | 8 GB | 16 GB |
| Storage | 50 GB SSD | 100 GB SSD |
| OS | Ubuntu 22.04, Debian 12, Kali | Ubuntu 22.04 |

---

## 2. Häufige Fehler

### Fehler: "sidekiq-cron not in lockfile"

**Ursache:** Docker Build Cache hat alte Dateien gecached.

**Lösung:**
```bash
docker builder prune -af
cd ~/errordon
git fetch origin && git reset --hard origin/master
cd deploy
docker compose build
```

### Fehler: "role mastodon does not exist"

**Ursache:** Datenbank wurde mit falschen Credentials erstellt.

**Lösung:**
```bash
cd ~/errordon/deploy
docker compose down -v
docker compose up -d db redis
sleep 15
docker compose run --rm web bundle exec rails db:setup
docker compose up -d
```

### Fehler: "CACHED" Layers beim Build

**Ursache:** BuildKit cached alte Dateien.

**Lösung:**
```bash
docker builder prune -af
docker compose build
```

### Fehler: Blank Page / 404 auf Assets

**Ursache:** Nginx proxied nicht korrekt.

**Lösung:**
```bash
cd ~/errordon/deploy
sudo cp nginx.conf /etc/nginx/sites-available/errordon
sudo sed -i "s/example.com/DEINE-DOMAIN/g" /etc/nginx/sites-available/errordon
sudo nginx -t && sudo systemctl reload nginx
```

### Fehler: SSL Zertifikat fehlt

**Lösung:**
```bash
sudo certbot --nginx -d DEINE-DOMAIN.de
```

---

## 3. Docker Build

### Build starten
```bash
cd ~/errordon/deploy
docker compose build
```
**Dauer:** 15-25 Minuten

### Build mit Debug-Output
```bash
docker compose build --progress=plain 2>&1 | tee build.log
```

### Cache komplett löschen
```bash
docker builder prune -af
docker system prune -af
```

---

## 4. Datenbank

### Initialisieren
```bash
docker compose up -d db redis
sleep 15
docker compose run --rm web bundle exec rails db:setup
```

### Zurücksetzen (LÖSCHT ALLE DATEN!)
```bash
docker compose down -v
docker compose up -d db redis
sleep 15
docker compose run --rm web bundle exec rails db:setup
```

### Migrationen (nach Updates)
```bash
docker compose run --rm web bundle exec rails db:migrate
```

---

## 5. Nginx & SSL

### Config kopieren
```bash
sudo cp nginx.conf /etc/nginx/sites-available/errordon
sudo sed -i "s/example.com/DEINE-DOMAIN/g" /etc/nginx/sites-available/errordon
sudo ln -sf /etc/nginx/sites-available/errordon /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
```

### SSL holen
```bash
sudo certbot --nginx -d DEINE-DOMAIN.de
```

### Testen & Neuladen
```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 6. Admin Account

### Erstellen
```bash
docker compose exec web tootctl accounts create BENUTZERNAME \
  --email=EMAIL@DOMAIN.de --confirmed --role=Owner
```

### Bestätigen
```bash
docker compose exec web tootctl accounts modify BENUTZERNAME --confirm
```

### Passwort zurücksetzen
```bash
docker compose exec web tootctl accounts modify BENUTZERNAME --reset-password
```

---

## 7. Matrix Terminal

### Aktivieren
```bash
docker compose exec web bundle exec rails runner "Setting.landing_page = 'matrix'"
```

### Befehle
| Befehl | Aktion |
|--------|--------|
| `enter matrix` | Login |
| `register` | Registrierung |
| `tetris` | Spiel |
| `help` | Hilfe |

---

## 8. Ollama AI

### Installieren
```bash
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl enable ollama
sudo systemctl start ollama
```

### Modelle laden
```bash
ollama pull llava:7b    # Bilder (4GB)
ollama pull llama3:8b   # Text (5GB)
```

### In .env.production
```bash
ERRORDON_NSFW_PROTECT_ENABLED=true
ERRORDON_NSFW_OLLAMA_ENDPOINT=http://host.docker.internal:11434
```

---

## 9. Migration-Fehler beheben

### strong_migrations Fehler
```bash
# Falls Migration mit "Dangerous operation detected" fehlschlägt:
cd ~/errordon/deploy
docker compose run --rm -e SAFETY_ASSURED=1 web bundle exec rails db:migrate
```

### Datenbank existiert bereits
```bash
# Falls "database already exists" Fehler:
docker compose run --rm -e SAFETY_ASSURED=1 web bundle exec rails db:migrate
```

### Datenbank komplett neu aufsetzen (ACHTUNG: löscht alle Daten!)
```bash
docker compose down -v
docker compose run --rm -e SAFETY_ASSURED=1 web bundle exec rails db:setup
docker compose up -d
```

---

## Support

- **GitHub Issues:** https://github.com/error-wtf/errordon/issues
- **README:** [README_VPS.md](README_VPS.md)
