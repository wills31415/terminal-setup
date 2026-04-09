# Terminal personnalisé — Installation WSL2

Prompt Powerline, fzf, couleurs et complétion avancée pour Bash sous WSL2.

## Aperçu

Le prompt affiche en temps réel :
- **✔ / ✘** — statut et durée de la dernière commande
- **user@host** — avec indicateur ⚡ si connexion SSH
- **chemin courant**
- **⎇ branche** — avec indicateurs ahead ↑, behind ↓, fichiers modifiés ●, stash ⚑
- **🐍 env** — environnement conda/python actif
- **🐳 N** — clusters Docker actifs (si configuré)
- **⚙ N** — jobs en arrière-plan

---

## Prérequis

### 1. Police Nerd Font (sur Windows, pas dans WSL2)

Les séparateurs Powerline et icônes nécessitent une police spéciale installée côté Windows.

1. Télécharger **MesloLGS NF** : https://github.com/ryanoasis/nerd-fonts/releases/latest
   → choisir `Meslo.zip` dans les assets
2. Décompresser → sélectionner tous les `.ttf` → clic droit → **Installer pour tous les utilisateurs**
3. Ouvrir **Windows Terminal** → ⚙ Paramètres → Profils → *Ubuntu* (ou ton profil WSL2)
   → Apparence → Police de caractères → `MesloLGS NF`

> Sans cette étape, les séparateurs s'affichent comme des carrés □.

---

## Installation

### 2. Dépendances dans WSL2

```bash
sudo apt update && sudo apt install -y git bash-completion fzf
```

> **fzf alternatif** (version plus récente via git) :
> ```bash
> git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
> ~/.fzf/install --key-bindings --completion --no-update-rc
> ```

### 3. Installer le bashrc

```bash
# Sauvegarder l'ancien .bashrc
cp ~/.bashrc ~/.bashrc.backup

# Copier le nouveau
cp bashrc ~/.bashrc

# Recharger
source ~/.bashrc
```

---

## Vérification

| Test | Résultat attendu |
|---|---|
| Ouvrir un nouveau terminal | Prompt Powerline avec séparateurs ▶ (pas de □) |
| `Ctrl+R` | Recherche floue dans l'historique (fzf) |
| `Ctrl+T` | Navigation floue dans les fichiers (fzf) |
| `ls` | Fichiers en couleur |
| Se placer dans un dépôt git | Segment `⎇ main` visible dans le prompt |
| Lancer une commande longue | Durée affichée dans le segment statut |

---

## Fonctionnalités optionnelles

### Conda / Python (segment 🐍)

Installer [Miniconda](https://docs.conda.io/en/latest/miniconda.html) pour WSL2 (Linux x86_64).  
Le segment apparaît automatiquement dès qu'un environnement est activé (`conda activate mon-env`).

### Clusters Docker (segment 🐳)

Ce segment utilise un outil custom (`da`) pour gérer des clusters Docker Compose.  
Définir la variable `CUSTOM_DOCKER_CLUSTER_BASE_PATH` dans `~/.bashrc` pour l'activer.

---

## Structure du dépôt

```
bashrc      → à placer en ~/.bashrc dans WSL2
README.md   → ce fichier
```
