# Terminal Setup

Prompt Powerline, fzf, couleurs et complétion avancée pour Bash.
Fonctionne sur **macOS**, **Linux** (Ubuntu/Debian), **WSL2** et **Raspberry Pi**.

## Apercu

Le prompt affiche en temps réel :
- **✔ / ✘** — statut et durée de la dernière commande
- **user@host** — avec indicateur ⚡ si connexion SSH
- **chemin courant**
- **⎇ branche** — avec indicateurs ahead ↑, behind ↓, fichiers modifiés ●, stash ⚑
- **🐍 env** — environnement conda/python actif
- **🐳 N** — clusters Docker actifs (si configuré)
- **⚙ N** — jobs en arrière-plan

---

## Installation

```bash
git clone git@github.com:wills31415/terminal-setup.git
cd terminal-setup
./install.sh
```

Le script détecte automatiquement la plateforme et :
1. Installe les dépendances (`git`, `bash-completion`, `fzf`, Nerd Font)
2. Sauvegarde l'ancien `~/.bashrc`
3. Migre les personnalisations locales (conda, docker-apps…) vers `~/.bashrc.local`
4. Déploie le nouveau `~/.bashrc`
5. Configure `~/.bash_profile` si nécessaire (macOS)

### Installation distante (SSH)

```bash
ssh mon-serveur 'git clone git@github.com:wills31415/terminal-setup.git ~/terminal-setup && ~/terminal-setup/install.sh'
```

---

## Police Nerd Font

Les séparateurs Powerline (▶) nécessitent une police Nerd Font.
Sur Linux et macOS, `install.sh` l'installe automatiquement.
Il reste à la **sélectionner dans le terminal** :

| Plateforme | Configuration |
|---|---|
| **macOS** (iTerm2) | iTerm2 → Settings → Profiles → Text → Font → **MesloLGS Nerd Font** |
| **macOS** (Terminal.app) | Terminal → Préférences → Profil → Police → **MesloLGS Nerd Font** |
| **Linux** (GNOME Terminal) | Préférences → Profil → Police → **MesloLGS Nerd Font** |
| **Linux** (XFCE Terminal) | Préférences → Apparence → Police → **MesloLGS Nerd Font** |
| **Windows Terminal** | Télécharger [MesloLGS NF](https://github.com/ryanoasis/nerd-fonts/releases/latest) → installer → Paramètres → Profil → Apparence → Police → **MesloLGS NF** |
| **SSH** | La police doit être configurée sur le **terminal client**, pas sur le serveur distant |

> Sans police Nerd Font, les séparateurs s'affichent comme des carrés □.

---

## Raccourcis fzf

| Raccourci | Fonction |
|---|---|
| `Ctrl+R` | Recherche floue dans l'historique |
| `Ctrl+T` | Navigation floue dans les fichiers |
| `Alt+C` | Navigation floue dans les répertoires (`cd`) |

### Alt+C sur macOS (iTerm2)

Par défaut, `Option+C` envoie `ç` au lieu du signal attendu par fzf.
Pour activer le raccourci **sans casser les accents** (é, è, ç…) :

1. iTerm2 → Settings → Profiles → Keys → **Key Mappings**
2. Cliquer **+** (ajouter)
3. Keyboard Shortcut : appuyer sur **⌥C**
4. Action : **Send Escape Sequence**
5. Valeur : **c**

> Seul `⌥C` est remappé — les autres combinaisons Option continuent de produire les caractères accentués.

---

## Vérification

| Test | Résultat attendu |
|---|---|
| Ouvrir un nouveau terminal | Prompt Powerline avec séparateurs ▶ (pas de □) |
| `Ctrl+R` | Recherche floue dans l'historique (fzf) |
| `Ctrl+T` | Navigation floue dans les fichiers (fzf) |
| `Alt+C` | Navigation floue dans les répertoires (fzf) |
| `ls` | Fichiers en couleur |
| Se placer dans un dépôt git | Segment `⎇ main` visible dans le prompt |
| Lancer une commande longue | Durée affichée dans le segment statut |
| Connexion SSH | Segment ambre ⚡ user@host |

---

## Personnalisations locales

Le fichier `~/.bashrc.local` (non versionné) est sourcé à la fin du bashrc.
C'est l'endroit pour les ajouts propres à une machine :

```bash
# Conda
# >>> conda initialize >>>
# ...
# <<< conda initialize <<<

# Docker apps
source ~/docker-apps/.bash_utils

# Variables d'environnement locales
export CUSTOM_DOCKER_CLUSTER_BASE_PATH=~/docker-apps
```

L'install.sh migre automatiquement ces blocs depuis un bashrc existant.

---

## Structure du dépôt

```
bashrc       → ~/.bashrc (universel, détecte l'OS)
install.sh   → script d'installation automatique
README.md    → ce fichier
```
