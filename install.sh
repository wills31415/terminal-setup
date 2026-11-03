#!/usr/bin/env bash
# terminal-setup — installation (et mise à jour : --update) de la config terminal.
#
#   ./install.sh                       première installation (questions si besoin)
#   ./install.sh --name NOM            nom de la machine (macOS : nom fixe du Mac ;
#                                      ailleurs, ex. Termux : nom affiché dans le prompt)
#   ./install.sh --user NOM            utilisateur affiché dans le prompt (ex. Termux)
#   ./install.sh --update              sans question : ce que fait « terminal-setup update »
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/terminal-setup"
BACKUP_DIR="$DATA_DIR/backups"
BACKUP_KEEP=5
LOCAL_MARK="# ── 1. Identité dans le prompt"

UPDATE=0 NAME="" SHOWN_USER=""
while (( $# )); do
    case "$1" in
        --update) UPDATE=1 ;;
        --name)   NAME="${2:?--name NOM}"; shift ;;
        --user)   SHOWN_USER="${2:?--user NOM}"; shift ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "option inconnue : $1 (--help)" >&2; exit 1 ;;
    esac
    shift
done

# ── Couleurs de sortie ──
info()  { printf '\033[1;34m[info]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[1;32m[ok]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[1;33m[warn]\033[0m  %s\n' "$1"; }
err()   { printf '\033[1;31m[err]\033[0m   %s\n' "$1" >&2; }

# ── Détection de plateforme ──
detect_platform() {
    if [[ -n "${TERMUX_VERSION:-}" || "${PREFIX:-}" == */com.termux/* ]]; then
        echo "termux"; return
    fi
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if grep -qi raspberry /proc/device-tree/model 2>/dev/null; then
                echo "raspberry"
            elif grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl2"
            else
                echo "linux"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM="$(detect_platform)"

if [ -f /etc/homelab-terminal ] && (( UPDATE == 0 )); then
    warn "Ici, la config terminal est installée par le homelab (homelab apply) : rien à faire."
    exit 0
fi

# Demande confirmation à l'utilisateur (jamais en mode --update).
# Usage : ask "Question ?" && echo oui || echo non
ask() {
    (( UPDATE )) && return 1
    local answer
    read -rp "  → $1 [O/n] " answer
    [[ ! "$answer" =~ ^[nN] ]]
}

# Affiche un bloc de lignes de façon lisible (à l'écran : jamais dans un fichier produit).
show_block() {
    local label="$1" content="$2"
    {
        echo ""
        warn "$label"
        echo "  ┌────────────────────────────────────"
        while IFS= read -r line; do
            echo "  │ $line"
        done <<< "$content"
        echo "  └────────────────────────────────────"
    } >&2
}

# Sauvegarde un fichier dans ~/.local/share/terminal-setup/backups (on en garde 5 par fichier).
backup() {
    local f="$1" base
    [ -f "$f" ] || return 0
    base="$(basename "$f")"
    mkdir -p "$BACKUP_DIR"
    cp -p "$f" "$BACKUP_DIR/${base#.}.$(date +%Y%m%d-%H%M%S)"
    ls -1t "$BACKUP_DIR/${base#.}".* 2>/dev/null | tail -n +$((BACKUP_KEEP + 1)) | while read -r old; do rm -f "$old"; done
}

# Les anciennes sauvegardes (~/.bashrc.backup.*) rejoignent le dossier des sauvegardes.
tidy_old_backups() {
    local f n=0
    for f in ~/.bashrc.backup.* ~/.bash_profile.backup.*; do
        [ -f "$f" ] || continue
        mkdir -p "$BACKUP_DIR"
        mv "$f" "$BACKUP_DIR/$(basename "$f" | sed 's/^\.//; s/\.backup\./\./')"
        n=$((n + 1))
    done
    (( n )) && ok "$n ancienne(s) sauvegarde(s) rangée(s) dans $BACKUP_DIR"
    return 0
}

# ══════════════════════════════════════════════════════════════
#  Installation des dépendances
# ══════════════════════════════════════════════════════════════
install_deps() {
    case "$PLATFORM" in
        macos)
            if ! command -v brew &>/dev/null; then
                err "Homebrew requis. Installe-le d'abord : https://brew.sh"
                exit 1
            fi
            local deps=()
            command -v git &>/dev/null || deps+=(git)
            brew list bash-completion@2 &>/dev/null 2>&1 || deps+=(bash-completion@2)
            command -v fzf &>/dev/null || deps+=(fzf)
            if (( ${#deps[@]} > 0 )); then
                info "Installation via Homebrew : ${deps[*]}"
                brew install "${deps[@]}"
            else
                ok "Dépendances déjà installées"
            fi
            if ! brew list --cask font-meslo-lg-nerd-font &>/dev/null 2>&1; then
                info "Installation de MesloLGS Nerd Font..."
                brew install --cask font-meslo-lg-nerd-font
            fi
            ;;
        termux)
            local deps=()
            command -v git &>/dev/null || deps+=(git)
            [ -r "$PREFIX/share/bash-completion/bash_completion" ] || deps+=(bash-completion)
            command -v fzf &>/dev/null || deps+=(fzf)
            command -v curl &>/dev/null || deps+=(curl)
            if (( ${#deps[@]} > 0 )); then
                info "Installation via pkg : ${deps[*]}"
                pkg install -y "${deps[@]}"
            else
                ok "Dépendances déjà installées"
            fi
            ;;
        wsl2|linux|raspberry)
            local deps=()
            command -v git &>/dev/null || deps+=(git)
            dpkg -s bash-completion &>/dev/null 2>&1 || deps+=(bash-completion)
            command -v fzf &>/dev/null || deps+=(fzf)
            if (( ${#deps[@]} > 0 )); then
                info "Installation via apt : ${deps[*]}"
                sudo apt-get update -qq
                sudo apt-get install -y -qq "${deps[@]}"
            else
                ok "Dépendances déjà installées"
            fi
            install_nerd_font_linux
            ;;
        *)
            warn "Plateforme inconnue — installation des dépendances ignorée"
            ;;
    esac
}

NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
# Termux n'utilise qu'une police : on ne télécharge qu'elle (~2,5 Mo au lieu de l'archive).
NERD_FONT_TTF_URL="https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/S/MesloLGSNerdFontMono-Regular.ttf"

download() {  # download <url> <fichier>
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$2" "$1"
    elif command -v wget &>/dev/null; then
        wget -q -O "$2" "$1"
    else
        return 1
    fi
}

# ══════════════════════════════════════════════════════════════
#  Installation de la police Nerd Font (Linux)
# ══════════════════════════════════════════════════════════════
install_nerd_font_linux() {
    local font_dir="$HOME/.local/share/fonts/MesloLGS-NF"

    if fc-list 2>/dev/null | grep -qi "MesloLGS Nerd Font"; then
        ok "MesloLGS Nerd Font déjà installée"
        return 0
    fi

    local tmpzip
    tmpzip="$(mktemp /tmp/meslo-nf-XXXXXX.zip)"
    info "Téléchargement de MesloLGS Nerd Font..."
    if ! download "$NERD_FONT_URL" "$tmpzip"; then
        warn "Ni curl ni wget disponible — installation de la police ignorée"
        return 0
    fi
    mkdir -p "$font_dir"
    unzip -qo "$tmpzip" -d "$font_dir"
    rm -f "$tmpzip"
    command -v fc-cache &>/dev/null && fc-cache -f "$font_dir"
    ok "MesloLGS Nerd Font installée → $font_dir"
}

# ══════════════════════════════════════════════════════════════
#  Thème commun (palette One Dark) : iTerm2 (macOS) et Termux
# ══════════════════════════════════════════════════════════════
palette() {  # palette <nom> → #rrggbb
    sed -n "s/^$1=//p" "$REPO_DIR/theme/palette"
}

install_theme_termux() {
    local dir="$HOME/.termux" changed=0
    mkdir -p "$dir"
    # Police : MesloLGS Nerd Font (séparateurs Powerline, icônes).
    if [ ! -f "$dir/font.ttf" ] || [ ! -f "$DATA_DIR/termux-font" ]; then
        local tmp
        tmp="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/meslo.XXXXXX")"
        info "Téléchargement de MesloLGS Nerd Font..."
        if download "$NERD_FONT_TTF_URL" "$tmp/meslo.ttf" \
           && [ "$(head -c 4 "$tmp/meslo.ttf" | od -An -tx1 | tr -d ' ')" = "00010000" ]; then
            [ -f "$dir/font.ttf" ] && backup "$dir/font.ttf"
            cp "$tmp/meslo.ttf" "$dir/font.ttf"
            mkdir -p "$DATA_DIR" && touch "$DATA_DIR/termux-font"
            changed=1
            ok "Police MesloLGS Nerd Font Mono → ~/.termux/font.ttf"
        else
            warn "Police non téléchargée (réseau ?) : relance plus tard"
        fi
        rm -rf "$tmp"
    fi
    # Couleurs
    local new="$dir/colors.properties.new"
    {
        echo "# terminal-setup — palette commune (One Dark). Régénéré par install.sh."
        echo "background=$(palette background)"
        echo "foreground=$(palette foreground)"
        echo "cursor=$(palette cursor)"
        for i in $(seq 0 15); do echo "color$i=$(palette "color$i")"; done
    } > "$new"
    if ! cmp -s "$new" "$dir/colors.properties" 2>/dev/null; then
        backup "$dir/colors.properties"
        mv "$new" "$dir/colors.properties"
        changed=1
        ok "Couleurs → ~/.termux/colors.properties"
    else
        rm -f "$new"
    fi
    (( changed )) && command -v termux-reload-settings &>/dev/null && termux-reload-settings || true
}

install_theme_iterm2() {
    local dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    [ -d "/Applications/iTerm.app" ] || return 0
    mkdir -p "$dir"
    _color() {  # #rrggbb → dictionnaire de couleur iTerm2
        local h="${1#\#}"
        printf '{"Red Component": %s, "Green Component": %s, "Blue Component": %s, "Alpha Component": 1, "Color Space": "sRGB"}' \
            "$(LC_ALL=C awk "BEGIN{printf \"%.4f\", $((16#${h:0:2}))/255}")" \
            "$(LC_ALL=C awk "BEGIN{printf \"%.4f\", $((16#${h:2:2}))/255}")" \
            "$(LC_ALL=C awk "BEGIN{printf \"%.4f\", $((16#${h:4:2}))/255}")"
    }
    {
        echo '{"Profiles": [{'
        echo '  "Name": "terminal-setup",'
        echo '  "Guid": "terminal-setup-one-dark",'
        echo '  "Normal Font": "MesloLGSNF-Regular 13",'
        echo '  "Use Non-ASCII Font": false,'
        echo "  \"Background Color\": $(_color "$(palette background)"),"
        echo "  \"Foreground Color\": $(_color "$(palette foreground)"),"
        echo "  \"Bold Color\": $(_color "$(palette color15)"),"
        echo "  \"Cursor Color\": $(_color "$(palette cursor)"),"
        echo "  \"Cursor Text Color\": $(_color "$(palette background)"),"
        echo "  \"Selection Color\": $(_color "$(palette selection)"),"
        echo "  \"Selected Text Color\": $(_color "$(palette foreground)"),"
        for i in $(seq 0 15); do
            printf '  "Ansi %s Color": %s%s\n' "$i" "$(_color "$(palette "color$i")")" "$([ "$i" -lt 15 ] && echo ,)"
        done
        echo '}]}'
    } > "$dir/terminal-setup.json"
    ok "Profil iTerm2 « terminal-setup » (couleurs + police) prêt"
}

# ══════════════════════════════════════════════════════════════
#  ~/.bashrc.local : migration et rangement en sections
# ══════════════════════════════════════════════════════════════

# Blocs connus « outils de la machine » d'un fichier (conda, docker-apps, nvm, iTerm2…).
known_blocks() {
    local f="$1"
    [ -f "$f" ] || return 0
    sed -n '/^# >>> conda initialize >>>/,/^# <<< conda initialize <<</p' "$f"
    sed -n '/^# >>> nvm >>>/,/^# <<< nvm <<</p' "$f"
    grep -E '^[^#]*(NVM_DIR|nvm\.sh|PYENV_ROOT|pyenv init|rbenv init|SDKMAN|\.cargo/env|GOPATH|GOROOT|/usr/local/go/bin|docker-apps|CUSTOM_DOCKER_CLUSTER_BASE_PATH=|iterm2_shell_integration|ts_lazy_conda)' "$f" \
        | grep -vE '^\s*#' || true
}

# Le reste d'un fichier, sans ces blocs connus ni les fonctions fournies par bin/ du dépôt.
other_lines() {
    local f="$1" provided
    [ -f "$f" ] || return 0
    provided="$(ls "$REPO_DIR/bin" | paste -sd'|' -)"
    sed -e '/^# >>> conda initialize >>>/,/^# <<< conda initialize <<</d' \
        -e '/^# >>> nvm >>>/,/^# <<< nvm <<</d' "$f" \
    | grep -vE '^[^#]*(NVM_DIR|nvm\.sh|PYENV_ROOT|pyenv init|rbenv init|SDKMAN|\.cargo/env|GOPATH|GOROOT|/usr/local/go/bin|docker-apps|CUSTOM_DOCKER_CLUSTER_BASE_PATH=|iterm2_shell_integration|ts_lazy_conda)' \
    | awk -v re="^(${provided})[[:space:]]*\\\\(\\\\)" '
        # Une fonction fournie par bin/ disparaît, avec les commentaires qui la précèdent.
        skip { if ($0 ~ /^\}/) skip = 0; next }
        $0 ~ re { skip = 1; pending = ""; next }
        /^[[:space:]]*#/ { pending = pending $0 "\n"; next }
        { printf "%s", pending; pending = ""; print }
        END { printf "%s", pending }' || true
}

# Lignes d'un ~/.bash_profile de macOS qui ne sont ni brew, ni « charger ~/.bashrc ».
profile_extras() {
    other_lines "$1" | grep -vE 'brew shellenv|source ~/\.bashrc|\. ~/\.bashrc|source "\$HOME/\.bashrc"|\. "\$HOME/\.bashrc"|^\s*if \[ -f ~/\.bashrc \]|^\s*fi\s*$|Charge \.bashrc' || true
}

trim_blank() {  # retire les lignes vides au début/à la fin et les doublons de lignes vides
    awk 'NF { for (; blank > 0 && started; blank--) print ""; blank = 0; started = 1; print; next } { blank++ }'
}

# Écrit ~/.bashrc.local à partir du modèle : identité / outils / ajouts perso.
write_local() {
    local identity="$1" tools="$2" perso="$3" out
    out="$(mktemp)"
    while IFS= read -r line; do
        case "$line" in
            @IDENTITY@) [ -n "$identity" ] && printf '%s\n' "$identity"; echo ;;
            @TOOLS@)    [ -n "$tools" ] && printf '%s\n' "$tools"; echo ;;
            @PERSO@)    [ -n "$perso" ] && printf '%s\n' "$perso" ;;
            *)          printf '%s\n' "$line" ;;
        esac
    done < "$REPO_DIR/local.template" > "$out"
    if ! cmp -s "$out" ~/.bashrc.local 2>/dev/null; then
        backup ~/.bashrc.local
        mv "$out" ~/.bashrc.local
        ok "~/.bashrc.local rangé (identité / outils de la machine / ajouts perso)"
    else
        rm -f "$out"
    fi
}

# Contenu d'une section d'un ~/.bashrc.local déjà rangé (1, 2 ou 3).
local_section() {
    awk -v n="$1" '
        /^# ── [0-9]\. / { match($0, /[0-9]\./); cur = substr($0, RSTART, 1); next }
        cur == n && !(n == 1 && /^# (Vide|affiché|TS_NAME|\(")/) { print }' ~/.bashrc.local | trim_blank
}

set_identity_var() {  # set_identity_var <texte identité> <VAR> <valeur> → texte modifié
    local text="$1" var="$2" val="$3"
    text="$(printf '%s\n' "$text" | grep -vE "^\s*${var}=" || true)"
    printf '%s\n%s=%q\n' "$text" "$var" "$val" | trim_blank
}

# Première installation : détection interactive des ajouts d'un ~/.bashrc d'origine.
custom_from_old_bashrc() {
    local old=~/.bashrc result=""
    [ -f "$old" ] || return 0
    grep -q '_prompt_command' "$old" && return 0      # déjà le bashrc de terminal-setup

    local stripped
    stripped="$(other_lines "$old")"
    local -a std_patterns=(
        '^\s*$' '^\s*#'
        '^\s*(case|in|esac|then|fi|else|elif|done|do|while|for|if|\*\)|;;)'
        '^\s*(local|return|unset|eval)\s' '^\s*\}'
        '(HISTSIZE|HISTFILESIZE|HISTCONTROL)=' 'shopt -s (histappend|checkwinsize|globstar)'
        '(lesspipe|debian_chroot|color_prompt|force_color_prompt)' 'tput setaf' '^\s*PS1='
        'unset color_prompt' '(xterm|rxvt)' '(dircolors|LS_COLORS|LSCOLORS|CLICOLOR)'
        '^\s*alias (ls|ll|la|l|grep|fgrep|egrep|diff|dir|vdir)=' 'GCC_COLORS'
        '(bash_completion|bash_aliases)' 'shopt -oq posix' '(GREP_COLOR|GREP_OPTIONS)'
        '^\s*export (LESS=|LESS_TERMCAP|PATH=)' 'bashrc\.local' 'uname -s'
        '^\s*echo\s' '^\s*(true|false)\s*$'
    )
    local skip_re
    skip_re="$(printf '%s|' "${std_patterns[@]}")"
    skip_re="${skip_re%|}"

    local kind lines
    for kind in "source/." "export" "alias"; do
        case "$kind" in
            source/.) lines="$(echo "$stripped" | grep -E '^\s*(source |\. )' | grep -vE "$skip_re" || true)" ;;
            export)   lines="$(echo "$stripped" | grep -E '^\s*export [A-Z_]+=' | grep -vE "$skip_re" || true)" ;;
            alias)    lines="$(echo "$stripped" | grep -E '^\s*alias ' | grep -vE "$skip_re" || true)" ;;
        esac
        if [ -n "$lines" ]; then
            show_block "Ajouts personnels ($kind) trouvés dans ~/.bashrc :" "$lines"
            ask "Les garder dans ~/.bashrc.local ?" && result+="$lines"$'\n'
        fi
    done
    printf '%s' "$result"
}

arrange_local() {
    local identity="" tools="" perso=""
    if [ -f ~/.bashrc.local ] && grep -q "^$LOCAL_MARK" ~/.bashrc.local; then
        identity="$(local_section 1)"
        tools="$(local_section 2)"
        perso="$(local_section 3)"
    else
        # Ancien fichier (ou aucun) : on range ce qu'il contient, et ce que l'ancien ~/.bashrc
        # avait de connu (conda, docker-apps…), en retirant les outils fournis par bin/.
        tools="$( { known_blocks ~/.bashrc.local; grep -q _prompt_command ~/.bashrc 2>/dev/null || known_blocks ~/.bashrc; } | trim_blank)"
        perso="$( { other_lines ~/.bashrc.local; custom_from_old_bashrc; } | trim_blank)"
        if [ -f ~/.bashrc.local ] && grep -qE "^($(ls "$REPO_DIR/bin" | paste -sd'|' -))[[:space:]]*\(\)" ~/.bashrc.local; then
            ok "Fonctions désormais fournies par le dépôt (bin/) retirées de ~/.bashrc.local"
        fi
    fi
    # macOS : ~/.bash_profile ne garde que brew + « charger ~/.bashrc » ; le reste vient ici.
    if [ "$PLATFORM" = "macos" ] && [ -f ~/.bash_profile ] \
       && ! grep -q "géré par terminal-setup" ~/.bash_profile; then
        local p_tools p_extra
        p_tools="$(known_blocks ~/.bash_profile)"
        p_extra="$(profile_extras ~/.bash_profile | trim_blank)"
        if [ -n "$p_tools$p_extra" ]; then
            [ -n "$p_tools" ] && tools="$(printf '%s\n\n%s\n' "$tools" "$p_tools" | trim_blank)"
            [ -n "$p_extra" ] && perso="$(printf '%s\n\n%s\n' "$perso" "$p_extra" | trim_blank)"
            ok "Réglages de ~/.bash_profile déplacés dans ~/.bashrc.local (lus par tous les terminaux)"
        fi
        write_bash_profile
    elif [ "$PLATFORM" = "macos" ]; then
        write_bash_profile
    fi
    [ -n "$NAME" ] && [ "$PLATFORM" != "macos" ] && identity="$(set_identity_var "$identity" TS_NAME "$NAME")"
    [ -n "$SHOWN_USER" ] && identity="$(set_identity_var "$identity" TS_USER "$SHOWN_USER")"
    write_local "$identity" "$tools" "$perso"
}

write_bash_profile() {
    local new
    new="$(mktemp)"
    cat > "$new" << 'EOF'
# ~/.bash_profile — géré par terminal-setup : Homebrew, puis ~/.bashrc.
# Tes réglages vont dans ~/.bashrc.local (lu par tous les terminaux, connexion ou non).
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$_brew" ] && { eval "$("$_brew" shellenv bash)"; break; }
done
unset _brew

[ -f ~/.bashrc ] && source ~/.bashrc
EOF
    if ! cmp -s "$new" ~/.bash_profile 2>/dev/null; then
        backup ~/.bash_profile
        mv "$new" ~/.bash_profile
        ok "~/.bash_profile réduit à Homebrew + ~/.bashrc"
    else
        rm -f "$new"
    fi
}

# ══════════════════════════════════════════════════════════════
#  Nom de la machine
# ══════════════════════════════════════════════════════════════
set_mac_name() {
    [ "$PLATFORM" = "macos" ] || return 0
    local cur
    cur="$(scutil --get HostName 2>/dev/null || true)"
    if [ -z "$NAME" ]; then
        [ -n "$cur" ] && return 0
        (( UPDATE )) && return 0
        warn "Ce Mac n'a pas de nom fixe : il change selon le réseau (ex. $(hostname -s))."
        read -rp "  → Nom fixe (minuscules, chiffres, tirets ; vide = laisser) : " NAME
        [ -n "$NAME" ] || return 0
    fi
    [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { err "nom invalide : $NAME"; exit 1; }
    [ "$cur" = "$NAME" ] && { ok "Nom du Mac : $NAME"; return 0; }
    info "Nom fixe du Mac → $NAME (mot de passe de session demandé)"
    sudo scutil --set HostName "$NAME"
    sudo scutil --set LocalHostName "$NAME"
    sudo scutil --set ComputerName "$NAME"
    ok "Nom du Mac : $NAME (nouveaux terminaux)"
}

# ══════════════════════════════════════════════════════════════
#  Déploiement
# ══════════════════════════════════════════════════════════════
deploy_bashrc() {
    if [ -f ~/.bashrc ] && ! cmp -s "$REPO_DIR/bashrc" ~/.bashrc; then
        backup ~/.bashrc
    fi
    cp "$REPO_DIR/bashrc" ~/.bashrc
    ok ".bashrc installé"
}

deploy_bin() {
    mkdir -p ~/.local/bin "$DATA_DIR"
    local f n=0
    for f in "$REPO_DIR"/bin/*; do
        cp "$f" ~/.local/bin/ && chmod 755 ~/.local/bin/"$(basename "$f")" && n=$((n + 1))
    done
    printf '%s\n' "$REPO_DIR" > "$DATA_DIR/repo"
    ok "$n outil(s) dans ~/.local/bin : $(ls "$REPO_DIR/bin" | paste -sd' ' - | sed 's/ /, /g')"
}

# ══════════════════════════════════════════════════════════════
#  Post-installation
# ══════════════════════════════════════════════════════════════
post_install() {
    echo ""
    ok "$( (( UPDATE )) && echo "Mise à jour terminée" || echo "Installation terminée" ) !"
    echo ""
    case "$PLATFORM" in
        macos)
            info "iTerm2 : Settings → Profiles → « terminal-setup » → Other Actions… → Set as Default"
            info "Alt+C  : iTerm2 → Settings → Profiles → Keys → Key Mappings → ⌥C → Send Escape Sequence → c"
            ;;
        termux)
            info "Police et couleurs appliquées ; ferme et rouvre Termux si l'affichage n'a pas changé."
            ;;
        wsl2)
            info "Police : Windows Terminal → Paramètres → Profil → Apparence → MesloLGS NF"
            ;;
        linux)
            info "Police installée. Configure ton émulateur de terminal :"
            info "  GNOME Terminal → Préférences → Profil → Police → MesloLGS Nerd Font"
            info "  XFCE Terminal  → Préférences → Apparence → Police → MesloLGS Nerd Font"
            ;;
        raspberry)
            info "Pour le SSH, la police doit être sur le terminal client."
            ;;
    esac
    echo ""
    info "Recharge : source ~/.bashrc   ·   Plus tard : terminal-setup update"
}

# ══════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════
main() {
    if (( UPDATE == 0 )); then
        echo "┌──────────────────────────────────────┐"
        echo "│      Terminal Setup — Installation    │"
        echo "└──────────────────────────────────────┘"
        echo ""
    fi
    info "Plateforme : $PLATFORM"
    install_deps
    tidy_old_backups
    arrange_local
    deploy_bashrc
    deploy_bin
    case "$PLATFORM" in
        macos)  install_theme_iterm2; set_mac_name ;;
        termux) install_theme_termux ;;
    esac
    post_install
}

main
