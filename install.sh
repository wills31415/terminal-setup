#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Couleurs de sortie ──
info()  { printf '\033[1;34m[info]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[1;32m[ok]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[1;33m[warn]\033[0m  %s\n' "$1"; }
err()   { printf '\033[1;31m[err]\033[0m   %s\n' "$1" >&2; }

# ── Détection de plateforme ──
detect_platform() {
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
            ;;
        *)
            warn "Plateforme inconnue — installation des dépendances ignorée"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════
#  Migration du bashrc existant
# ══════════════════════════════════════════════════════════════

# Demande confirmation à l'utilisateur.
# Usage : ask "Question ?" && echo oui || echo non
ask() {
    local answer
    read -rp "  → $1 [O/n] " answer
    [[ ! "$answer" =~ ^[nN] ]]
}

# Affiche un bloc de lignes de façon lisible.
show_block() {
    local label="$1" content="$2"
    echo ""
    warn "$label"
    echo "  ┌────────────────────────────────────"
    while IFS= read -r line; do
        echo "  │ $line"
    done <<< "$content"
    echo "  └────────────────────────────────────"
}

migrate_existing_bashrc() {
    [ -f ~/.bashrc ] || return 0
    if [ -f ~/.bashrc.local ]; then
        ok "~/.bashrc.local existe déjà — migration ignorée"
        return 0
    fi

    local old=~/.bashrc
    local result=""

    # ── Phase 1 : Blocs délimités connus (migration automatique) ──

    # Conda
    if grep -q '>>> conda initialize >>>' "$old"; then
        result+="$(sed -n '/^# >>> conda initialize >>>/,/^# <<< conda initialize <<</p' "$old")"$'\n\n'
        ok "Bloc conda détecté → migration automatique"
    fi

    # NVM
    if grep -q '>>> nvm >>>\|NVM_DIR' "$old"; then
        if grep -q '>>> nvm >>>' "$old"; then
            result+="$(sed -n '/^# >>> nvm >>>/,/^# <<< nvm <<</p' "$old")"$'\n\n'
        else
            result+="$(grep -B1 -A3 'NVM_DIR' "$old" | grep -v '^--$')"$'\n\n'
        fi
        ok "Config nvm détectée → migration automatique"
    fi

    # pyenv
    if grep -q 'PYENV_ROOT\|pyenv init' "$old"; then
        result+="$(grep -E '(PYENV_ROOT|pyenv)' "$old")"$'\n\n'
        ok "Config pyenv détectée → migration automatique"
    fi

    # rbenv
    if grep -q 'rbenv init' "$old"; then
        result+="$(grep 'rbenv' "$old")"$'\n\n'
        ok "Config rbenv détectée → migration automatique"
    fi

    # SDKMAN
    if grep -q 'SDKMAN_DIR' "$old"; then
        result+="$(grep -B1 -A3 'SDKMAN' "$old" | grep -v '^--$')"$'\n\n'
        ok "Config SDKMAN détectée → migration automatique"
    fi

    # Cargo / Rust
    if grep -q '\.cargo/env' "$old"; then
        result+="$(grep '\.cargo/env' "$old")"$'\n\n'
        ok "Config Cargo/Rust détectée → migration automatique"
    fi

    # Go
    if grep -qE 'GOPATH|GOROOT|/usr/local/go/bin' "$old"; then
        result+="$(grep -E '(GOPATH|GOROOT|/usr/local/go/bin)' "$old")"$'\n\n'
        ok "Config Go détectée → migration automatique"
    fi

    # docker-apps
    local docker_lines
    docker_lines="$(grep -E '(source.*docker-apps|\. .*docker-apps|CUSTOM_DOCKER_CLUSTER_BASE_PATH=)' "$old" | grep -v '^\s*#' || true)"
    if [ -n "$docker_lines" ]; then
        result+="$docker_lines"$'\n\n'
        ok "Config docker-apps détectée → migration automatique"
    fi

    # ── Phase 2 : Nettoyage pour détection des ajouts inconnus ──
    # On retire les blocs déjà extraits pour éviter les faux positifs
    local stripped
    stripped="$(sed \
        -e '/^# >>> conda initialize >>>/,/^# <<< conda initialize <<</d' \
        -e '/^# >>> nvm >>>/,/^# <<< nvm <<</d' \
        -e '/docker-apps/d' \
        -e '/CUSTOM_DOCKER_CLUSTER_BASE_PATH/d' \
        -e '/NVM_DIR/d' -e '/nvm\.sh/d' \
        -e '/PYENV_ROOT/d' -e '/pyenv init/d' \
        -e '/rbenv init/d' \
        -e '/SDKMAN/d' \
        -e '/\.cargo\/env/d' \
        -e '/GOPATH\|GOROOT\|\/usr\/local\/go\/bin/d' \
        "$old")"

    # Patterns standard (notre bashrc + défaut Debian) — une ligne = un pattern grep -E
    local -a std_patterns=(
        '^\s*$'
        '^\s*#'
        '^\s*(case|in|esac|then|fi|else|elif|done|do|while|for|if|\*\)|;;)'
        '^\s*(local|return|unset|eval)\s'
        '^\s*\}'
        '(HISTSIZE|HISTFILESIZE|HISTCONTROL)='
        'shopt -s (histappend|checkwinsize|globstar)'
        '(lesspipe|debian_chroot|color_prompt|force_color_prompt)'
        'tput setaf'
        '^\s*PS1='
        'unset color_prompt'
        '(xterm|rxvt)'
        '(dircolors|LS_COLORS|LSCOLORS|CLICOLOR)'
        '^\s*alias (ls|ll|la|l|grep|fgrep|egrep|diff|dir|vdir)='
        'GCC_COLORS'
        '(bash_completion|bash_aliases)'
        'shopt -oq posix'
        '(GREP_COLOR|GREP_OPTIONS)'
        '^\s*export (LESS=|LESS_TERMCAP|PATH=)'
        '(CONDA_CHANGEPS1|CONDA_DEFAULT_ENV)'
        '(FZF_DEFAULT_OPTS|FZF_CTRL_R|FZF_CTRL_T|FZF_ALT_C)'
        '(--height=|--layout=|--border=|--prompt=|--pointer=|--marker=)'
        '(_PL_SEP|_PL_BG|_PL_FG)'
        '(_timer_start|_prompt_command|_prompt_ready|_cmd_start|_cmd_ran)'
        '^\s*PROMPT_COMMAND='
        'EPOCHREALTIME'
        '^\s*trap.*DEBUG'
        'bind .*set (completion|show-all|colored|mark-sym)'
        '(fzf --bash|\.fzf\.bash|fzf.*key-bindings|completions/fzf)'
        'bashrc\.local'
        '(update_terminal_cwd|__iterm2_|__bp_)'
        '(seg_status|seg_host|seg_git|seg_py|seg_dock|seg_job)'
        '(SSH_TTY|SSH_CLIENT|SSH_CONNECTION)'
        '(git status --porcelain|git stash list)'
        '(branch\.head|branch\.ab)'
        'BASH_REMATCH'
        '(_pl\(\)|_prev_bg)'
        'jobs -p'
        'uname -s'
        'docker.*bash-completion'
        'HOMEBREW_PREFIX'
        '\\\\u@\\\\h'
        '^\s*echo\s'
        '^\s*(true|false)\s*$'
    )

    # Construire un seul pattern grep -E
    local skip_re
    skip_re="$(printf '%s|' "${std_patterns[@]}")"
    skip_re="${skip_re%|}"   # retirer le | final

    # ── Phase 3 : Détection interactive des ajouts inconnus ──

    # Source/. personnalisés
    local custom_sources
    custom_sources="$(echo "$stripped" | grep -E '^\s*(source |\. )' | grep -vE "$skip_re" || true)"
    if [ -n "$custom_sources" ]; then
        show_block "Commandes source/. personnalisées :" "$custom_sources"
        if ask "Migrer vers ~/.bashrc.local ?"; then
            result+="# Source personnalisés"$'\n'"$custom_sources"$'\n\n'
        fi
    fi

    # Exports personnalisés
    local custom_exports
    custom_exports="$(echo "$stripped" | grep -E '^\s*export [A-Z_]+=' | grep -vE "$skip_re" || true)"
    if [ -n "$custom_exports" ]; then
        show_block "Exports personnalisés :" "$custom_exports"
        if ask "Migrer vers ~/.bashrc.local ?"; then
            result+="# Exports personnalisés"$'\n'"$custom_exports"$'\n\n'
        fi
    fi

    # Alias personnalisés
    local custom_aliases
    custom_aliases="$(echo "$stripped" | grep -E '^\s*alias ' | grep -vE "$skip_re" || true)"
    if [ -n "$custom_aliases" ]; then
        show_block "Alias personnalisés :" "$custom_aliases"
        if ask "Migrer vers ~/.bashrc.local ?"; then
            result+="# Alias personnalisés"$'\n'"$custom_aliases"$'\n\n'
        fi
    fi

    # Fonctions personnalisées (en-têtes uniquement)
    local custom_funcs
    custom_funcs="$(echo "$stripped" \
        | grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{?' \
        | grep -vE '(_timer_start|_prompt_command|_pl|_exit_status|_git_branch|__fzf|__conda|__bp)' \
        || true)"
    if [ -n "$custom_funcs" ]; then
        show_block "Fonctions personnalisées détectées (en-têtes) :" "$custom_funcs"
        warn "Les corps de fonction ne sont pas extraits automatiquement."
        warn "Vérifie le backup pour récupérer le code complet si nécessaire."
        if ask "Migrer les en-têtes comme rappel dans ~/.bashrc.local ?"; then
            result+="# TODO: Fonctions à récupérer depuis le backup"$'\n'
            result+="# $(echo "$custom_funcs" | tr '\n' ' ')"$'\n\n'
        fi
    fi

    # ── Écriture du résultat ──
    result="$(echo "$result" | sed -e '/^$/{ N; /^\n$/d; }')"  # dédoubler lignes vides
    if [ -n "$result" ]; then
        printf '%s\n' "$result" > ~/.bashrc.local
        ok "Personnalisations sauvegardées → ~/.bashrc.local"
    else
        info "Aucune personnalisation locale détectée"
    fi
}

# ══════════════════════════════════════════════════════════════
#  Déploiement
# ══════════════════════════════════════════════════════════════
deploy_bashrc() {
    migrate_existing_bashrc

    if [ -f ~/.bashrc ] && ! diff -q "$REPO_DIR/bashrc" ~/.bashrc &>/dev/null; then
        local backup=~/.bashrc.backup.$(date +%Y%m%d-%H%M%S)
        cp ~/.bashrc "$backup"
        ok "Backup : $backup"
    fi

    cp "$REPO_DIR/bashrc" ~/.bashrc
    ok ".bashrc installé"
}

setup_bash_profile() {
    [ "$PLATFORM" = "macos" ] || return 0

    if [ ! -f ~/.bash_profile ]; then
        cat > ~/.bash_profile << 'EOF'
eval "$(/usr/local/bin/brew shellenv bash 2>/dev/null || /opt/homebrew/bin/brew shellenv bash 2>/dev/null)"

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
EOF
        ok ".bash_profile créé (brew + source bashrc)"
    elif ! grep -qE 'source ~/\.bashrc|source "\$HOME/\.bashrc"|\. ~/\.bashrc|\. "\$HOME/\.bashrc"' ~/.bash_profile; then
        warn ".bash_profile ne source pas .bashrc"
        warn "  Ajoute : if [ -f ~/.bashrc ]; then source ~/.bashrc; fi"
    else
        ok ".bash_profile source déjà .bashrc"
    fi
}

# ══════════════════════════════════════════════════════════════
#  Post-installation
# ══════════════════════════════════════════════════════════════
post_install() {
    echo ""
    ok "Installation terminée !"
    echo ""

    case "$PLATFORM" in
        macos)
            info "Police : iTerm2 → Settings → Profiles → Text → Font → MesloLGS Nerd Font"
            info "Alt+C  : iTerm2 → Settings → Profiles → Keys → Key Mappings"
            info "         Ajouter : ⌥C → Send Escape Sequence → c"
            ;;
        wsl2)
            info "Police : Windows Terminal → Paramètres → Profil → Apparence → MesloLGS NF"
            ;;
        raspberry|linux)
            info "La police Nerd Font doit être configurée sur le terminal"
            info "depuis lequel tu te connectes en SSH (pas sur cette machine)."
            ;;
    esac

    if [ -f ~/.bashrc.local ]; then
        echo ""
        info "Vérifie ~/.bashrc.local puis recharge : source ~/.bashrc"
    else
        echo ""
        info "Recharge : source ~/.bashrc"
    fi
}

# ══════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════
main() {
    echo "┌──────────────────────────────────────┐"
    echo "│      Terminal Setup — Installation    │"
    echo "└──────────────────────────────────────┘"
    echo ""
    info "Plateforme : $PLATFORM"
    echo ""

    install_deps
    deploy_bashrc
    setup_bash_profile
    post_install
}

main "$@"
