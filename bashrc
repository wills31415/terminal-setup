# =============================================================
#  COULEURS — activer le support couleur (GNU/Linux)
# =============================================================
# Génère LS_COLORS depuis dircolors (remplace LSCOLORS macOS)
if command -v dircolors &>/dev/null; then
    eval "$(dircolors -b)"
fi

export GREP_COLOR='1;32'

# Alias colorisés (GNU ls : --color=auto, pas -G)
alias ls='ls --color=auto'
alias ll='ls -lh --color=auto'
alias la='ls -lah --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# Activer les couleurs dans less (pour man, git log, etc.)
export LESS='-R'
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'


# =============================================================
#  HISTORIQUE
# =============================================================
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups   # pas de doublons
shopt -s histappend                        # append (pas écrasement)


# =============================================================
#  PATH
# =============================================================
export PATH="$HOME/.local/bin:$PATH"


# =============================================================
#  POWERLINE PROMPT
# =============================================================
# Requiert une Nerd Font (ex: MesloLGS Nerd Font)
#   Sous WSL2 : installer la police sur Windows, puis la sélectionner
#   dans Windows Terminal → Paramètres → Profil → Apparence → Police

# Désactiver la modification du PS1 par conda (on gère nous-mêmes)
export CONDA_CHANGEPS1=false

# Séparateur powerline (U+E0B0)
_PL_SEP=$'\uE0B0'

# Couleurs des segments (R;G;B pour truecolor)
#   BG = fond du segment, FG = texte du segment
_PL_BG_OK="45;90;39"         _PL_FG_OK="168;216;168"       # vert — succès
_PL_BG_ERR="90;26;26"        _PL_FG_ERR="240;160;160"      # rouge — erreur
_PL_BG_HOST="38;79;120"      _PL_FG_HOST="215;215;215"     # bleu — user@host
_PL_BG_SSH="90;58;26"        _PL_FG_SSH="232;200;138"      # ambre — SSH
_PL_BG_DIR="42;90;58"        _PL_FG_DIR="200;230;200"      # vert clair — chemin
_PL_BG_GIT="90;74;0"         _PL_FG_GIT="229;214;138"      # jaune — git
_PL_BG_PY="74;37;85"         _PL_FG_PY="212;181;224"       # violet — conda/python
_PL_BG_DOCK="26;74;74"       _PL_FG_DOCK="142;208;208"     # teal — docker
_PL_BG_JOB="58;58;42"        _PL_FG_JOB="200;200;160"      # olive — jobs

# --- Chronomètre : enregistre le début de chaque commande ---
_timer_start() {
    [[ -z "${_prompt_ready:-}" ]] && return
    [[ "$BASH_COMMAND" == "_prompt_command" ]] && return
    [[ "$BASH_COMMAND" == __bp_* ]] && return
    [[ "$BASH_COMMAND" == "trap "* ]] && return
    [[ " ${FUNCNAME[*]} " == *" _prompt_command "* ]] && return
    _cmd_start="${EPOCHREALTIME/,/.}"
    _cmd_ran=1
}
trap '_timer_start' DEBUG

# --- Construction du prompt ---
_prompt_command() {
    local exit_code=$?                         # DOIT être la 1ère ligne
    local timer_end="${EPOCHREALTIME/,/.}"      # Capturer immédiatement
    local timer_start="${_cmd_start:-}"

    # Ignorer le chronomètre si aucune commande réelle n'a été exécutée
    if [[ -z "${_cmd_ran:-}" ]]; then
        timer_start=""
    fi

    # ── Durée d'exécution ──
    local duration_ms=0
    if [[ -n "$timer_start" ]]; then
        local end_s="${timer_end%.*}"   end_us="${timer_end#*.}"
        local sta_s="${timer_start%.*}" sta_us="${timer_start#*.}"
        end_us="${end_us}000000"; end_us="${end_us:0:6}"
        sta_us="${sta_us}000000"; sta_us="${sta_us:0:6}"
        local diff_s=$(( end_s - sta_s ))
        local diff_us=$(( 10#$end_us - 10#$sta_us ))
        if (( diff_us < 0 )); then
            (( diff_s-- ))
            (( diff_us += 1000000 ))
        fi
        duration_ms=$(( diff_s * 1000 + diff_us / 1000 ))
    fi

    local dur
    if (( duration_ms >= 60000 )); then
        dur="$(( duration_ms / 60000 ))m $(( duration_ms % 60000 / 1000 ))s"
    elif (( duration_ms >= 1000 )); then
        dur="$(( duration_ms / 1000 )).$(( duration_ms % 1000 / 100 ))s"
    else
        dur="${duration_ms}ms"
    fi

    # ── Segment : statut + durée (masqué si aucune commande exécutée) ──
    local seg_status_content="" seg_status_bg="" seg_status_fg=""
    if [[ -n "${_cmd_ran:-}" ]]; then
        if (( exit_code == 0 )); then
            seg_status_content="✔ ${dur}"
            seg_status_bg="$_PL_BG_OK"  seg_status_fg="$_PL_FG_OK"
        else
            seg_status_content="✘ ${exit_code} — ${dur}"
            seg_status_bg="$_PL_BG_ERR" seg_status_fg="$_PL_FG_ERR"
        fi
    fi

    # ── Segment : user@host (+ indicateur SSH) ──
    local seg_host_content seg_host_bg seg_host_fg
    if [[ -n "${SSH_TTY:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_CONNECTION:-}" ]]; then
        seg_host_content="⚡ \\u@\\h"
        seg_host_bg="$_PL_BG_SSH"  seg_host_fg="$_PL_FG_SSH"
    else
        seg_host_content="\\u@\\h"
        seg_host_bg="$_PL_BG_HOST" seg_host_fg="$_PL_FG_HOST"
    fi

    # ── Segment : git (branche, ahead/behind, modifiés, stash) ──
    local seg_git_content=""
    local _git_out
    if _git_out=$(git status --porcelain=v2 --branch 2>/dev/null); then
        local branch="" ahead=0 behind=0 dirty=0
        while IFS= read -r _line; do
            case "$_line" in
                "# branch.head "*)  branch="${_line#\# branch.head }" ;;
                "# branch.ab "*)
                    [[ "$_line" =~ \+([0-9]+) ]] && ahead="${BASH_REMATCH[1]}"
                    [[ "$_line" =~ \-([0-9]+) ]] && behind="${BASH_REMATCH[1]}"
                    ;;
                [12]" "*|"?"*)  (( dirty++ )) ;;
            esac
        done <<< "$_git_out"
        local stash_n
        stash_n=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

        seg_git_content="⎇ ${branch}"
        (( ahead > 0 ))   && seg_git_content+=" ↑${ahead}"
        (( behind > 0 ))  && seg_git_content+=" ↓${behind}"
        (( dirty > 0 ))   && seg_git_content+=" ●${dirty}"
        (( stash_n > 0 )) && seg_git_content+=" ⚑${stash_n}"
    fi

    # ── Segment : conda/python ──
    local seg_py_content=""
    [[ -n "${CONDA_DEFAULT_ENV:-}" ]] && seg_py_content="🐍 ${CONDA_DEFAULT_ENV}"

    # ── Segment : clusters Docker actifs (via da) ──
    local seg_dock_content=""
    if [[ -d "${CUSTOM_DOCKER_CLUSTER_BASE_PATH:-}" ]]; then
        local _dc=0
        for _lf in "$CUSTOM_DOCKER_CLUSTER_BASE_PATH"/*/.lock; do
            [[ -f "$_lf" ]] && (( _dc++ ))
        done
        (( _dc > 0 )) && seg_dock_content="🐳 ${_dc}"
    fi

    # ── Segment : jobs en arrière-plan ──
    local seg_job_content=""
    local _jc
    _jc=$(jobs -p 2>/dev/null | wc -l | tr -d ' ')
    (( _jc > 0 )) && seg_job_content="⚙ ${_jc}"

    # ── Assemblage du prompt ──
    local _prev_bg=""
    PS1=""

    # Fonction locale : ajouter un segment powerline
    _pl() {
        local bg="$1" fg="$2" text="$3"
        if [[ -n "$_prev_bg" ]]; then
            PS1+="\[\e[38;2;${_prev_bg}m\e[48;2;${bg}m\]${_PL_SEP}"
        fi
        PS1+="\[\e[38;2;${fg}m\e[48;2;${bg}m\] ${text} "
        _prev_bg="$bg"
    }

    # Segments fixes
    [[ -n "$seg_status_content" ]] && _pl "$seg_status_bg" "$seg_status_fg" "$seg_status_content"
    _pl "$seg_host_bg"   "$seg_host_fg"   "$seg_host_content"
    _pl "$_PL_BG_DIR"    "$_PL_FG_DIR"    "\\w"

    # Segments conditionnels
    [[ -n "$seg_git_content" ]]  && _pl "$_PL_BG_GIT"  "$_PL_FG_GIT"  "$seg_git_content"
    [[ -n "$seg_py_content" ]]   && _pl "$_PL_BG_PY"   "$_PL_FG_PY"   "$seg_py_content"
    [[ -n "$seg_dock_content" ]] && _pl "$_PL_BG_DOCK"  "$_PL_FG_DOCK" "$seg_dock_content"
    [[ -n "$seg_job_content" ]]  && _pl "$_PL_BG_JOB"   "$_PL_FG_JOB"  "$seg_job_content"

    # Fermeture : séparateur final → fond transparent
    PS1+="\[\e[0m\e[38;2;${_prev_bg}m\]${_PL_SEP}\[\e[0m\]"

    # Nouvelle ligne + symbole de saisie
    PS1+="\n\[\e[38;2;229;192;123m\]❯\[\e[0m\] "

    # Activer le chronomètre (inactif pendant l'initialisation du shell)
    _prompt_ready=1

    # Nettoyage du chronomètre (DOIT être la dernière instruction)
    unset _cmd_start
    unset _cmd_ran
}

PROMPT_COMMAND="_prompt_command"


# =============================================================
#  AUTO-COMPLÉTION
# =============================================================

# Bash-completion système (Debian/Ubuntu/WSL2)
if [ -r "/usr/share/bash-completion/bash_completion" ]; then
    source "/usr/share/bash-completion/bash_completion"
elif [ -r "/etc/bash_completion" ]; then
    source "/etc/bash_completion"
fi

# Complétion Docker (via le paquet bash-completion de Docker)
# Installé automatiquement avec : sudo apt install docker-ce ou docker.io
# Le fichier est généralement dans /usr/share/bash-completion/completions/docker
# → rien à sourcer manuellement si bash-completion système est chargé

# Options de complétion bash (liste classique)
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set mark-symlinked-directories on'


# =============================================================
#  FZF — fuzzy finder (Ctrl+R, Ctrl+T, Alt+C)
# =============================================================
# Installation : sudo apt install fzf   OU   git clone + install
# Selon la méthode d'installation, l'un de ces fichiers existe :
if [ -f ~/.fzf.bash ]; then
    source ~/.fzf.bash                                         # install via git
elif [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    source /usr/share/doc/fzf/examples/key-bindings.bash      # install via apt
    source /usr/share/bash-completion/completions/fzf 2>/dev/null
fi

export FZF_DEFAULT_OPTS='
  --height=40%
  --layout=reverse
  --border=rounded
  --prompt="❯ "
  --pointer="▶"
  --marker="✓"
'
export FZF_CTRL_R_OPTS='--prompt="History ❯ "'
export FZF_CTRL_T_OPTS='--preview="head -80 {}" --prompt="Files ❯ "'
export FZF_ALT_C_OPTS='--preview="ls {}" --prompt="cd ❯ "'
