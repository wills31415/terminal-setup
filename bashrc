# terminal-setup — ~/.bashrc commun à toutes les machines (macOS, Linux, Raspberry Pi,
# WSL2, Termux). Ne pas éditer ici : les réglages propres à une machine vont dans
# ~/.bashrc.local (jamais écrasé). Mise à jour : terminal-setup update.

# Non-interactive shells → ne rien charger
case $- in
    *i*) ;;
      *) return;;
esac

# Termux (Android) : préfixe de ses paquets (/data/data/com.termux/files/usr).
_TS_TERMUX=""
[[ -n "${TERMUX_VERSION:-}" || "${PREFIX:-}" == */com.termux/* ]] && _TS_TERMUX=1


# =============================================================
#  COULEURS
# =============================================================
case "$(uname -s)" in
    Darwin)
        export CLICOLOR=1
        export LSCOLORS=GxFxCxDxBxegedabagaced
        alias ls='ls -G'
        alias ll='ls -lhG'
        alias la='ls -lahG'
        ;;
    *)
        if command -v dircolors &>/dev/null; then
            eval "$(dircolors -b)"
        fi
        alias ls='ls --color=auto'
        alias ll='ls -lh --color=auto'
        alias la='ls -lah --color=auto'
        ;;
esac

export GREP_COLOR='1;32'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

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
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend
shopt -s checkwinsize


# =============================================================
#  PATH
# =============================================================
export PATH="$HOME/.local/bin:$PATH"


# =============================================================
#  POWERLINE PROMPT
# =============================================================
export CONDA_CHANGEPS1=false
export VIRTUAL_ENV_DISABLE_PROMPT=1

_PL_SEP=$''

_PL_BG_OK="45;90;39"         _PL_FG_OK="168;216;168"
_PL_BG_ERR="90;26;26"        _PL_FG_ERR="240;160;160"
_PL_BG_HOST="38;79;120"      _PL_FG_HOST="215;215;215"
_PL_BG_SSH="90;58;26"        _PL_FG_SSH="232;200;138"
_PL_BG_DIR="42;90;58"        _PL_FG_DIR="200;230;200"
_PL_BG_GIT="90;74;0"         _PL_FG_GIT="229;214;138"
_PL_BG_PY="74;37;85"         _PL_FG_PY="212;181;224"
_PL_BG_DOCK="26;74;74"       _PL_FG_DOCK="142;208;208"
_PL_BG_JOB="58;58;42"        _PL_FG_JOB="200;200;160"
_PL_BG_ROOT="140;24;24"      _PL_FG_ROOT="255;225;225"

# ── Identité de la machine : icône + couleur (bg) par machine du homelab ──
# Surchargeable dans ~/.bashrc.local : TS_NAME (nom affiché), TS_USER (utilisateur
# affiché), TS_ICON, TS_COLOR ("r;g;b" du fond).
_ts_identity() {
    local name="${TS_NAME:-${HOSTNAME%%.*}}"
    local icon="" bg="$_PL_BG_HOST" fg="$_PL_FG_HOST"
    case "$name" in
        gw)               icon="🛡"  bg="38;79;120"   fg="215;228;245" ;;   # passerelle
        nas)              icon="🗄"  bg="74;50;112"   fg="225;210;245" ;;   # stockage
        enclume)          icon="🖥"  bg="112;62;38"   fg="245;215;195" ;;   # PC fixe
        macbook-pro)      icon="💻" bg="78;84;96"    fg="228;231;236" ;;   # portable
        galaxy-s22-ultra) icon="📱" bg="112;40;82"   fg="245;205;225" ;;   # téléphone
    esac
    [[ -n "${TS_ICON:-}" ]] && icon="$TS_ICON"
    [[ -n "${TS_COLOR:-}" ]] && bg="$TS_COLOR"
    _TS_ID_NAME="$name" _TS_ID_ICON="$icon" _TS_ID_BG="$bg" _TS_ID_FG="$fg"
}

_timer_start() {
    [[ -z "${_prompt_ready:-}" ]] && return
    [[ "$BASH_COMMAND" == "_prompt_command" ]] && return
    [[ "$BASH_COMMAND" == "update_terminal_cwd" ]] && return
    [[ "$BASH_COMMAND" == __iterm2_* ]] && return
    [[ "$BASH_COMMAND" == __bp_* ]] && return
    [[ "$BASH_COMMAND" == "trap "* ]] && return
    [[ " ${FUNCNAME[*]} " == *" _prompt_command "* ]] && return
    _cmd_start="${EPOCHREALTIME/,/.}"
    _cmd_ran=1
}
trap '_timer_start' DEBUG

_prompt_command() {
    local exit_code=$?
    local timer_end="${EPOCHREALTIME/,/.}"
    local timer_start="${_cmd_start:-}"

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

    # ── Segment : statut + durée ──
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

    # ── Segment : machine (icône + couleur), root en rouge, ⚡ si SSH ──
    _ts_identity
    local _user="${TS_USER:-\\u}"
    local seg_host_content="${_TS_ID_ICON:+$_TS_ID_ICON }${_user}@${_TS_ID_NAME}"
    local seg_host_bg="$_TS_ID_BG" seg_host_fg="$_TS_ID_FG"
    if (( EUID == 0 )); then
        seg_host_content="⚠ ${seg_host_content}"
        seg_host_bg="$_PL_BG_ROOT" seg_host_fg="$_PL_FG_ROOT"
    fi
    if [[ -n "${SSH_TTY:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_CONNECTION:-}" ]]; then
        seg_host_content+=" ⚡"
    fi

    # ── Segment : git ──
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
    if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
        seg_py_content="🐍 ${CONDA_DEFAULT_ENV}"
    elif [[ -n "${VIRTUAL_ENV:-}" ]]; then
        local _venv_name="${VIRTUAL_ENV_PROMPT:-}"
        if [[ -z "$_venv_name" ]]; then
            _venv_name="$(basename "$VIRTUAL_ENV")"
            # Noms génériques → on affiche plutôt le dossier projet (parent)
            case "$_venv_name" in
                .venv|venv|.env|env|virtualenv|.virtualenv)
                    _venv_name="$(basename "$(dirname "$VIRTUAL_ENV")")" ;;
            esac
        fi
        seg_py_content="🐍 ${_venv_name}"
    fi

    # ── Segment : clusters Docker actifs ──
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

    # ── Assemblage ──
    local _prev_bg=""
    PS1=""

    _pl() {
        local bg="$1" fg="$2" text="$3"
        if [[ -n "$_prev_bg" ]]; then
            PS1+="\[\e[38;2;${_prev_bg}m\e[48;2;${bg}m\]${_PL_SEP}"
        fi
        PS1+="\[\e[38;2;${fg}m\e[48;2;${bg}m\] ${text} "
        _prev_bg="$bg"
    }

    [[ -n "$seg_status_content" ]] && _pl "$seg_status_bg" "$seg_status_fg" "$seg_status_content"
    _pl "$seg_host_bg"   "$seg_host_fg"   "$seg_host_content"
    _pl "$_PL_BG_DIR"    "$_PL_FG_DIR"    "\\w"
    [[ -n "$seg_git_content" ]]  && _pl "$_PL_BG_GIT"  "$_PL_FG_GIT"  "$seg_git_content"
    [[ -n "$seg_py_content" ]]   && _pl "$_PL_BG_PY"   "$_PL_FG_PY"   "$seg_py_content"
    [[ -n "$seg_dock_content" ]] && _pl "$_PL_BG_DOCK"  "$_PL_FG_DOCK" "$seg_dock_content"
    [[ -n "$seg_job_content" ]]  && _pl "$_PL_BG_JOB"   "$_PL_FG_JOB"  "$seg_job_content"

    PS1+="\[\e[0m\e[38;2;${_prev_bg}m\]${_PL_SEP}\[\e[0m\]"
    PS1+="\n\[\e[38;2;229;192;123m\]❯\[\e[0m\] "

    _prompt_ready=1
    unset _cmd_start
    unset _cmd_ran
}

# Console sans police ni couleurs vraies (console série de l'iDRAC, écran Linux) :
# prompt simple et lisible, sans séparateurs Powerline ni icônes.
_prompt_plain() {
    local exit_code=$? mark="\[\e[32m\]ok\[\e[0m\]"
    (( exit_code )) && mark="\[\e[31m\]err $exit_code\[\e[0m\]"
    local who="\[\e[1;36m\]\u@${TS_NAME:-\h}\[\e[0m\]"
    (( EUID == 0 )) && who="\[\e[1;31m\]\u@${TS_NAME:-\h}\[\e[0m\]"
    PS1="[$mark] $who \[\e[32m\]\w\[\e[0m\]\n\\$ "
}

case "${TERM:-dumb}" in
    linux|vt*|dumb) PROMPT_COMMAND="_prompt_plain" ;;
    *)              PROMPT_COMMAND="_prompt_command" ;;
esac


# =============================================================
#  AUTO-COMPLÉTION
# =============================================================
case "$(uname -s)" in
    Darwin)
        if [ -r "${HOMEBREW_PREFIX:-/usr/local}/etc/profile.d/bash_completion.sh" ]; then
            source "${HOMEBREW_PREFIX:-/usr/local}/etc/profile.d/bash_completion.sh"
        fi
        for _f in docker docker-compose; do
            [ -f "/Applications/Docker.app/Contents/Resources/etc/${_f}.bash-completion" ] && \
                source "/Applications/Docker.app/Contents/Resources/etc/${_f}.bash-completion"
        done
        unset _f
        ;;
    *)
        if [ -r "${PREFIX:-/usr}/share/bash-completion/bash_completion" ]; then
            source "${PREFIX:-/usr}/share/bash-completion/bash_completion"     # Linux, Termux
        elif [ -r /usr/share/bash-completion/bash_completion ]; then
            source /usr/share/bash-completion/bash_completion
        elif [ -r /etc/bash_completion ]; then
            source /etc/bash_completion
        fi
        ;;
esac

bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set mark-symlinked-directories on'


# =============================================================
#  FZF — fuzzy finder (Ctrl+R, Ctrl+T, Alt+C)
# =============================================================
if command -v fzf &>/dev/null && fzf --bash &>/dev/null; then
    eval "$(fzf --bash)"
elif [ -f ~/.fzf.bash ]; then
    source ~/.fzf.bash
elif [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    source /usr/share/doc/fzf/examples/key-bindings.bash
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


# =============================================================
#  CONDA À LA DEMANDE — à appeler depuis ~/.bashrc.local :
#    ts_lazy_conda /chemin/vers/bin/conda
#  conda ne s'initialise qu'au premier « conda … » : le terminal s'ouvre ~1 s plus vite.
# =============================================================
ts_lazy_conda() {
    local bin="$1"
    [ -x "$bin" ] || return 0
    eval "conda() {
        unset -f conda
        eval \"\$('$bin' 'shell.bash' 'hook' 2>/dev/null)\"
        conda \"\$@\"
    }"
}


# =============================================================
#  PERSONNALISATIONS LOCALES (~/.bashrc.local)
# =============================================================
[ -f ~/.bash_aliases ] && . ~/.bash_aliases
[ -f ~/.bashrc.local ] && source ~/.bashrc.local
