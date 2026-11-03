# Terminal Setup

Prompt Powerline, fzf, couleurs et complétion avancée pour Bash — le même partout.
Fonctionne sur **macOS**, **Linux** (Ubuntu/Debian), **WSL2**, **Raspberry Pi** et **Android (Termux)**.

## Apercu

Le prompt affiche en temps réel :
- **✔ / ✘** — statut et durée de la dernière commande
- **icône user@machine** — couleur et icône propres à chaque machine (voir ci-dessous),
  ⚡ si connexion SSH, **⚠ fond rouge pour root**
- **chemin courant**
- **⎇ branche** — avec indicateurs ahead ↑, behind ↓, fichiers modifiés ●, stash ⚑
- **🐍 env** — environnement conda/python actif
- **🐳 N** — clusters Docker actifs (si configuré)
- **⚙ N** — jobs en arrière-plan

### Repère de machine

| Machine | Repère |
|---|---|
| `gw` (passerelle) | 🛡 bleu |
| `nas` (stockage) | 🗄 violet |
| `enclume` (PC fixe) | 🖥 cuivre |
| `macbook-pro` | 💻 argent |
| `galaxy-s22-ultra` (Termux) | 📱 framboise |
| autre | couleur par défaut, sans icône |

Sur une console sans police ni vraies couleurs (console série, écran Linux : `TERM=linux`,
`vt*`), le prompt passe en version simple : `[ok] wsl@nas ~` puis `$`.

---

## Installation

```bash
git clone git@github.com:wills31415/terminal-setup.git
cd terminal-setup
./install.sh                          # macOS : propose un nom fixe pour le Mac
./install.sh --name macbook-pro       # (ou directement)
```

**Termux (Android)** — installer `git` d'abord, puis :

```bash
pkg install -y git && git clone https://github.com/wills31415/terminal-setup.git ~/terminal-setup
~/terminal-setup/install.sh --name galaxy-s22-ultra --user wsl
```

`--name` / `--user` : nom et utilisateur **affichés** (Android ne laisse pas renommer l'appareil,
et l'utilisateur Termux s'appelle `u0_a…`). Ils vont dans la section « identité » de `~/.bashrc.local`.

**Mise à jour**, partout ensuite : `terminal-setup update` (git pull + réinstallation, sans
question ; `~/.bashrc.local` n'est jamais écrasé). Sur les machines administrées par le homelab
(gw, nas), c'est `homelab apply` qui installe et met à jour cette config.

Le script détecte automatiquement la plateforme et :
1. Installe les dépendances (`git`, `bash-completion`, `fzf`, Nerd Font)
2. Range `~/.bashrc.local` en trois sections (voir plus bas), en y migrant les personnalisations
   de l'ancien `~/.bashrc` et, sur macOS, de `~/.bash_profile` (conda, docker-apps, iTerm2, alias…)
3. Déploie le nouveau `~/.bashrc` et les outils perso de `bin/` dans `~/.local/bin`
4. macOS : réduit `~/.bash_profile` à Homebrew + `~/.bashrc`, crée le profil iTerm2, fixe le nom du Mac
5. Termux : police MesloLGS Nerd Font Mono et couleurs dans `~/.termux`
6. Range les sauvegardes dans `~/.local/share/terminal-setup/backups` (5 par fichier)

### Installation distante (SSH)

```bash
ssh mon-serveur 'git clone git@github.com:wills31415/terminal-setup.git ~/terminal-setup && ~/terminal-setup/install.sh'
```

---

## Thème de couleurs commun

La même palette (One Dark, assortie au prompt) dans tous les terminaux, définie une seule fois
dans `theme/palette` :

| Terminal | Mise en place |
|---|---|
| **iTerm2** (macOS) | profil « terminal-setup » créé par `install.sh` (couleurs + police) : Settings → Profiles → « terminal-setup » → Other Actions… → **Set as Default** |
| **Termux** | appliqué automatiquement (`~/.termux/colors.properties`) |

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
| **Termux** | Installée et appliquée automatiquement (`~/.termux/font.ttf`) |
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
| Connexion SSH | ⚡ à la fin du segment machine |
| `sudo -i` | Segment rouge ⚠ root@machine |
| `line -h`, `terminal-setup version` | Outils perso disponibles |

---

## Personnalisations locales — `~/.bashrc.local`

Non versionné, lu à la fin de `~/.bashrc` par **tous** les terminaux (connexion ou non).
`install.sh` le range toujours en trois sections, dans cet ordre :

```bash
# ── 1. Identité dans le prompt ──
TS_NAME=galaxy-s22-ultra      # nom affiché (vide = vrai nom de la machine)
TS_USER=wsl                   # utilisateur affiché
# TS_ICON=🚀  TS_COLOR="r;g;b" # icône / couleur du segment machine

# ── 2. Outils de cette machine (conda, docker-apps, iTerm2…) ──
# >>> conda initialize >>> … <<< conda initialize <<<
source ~/docker-apps/.bash_utils

# ── 3. Ajouts perso ──
alias mqtt-explorer='…'
```

## Outils perso — `bin/`

Les petits programmes perso vivent dans `bin/` et sont installés dans `~/.local/bin` sur
chaque machine : plus besoin de les recopier à la main.

| Outil | Rôle |
|---|---|
| `line` | extrait un bloc de lignes d'un fichier ou d'un flux (`line -h`) |
| `terminal-setup` | `update` (dernière version du dépôt) · `version` |

Une fonction de `~/.bashrc.local` qui porte le nom d'un outil de `bin/` en est retirée à
l'installation (l'outil la remplace).

---

## Structure du dépôt

```
bashrc          → ~/.bashrc (universel, détecte l'OS)
bin/            → ~/.local/bin (outils perso : line, terminal-setup)
local.template  → modèle de ~/.bashrc.local (3 sections)
theme/palette   → palette commune (iTerm2, Termux)
install.sh      → installation et mise à jour (--update, --name, --user)
README.md       → ce fichier
```
