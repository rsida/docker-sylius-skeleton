# docker-sylius-skeleton

Squelette Docker pour bootstrapper un nouveau projet Sylius. Repose sur [docker-base](../docker-base) pour la gestion du reverse proxy Traefik et des certificats TLS locaux.

---

## Prérequis

| Outil | Version minimale |
|-------|-----------------|
| Docker + Docker Compose v2 | Docker 24+ |
| GNU Make | 4+ |
| docker-base | en cours d'exécution |

### docker-base

Ce projet **ne gère pas Traefik ni les certificats TLS**. Ces responsabilités appartiennent à `docker-base`, qui doit être démarré avant tout.

```bash
# Dans le répertoire docker-base
make up
```

`docker-base` crée le réseau externe `traefik-net`. Si ce réseau est absent, les conteneurs refuseront de démarrer avec l'erreur :
```
network traefik-net declared as external, but could not be found
```

---

## Scénario 1 — Créer un nouveau projet Sylius

À utiliser **une seule fois**, sur un skeleton vierge, pour bootstrapper un nouveau projet.

### 1. Cloner le skeleton

```bash
git clone <url-de-ce-repo> mon-projet
cd mon-projet
```

### 2. Configurer l'environnement

```bash
cp .env.example .env
```

Éditer `.env` et ajuster au minimum :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `APP_NAME` | Nom unique du projet (containers, réseau, routeur Traefik) | `mon-boutique` |
| `APP_DOMAIN` | Domaine local | `mon-boutique.local` |
| `DB_ROOT_PASSWORD` | Mot de passe root MariaDB | `secret-root` |
| `DB_PASSWORD` | Mot de passe utilisateur MariaDB | `secret-user` |
| `APP_SECRET` | Clé secrète Symfony (chaîne aléatoire 32 car.) | `a1b2c3...` |

> **Important** : `APP_NAME` doit être **unique** sur votre machine parmi tous les projets utilisant docker-base. Il est utilisé comme préfixe pour les noms de containers et les routeurs Traefik.

### 3. Ajouter le domaine dans /etc/hosts

```bash
echo "127.0.0.1 mon-boutique.local mail.mon-boutique.local" | sudo tee -a /etc/hosts
```

Remplacer `mon-boutique.local` par la valeur de `APP_DOMAIN` dans votre `.env`.

### 4. Lancer l'installation

```bash
make install
```

Cette commande effectue dans l'ordre :
1. Crée `.env` depuis `.env.example` si absent
2. Construit les images Docker
3. Démarre les containers
4. Attend que MariaDB soit prêt
5. Installe Sylius via `composer create-project` dans un répertoire temporaire, puis copie les fichiers
6. Exécute `sylius:install` (migrations, fixtures, compilation des assets)
7. Réchauffe le cache

L'installation prend **5 à 15 minutes** lors du premier lancement (téléchargement des dépendances Composer et Node).

Une fois terminé :
```
Sylius is ready!
  App:    https://mon-boutique.local
  Admin:  https://mon-boutique.local/admin
  Mail:   https://mail.mon-boutique.local
```

Identifiants admin par défaut générés par les fixtures Sylius :
- Login : `sylius@example.com`
- Mot de passe : `sylius`

### 5. Versionner l'application Sylius

Après `make install`, les fichiers Sylius sont présents dans le répertoire. Commitez-les pour que les autres développeurs puissent travailler sur le projet sans refaire `create-project` :

```bash
git add composer.json composer.lock config/ src/ templates/ translations/ migrations/ public/ assets/
git commit -m "chore: initial Sylius installation"
git push
```

---

## Scénario 2 — Rejoindre un projet existant

À utiliser quand `make install` a déjà été exécuté et que `composer.json` est présent dans le dépôt.

### 1. Cloner le projet

```bash
git clone <url-du-projet> mon-projet
cd mon-projet
```

### 2. Configurer l'environnement

```bash
cp .env.example .env
# Renseigner les credentials fournis par l'équipe (DB_PASSWORD, APP_SECRET, etc.)
```

### 3. Ajouter le domaine dans /etc/hosts

```bash
echo "127.0.0.1 mon-boutique.local mail.mon-boutique.local" | sudo tee -a /etc/hosts
```

### 4. Lancer le setup

```bash
make setup
```

`make setup` installe les dépendances Composer, exécute les migrations et installe les assets **sans** refaire `composer create-project`.

---

## Usage quotidien

```bash
make up                          # Démarrer les containers
make down                        # Arrêter les containers
make shell                       # Shell bash dans le container PHP
make console CMD="cache:clear"   # Commande Symfony
make cc                          # Vider le cache
make logs                        # Logs de tous les services
make logs SERVICES="php nginx"   # Logs d'un service spécifique
make ps                          # État des containers
make help                        # Liste complète des commandes
```

---

## Xdebug

Xdebug est installé et configuré pour PHPStorm. Il fonctionne en **trigger mode** : il ne s'active qu'à la demande et n'impacte pas les performances lors d'une navigation normale.

**Pour activer le débogage :**

1. Installez l'extension navigateur [Xdebug Helper](https://chromewebstore.google.com/detail/xdebug-helper/eadndfjplgieldjbigjakmdgkmoaaaoc)
2. Activez le mode "Debug" dans l'extension (icône verte)
3. Dans PHPStorm, démarrez "Listen for PHP Debug Connections" (icône téléphone)
4. Posez un point d'arrêt et rechargez la page

Paramètres Xdebug :
- Port : `9003`
- IDE Key : `PHPSTORM`

---

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Application | `https://<APP_DOMAIN>` | Sylius frontend |
| Admin | `https://<APP_DOMAIN>/admin` | Back-office Sylius |
| Mailpit | `https://mail.<APP_DOMAIN>` | Capture des emails (dev) |
| MariaDB | `mariadb:3306` (interne uniquement) | Base de données |

Les ports ne sont **pas** exposés sur l'hôte — tout le trafic passe par Traefik (géré par docker-base).

---

## Variables d'environnement

Toutes les variables sont définies dans `.env` (copié depuis `.env.example`).

| Variable | Défaut | Description |
|----------|--------|-------------|
| `APP_NAME` | `sylius` | Préfixe unique pour containers et routeurs Traefik |
| `APP_DOMAIN` | `sylius.local` | Domaine local de l'application |
| `APP_ENV` | `dev` | Environnement Symfony |
| `APP_SECRET` | `change-me-in-production` | Clé secrète Symfony |
| `TRAEFIK_NETWORK` | `traefik-net` | Réseau externe Traefik (doit correspondre à docker-base) |
| `DB_ROOT_PASSWORD` | `root` | Mot de passe root MariaDB |
| `DB_NAME` | `sylius` | Nom de la base de données |
| `DB_USER` | `sylius` | Utilisateur MariaDB |
| `DB_PASSWORD` | `sylius` | Mot de passe utilisateur MariaDB |

---

## Structure du projet

```
docker-sylius-skeleton/
├── docker/
│   ├── nginx/
│   │   └── default.conf     # Configuration Nginx (PHP-FPM + propagation HTTPS Traefik)
│   └── php/
│       ├── Dockerfile        # PHP 8.3-FPM + extensions Sylius + Composer 2 + Node.js 20
│       ├── php.ini           # Paramètres PHP (mémoire 512M, upload 64M)
│       └── xdebug.ini        # Configuration Xdebug 3 (trigger mode, port 9003)
├── .env.example              # Template de configuration — copier en .env
├── .gitignore
├── compose.yaml              # Services : nginx, php, mariadb, mailpit
├── Makefile                  # Commandes de développement
└── README.md
```
