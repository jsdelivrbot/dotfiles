################################################################################
# .bashrc
# This file is read for interactive shells
# and .bash_profile is read for login shells

# Mostly, aliases and functions go into .bashrc 
# and environment variables and startup programs go into .bash_profile

# Unless there is a specific need, it's simpler to put most things into .bashrc
# And reference it into .bash_profile
################################################################################

# Source global definitions
if [[ -f /etc/bashrc ]]; then
  . /etc/bashrc
fi

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Aliases
# Some people use a different file for aliases
if [[ -f "${HOME}/.bash_aliases" ]]; then
  . "${HOME}/.bash_aliases"
fi

# Functions
# Some people use a different file for functions
if [[ -f "${HOME}/.bash_functions" ]]; then
  . "${HOME}/.bash_functions"
fi

# Set umask for new files
umask 027

################################################################################
# Set the PATH, add in xpg6 and xpg4 in case we're on Solaris
PATH=/usr/gnu/bin:/usr/xpg6/bin:/usr/xpg4/bin:/usr/kerberos/bin:/usr/kerberos/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/opt/csw/bin:/opt/csw/sbin:/opt/sfw/bin:/opt/sfw/sbin:/usr/sfw/bin:/usr/sfw/sbin:$PATH

# We sanitise the PATH variable to only include
# directories that exist on the host.
newPath=
# Split the PATH out into individual loop elements and deduplicate
for dir in $(echo "${PATH}" | tr ":" "\n" | grep -v "\$PATH" | nl | sort -u -k2 | sort | awk '{print $2}'); do
  # If the directory exists, add it to the newPath variable
  if [ -d "${dir}" ]; then
    newPath="${newPath}:${dir}"
  fi
done

# If a leading colon sneaks in, get rid of it
if echo "${newPath}" | grep "^:" &>/dev/null; then
  newPath=$(echo "${newPath}" | cut -d ":" -f2-)
fi

# Now assign our freshly built newPath variable
PATH="${newPath}"

# If PATH doesn't contain ~/bin, then check if it exists, if so, append it to PATH
#if [[ $PATH != ?(*:)$HOME/bin?(:*) ]]; then # This breaks on older versions of bash
#if [[ ! $PATH =~ $HOME/bin{,:} ]]; then # This breaks on even older versions of bash e.g. 2.05
if ! echo "$PATH" | grep "$HOME/bin" &>/dev/null; then
  if [[ -d $HOME/bin ]]; then
    PATH=$PATH:$HOME/bin
  fi
fi

# Finally, export the PATH
export PATH

# A portable alternative to command -v/which/type
pathfind() {
  OLDIFS="$IFS"
  IFS=:
  for prog in $PATH; do
    if [[ -x "$prog/$*" ]]; then
      printf '%s\n' "$prog/$*"
      IFS="$OLDIFS"
      return 0
    fi
  done
  IFS="$OLDIFS"
  return 1
}

# Check if /usr/bin/sudo and /bin/bash exist
# If not, try to find them and suggest a symlink
if [[ ! -f /usr/bin/sudo ]]; then
  if pathfind sudo &>/dev/null; then
    printf '%s\n' "/usr/bin/sudo not found.  Please run 'sudo ln -s $(pathfind sudo) /usr/bin/sudo'"
  else
    printf '%s\n' "/usr/bin/sudo not found, and I couldn't find 'sudo' in '$PATH'"
  fi
fi
if [[ ! -f /bin/bash ]]; then
  if pathfind bash &>/dev/null; then
    printf '%s\n' "/bin/bash not found.  Please run 'sudo ln -s $(pathfind bash) /bin/bash'"
  else
    printf '%s\n' "/bin/bash not found, and I couldn't find 'bash' in '$PATH'"
  fi
fi

################################################################################
# Set the PROMPT_COMMAND
# If we've got bash v2 (e.g. Solaris 9), we cripple PROMPT_COMMAND.  Otherwise it will complain about 'history not found'
if (( BASH_VERSINFO[0] = 2 )) 2>/dev/null; then
  PROMPT_COMMAND=settitle
# Otherwise, for newer versions of bash (e.g. Solaris 10+), we treat it as per Linux
elif (( BASH_VERSINFO[0] > 2 )) 2>/dev/null; then
  # After each command, append to the history file and reread it
  # This attempts to keep history sync'd across multiple sessions
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r; settitle"
fi
export PROMPT_COMMAND

################################################################################
# Check the window size after each command and, if necessary,
# Update the values of LINES and COLUMNS.
# This attempts to correct line-wrapping-over-prompt issues when a window is resized
shopt -s checkwinsize

# Set the bash history timestamp format
export HISTTIMEFORMAT="%F,%T "

# don't put duplicate lines in the history. See bash(1) for more options
# and ignore commands that start with a space
HISTCONTROL=ignoredups:ignorespace
 
# append to the history file instead of overwriting it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=5000
HISTFILESIZE=5000

# Standardise the title header
settitle() {
  printf "\033]0;${HOSTNAME%%.*}:${PWD}\a"
  # This might also need to be expressed as
  #printf "\\033]2;${HOSTNAME}:${PWD}\\007\\003"
  # I possibly need to test and figure out a way to auto-switch between these two
}

# Disable ctrl+s (XOFF) in PuTTY
stty ixany
stty ixoff -ixon

################################################################################
# Programmable Completion (Tab Completion)

# Enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Fix 'cd' tab completion
complete -d cd

# SSH auto-completion based on ~/.ssh/config.
if [[ -e ~/.ssh/config ]]; then
  complete -o "default" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh
fi

# SSH auto-completion based on ~/.ssh/known_hosts.
if [[ -e ~/.ssh/known_hosts ]]; then
  complete -o "default" -W "$(cut -f 1 -d ' ' ~/.ssh/known_hosts | sed -e s/,.*//g | uniq | grep -v "\[" | tr ' ' '\n')" scp sftp ssh
fi

################################################################################
# OS specific tweaks

if [[ "$(uname)" = "SunOS" ]]; then
  # Sort out "Terminal Too Wide" issue in vi on Solaris
  stty columns 140

elif [[ "$(uname)" = "Linux" ]]; then
  # Enable wide diff, handy for side-by-side i.e. diff -y or sdiff
  # Linux only, as -W/-w options aren't available in non-GNU
  alias diff='diff -W $(( $(tput cols) - 2 ))'
  alias sdiff='sdiff -w $(( $(tput cols) - 2 ))'
 
  # Correct backspace behaviour for some troublesome Linux servers that don't abide by .inputrc
  if tty --quiet; then
    stty erase '^?'
  fi
  
# I haven't used HP-UX in a while, but just to be sure
# we fix the backspace quirk for xterm
elif [[ "$(uname -s)" = "HP-UX" ]] && [[ "$TERM" = "xterm" ]]; then
  stty intr ^c
  stty erase ^?
fi

################################################################################
# Aliases

# If .curl-format exists, AND 'curl' is available, enable curl-trace alias
if [[ -f ~/.curl-format ]] && command -v curl &>/dev/null; then
  alias curl-trace='curl -w "@/${HOME}/.curl-format" -o /dev/null -s'
fi

# Enable color support of ls and also add handy aliases
if [[ -x /usr/bin/dircolors ]]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# It looks like blindly asserting the following upsets certain 
# Solaris versions of *grep.  So we throw in an extra check
if echo "test" | grep --color=auto test &>/dev/null; then
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# Again, cater for Solaris.  First test for GNU:
if ls --color=auto &>/dev/null; then
  alias ls='ls --color=auto -F'
# Try for OSX, why not?
elif [[ $(uname) = "Darwin" ]]; then
  alias ls='ls -FG'
else
  alias ls='ls -F'
fi

# Check whether 'ls' supports human readable ( -h )
ls -h /dev/null 2> /dev/null 1>&2 && H='-h'

alias l.='ls -lAdF ${H} .*'    # list only hidden things
alias la='ls -lAF ${H}'        # list all
alias ll='ls -alF ${H}'        # list long

# When EDITOR == vim ; alias vi to vim
[[ "${EDITOR##*/}" = "vim" ]] && alias vi='vim'

if command -v vim &>/dev/null; then
  alias vi='vim'
fi

################################################################################
# Functions

# Bytes to Human Readable conversion function from http://unix.stackexchange.com/a/98790
# Usage: bytestohuman [number to convert] [pad or not yes/no] [base 1000/1024]
bytestohuman() {
  # converts a byte count to a human readable format in IEC binary notation (base-1024),
  # rounded to two decimal places for anything larger than a byte. 
  # switchable to padded format and base-1000 if desired.
  local L_BYTES="${1:-0}"
  local L_PAD="${2:-no}"
  local L_BASE="${3:-1024}"
  awk -v bytes="${L_BYTES}" -v pad="${L_PAD}" -v base="${L_BASE}" 'function human(x, pad, base) {
   if(base!=1024)base=1000
   basesuf=(base==1024)?"iB":"B"

   s="BKMGTEPYZ"
   while (x>=base && length(s)>1)
         {x/=base; s=substr(s,2)}
   s=substr(s,1,1)

   xf=(pad=="yes") ? ((s=="B")?"%5d   ":"%8.2f") : ((s=="B")?"%d":"%.2f")
   s=(s!="B") ? (s basesuf) : ((pad=="no") ? s : ((basesuf=="iB")?(s "  "):(s " ")))

   return sprintf( (xf " %s\n"), x, s)
  }
  BEGIN{print human(bytes, pad, base)}'
  return $?
}

# Capitalise words
# This is a bash-portable way to do this.
# To achieve with awk, use awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
# Known problem: leading whitespace is chomped.
capitalise() {
  # Ignore any instances of '*' that may be in a file
  local GLOBIGNORE="*"
  
  # Check that stdin or $1 isn't empty
  if [[ -t 0 ]] && [[ -z $1 ]]; then
    printf '%s\n' "Usage:  capitalise string" ""
    printf "\t%s\n" "Capitalises the first character of STRING and/or its elements."
    return 0
  # Disallow both piping in strings and declaring strings
  elif [[ ! -t 0 ]] && [[ ! -z $1 ]]; then
    printf '%s\n' "[ERROR] capitalise: Please select either piping in or declaring a string to capitalise, not both."
    return 1
  fi

  # If parameter is a file, or stdin is used, action that first
  if [[ -f $1 ]]||[[ ! -t 0 ]]; then
    # We require an exit condition for 'read', this covers the edge case
    # where a line is read that does not have a newline
    eof=
    while [[ -z "${eof}" ]]; do
      # Read each line of input
      read -r inLine || eof=true
      # If the line is blank, then print a blank line and continue
      if [[ -z "${inLine}" ]]; then
        printf '%s\n' ""
        continue
      fi
      # If we're using bash4, stop mucking about
      if (( BASH_VERSINFO == 4 )); then
        inLine=( ${inLine} )
        printf '%s ' "${inLine[@]^}" | trim
      # Otherwise, take the more exhaustive approach
      else
        # Split each line element for processing
        for inString in ${inLine}; do
          # Split off the first character and capitalise it
          inWord=$(echo "${inString:0:1}" | toupper)
          # Print out the uppercase var and the rest of the element
          outWord="${inWord}${inString:1}"
          # Pad the output so that multiple elements are spaced out
          printf "%s " "${outWord}"
        # We use to trim to remove any trailing whitespace
        done | trim
      fi
    done < "${1:-/dev/stdin}"

  # Otherwise, if a parameter exists, then capitalise all given elements
  # Processing follows the same path as before.
  elif [[ -n "$*" ]]; then
    if (( BASH_VERSINFO == 4 )); then
      printf '%s ' "${@^}" | trim
    else    
      for inString in "$@"; do
        inWord=$(echo "${inString:0:1}" | toupper)
        outWord="$inWord${inString:1}"
        printf "%s " "${outWord}"
      done | trim
    fi
  fi
  
  # Unset GLOBIGNORE, even though we've tried to limit it to this function
  local GLOBIGNORE=
}

# Print the given text in the center of the screen.
# From https://github.com/Haroenv/config/blob/master/.bash_profile
center() {
  width=$(tput cols);
  str="$*";
  len=${#str};
  [ "${len}" -ge "${width}" ] && echo "$str" && return;
  for ((i = 0; i < $((((width - len)) / 2)); i++)); do
    echo -n " ";
  done;
  echo "$str";
}

# Check YAML syntax
checkyaml() {
  local textGreen
  local textRed
  local textRst
  textGreen=$(tput setaf 2)
  textRed=$(tput setaf 1)
  textRst=$(tput sgr0)

  # Check that $1 is defined...
  if [[ -z $1 ]]; then
    printf '%s\n' "Usage:  checkyaml file" ""
    printf "\t%s\n"  "Check the YAML syntax in FILE"
    return 1
  fi
  
  # ...and readable
  if [[ ! -r "$1" ]]; then
    printf '%s\n' "${textRed}[ERROR]${textRst} checkyaml: '$1' does not appear to exist or I can't read it."
    return 1
  else
    local file
    file="$1"
  fi

  # If we can see the internet, let's use it!
  if ! wget -T 1 http://yamllint.com/ &>/dev/null; then
    curl --data-urlencode yaml'@'"${file:-/dev/stdin}" -d utf8='%E2%9C%93' -d commit=Go  http://yamllint.com/ --trace-ascii out -G 2>&1 | egrep 'div.*background-color'

  # Check the YAML contents, if there's no error, print out a message saying so
  elif python -c 'import yaml, sys; print yaml.load(sys.stdin)' < "${file:-/dev/stdin}" &>/dev/null; then
    printf '%s\n' "${textGreen}[OK]${textRst} checkyaml: It seems the provided YAML syntax is ok."

  # Otherwise, print out an error message and dump the trace
  else
    printf '%s\n' "${textRed}[ERROR]${textRst} checkyaml: It seems there is an issue with the provided YAML syntax." ""
    python -c 'import yaml, sys; print yaml.load(sys.stdin)' < "${file:-/dev/stdin}"
  fi
}

# Indent code by four spaces, useful for posting in markdown
codecat() {
  sed 's/^/    /' "$@"
}

# Provide a function to compress common compressed Filetypes
compress() {
  File=$1
  shift
  case "${File}" in
    (*.tar.bz2) tar cjf "${File}" "$@"  ;;
    (*.tar.gz)  tar czf "${File}" "$@"  ;;
    (*.tgz)     tar czf "${File}" "$@"  ;;
    (*.zip)     zip "${File}" "$@"      ;;
    (*.rar)     rar "${File}" "$@"      ;;
    (*)         echo "Filetype not recognized" ;;
  esac
}

# Optional error handling function
# See: https://www.reddit.com/r/bash/comments/5kfbi7/best_practices_error_handling/
die() {
  local format="$1"
  shift
  tput setaf 1
  printf >&2 "$format\n" "$@"
  tput sgr0
  return 1
}

# Calculate how many seconds since epoch
epoch() {
  if command -v perl >/dev/null 2>&1; then
    perl -e "print time"
  elif command -v truss >/dev/null 2>&1 && [[ $(uname) = SunOS ]]; then
    truss date 2>&1 | grep ^time | awk -F"= " '{print $2}'
  elif command -v truss >/dev/null 2>&1 && [[ $(uname) = FreeBSD ]]; then
    truss date 2>&1 | grep ^gettimeofday | cut -d "{" -f2 | cut -d "." -f1
  elif date +%s >/dev/null 2>&1; then
    date +%s
  # Portable workaround based on http://www.etalabs.net/sh_tricks.html
  # We take extra steps to try to prevent accidental octal interpretation
  else
    local secsVar minsVar hourVar dayVar yrOffset yearVar
    secsVar=$(TZ=GMT0 date +%S)
    minsVar=$(TZ=GMT0 date +%M)
    hourVar=$(TZ=GMT0 date +%H)
    dayVar=$(TZ=GMT0 date +%j | sed 's/^0*//')
    yrOffset=$(( $(TZ=GMT0 date +%Y) - 1600 ))
    yearVar=$(( (yrOffset * 365 + yrOffset / 4 - yrOffset / 100 + yrOffset / 400 + dayVar - 135140) * 86400 ))

    printf '%s\n' "$(( yearVar + (${hourVar#0} * 3600) + (${minsVar#0} * 60) + ${secsVar#0} ))"
  fi
}

# Calculate how many days since epoch
epochdays() {
  printf '%s\n' "$(( epoch / 86400 ))"
}

# Function to extract common compressed file types
extract() {
 if [ -z "$1" ]; then
    # display usage if no parameters given
    printf '%s\n' "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
 else
    if [ -f "$1" ] ; then
      #local nameInLowerCase=$(awk '{print tolower($0)}' <<< "$1")
      local nameInLowerCase=$(tolower "$1")
      case "$nameInLowerCase" in
        (*.tar.bz2)   tar xvjf ./"$1"    ;;
        (*.tar.gz)    tar xvzf ./"$1"    ;;
        (*.tar.xz)    tar xvJf ./"$1"    ;;
        (*.lzma)      unlzma ./"$1"      ;;
        (*.bz2)       bunzip2 ./"$1"     ;;
        (*.rar)       unrar x -ad ./"$1" ;;
        (*.gz)        gunzip ./"$1"      ;;
        (*.tar)       tar xvf ./"$1"     ;;
        (*.tbz2)      tar xvjf ./"$1"    ;;
        (*.tgz)       tar xvzf ./"$1"    ;;
        (*.zip)       unzip ./"$1"       ;;
        (*.Z)         uncompress ./"$1"  ;;
        (*.7z)        7z x ./"$1"        ;;
        (*.xz)        unxz ./"$1"        ;;
        (*.exe)       cabextract ./"$1"  ;;
        (*)           echo "extract: '$1' - unknown archive method" ;;
      esac
    else
      printf '%s\n' "'$1' - file does not exist"
    fi
  fi
}

# flocate function.  This gives a search function that blends find and locate
# Will obviously only work where locate lives, so Solaris will mostly be out of luck
# Usage: flocate searchterm1 searchterm2 searchterm[n]
# Source: http://solarum.com/v.php?l=1149LV99
flocate() {
  if ! command -v locate &>/dev/null; then
    printf '%s\n' "[ERROR]: 'flocate' depends on 'locate', which wasn't found."
    return 1
  fi
  if [[ $# -gt 1 ]]; then
    display_divider=1
  else
    display_divider=0
  fi

  current_argument=0
  total_arguments=$#
  while [[ "${current_argument}" -lt "${total_arguments}" ]]; do
    current_file=$1
    if [ "${display_divider}" = "1" ] ; then
      printf '%s\n' "----------------------------------------" \
      "Matches for ${current_file}" \
      "----------------------------------------"
    fi

    filename_re="^\(.*/\)*$( echo "${current_file}" | sed s%\\.%\\\\.%g )$"
    locate -r "${filename_re}"
    shift
    (( current_argument = current_argument + 1 ))
  done
}

# Sort history by most used commands, can optionally print n lines (e.g. histrank [n])
histrank() { 
  HISTTIMEFORMAT="%y/%m/%d %T " history | awk '{out=$4; for(i=5;i<=NF;i++){out=out" "$i}; print out}' | sort | uniq -c | sort -nk1 | tail -n "${1:-$(tput lines)}"
}

# Test if a given value is an integer
isinteger() {
  if test "$1" -eq "$1" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Replicate 'let'.  Likely to not be needed in bash, mostly for my reference
if ! command -v let &>/dev/null; then
  let() {
    return "$((!($1)))"
  }
fi

# Write a horizontal line of characters
hr() {
  printf '%*s\n' "${1:-$COLUMNS}" | tr ' ' "${2:-#}"
}

# A reinterpretation of 'llh' from the hpuxtools toolset (hpux.ch)
# This provides human readable 'ls' output for systems
# whose version of 'ls' does not have the '-h' option
# Requires: bytestohuman function
llh() {
  # Print out the total line
  ls -l | head -n 1

  # Read each line of 'ls -l', excluding the total line
  ls -l | grep -v "total" | while read -r line; do
    # Get the size of the file
    size=$(echo "${line}" | awk '{print $5}')
    
    # Convert it to human readable
    newSize=$(bytestohuman ${size} no 1024)
    
    # Grab the filename from the $9th field onwards
    # This caters for files with spaces
    fileName=$(echo "${line}" | awk '{print substr($0, index($0,$9))}')
    
    # Echo the line into awk, format it nicely and insert our substitutions
    echo "${line}" | awk -v size="${newSize}" -v file="${fileName}" '{printf "%-11s %+2s %-10s %-10s %+11s %s %02d %-5s %s\n",$1,$2,$3,$4,size,$6,$7,$8,file}'
  done
}

# Enable X-Windows for cygwin, finds and assigns an available display env variable.
# To use, issue 'myx', and then 'ssh -X [host] "/some/path/to/gui-application" &'

# First we check if we're on Solaris, because Solaris doesn't like "uname -o"
if [[ "$(uname)" != "SunOS" ]]; then
  if [[ "$(uname -o)" = "Cygwin" ]]; then
    myx() {
      a=/tmp/.X11-unix/X
      #for ((i=351;i<500;i++)) ; do #breaks older versions of bash, hence the next while loop
      i=351
      while [[ "${i}" -lt 500 ]]; do
        b=$a$i
        if [[ ! -S $b ]] ; then
          c=$i
          break
        fi
      i++
      done
      export DISPLAY=:$c
      echo export DISPLAY=:$c
      X :$c -multiwindow >& /dev/null &
      xterm -fn 9x15bold -bg black -fg orange -sb &
    }
  fi
fi

# Provide a faster-than-scp file transfer function
# From http://intermediatesql.com/linux/scrap-the-scp-how-to-copy-data-fast-using-pigz-and-nc/
ncp() {
  FileFull=$1
  RemoteHost=$2

  FileDir=$(dirname "${FileFull}")
  FileName=$(basename "${FileFull}")
  LocalHost=$(hostname)

  ZipTool=pigz
  NCPort=8888

  tar -cf - -C "${FileDir} ${FileName}" | pv -s "$(du -sb "${FileFull}" | awk '{s += $1} END {printf "%d", s}')" | "${ZipTool}" | nc -l "${NCPort}" &
  ssh "${RemoteHost}" "nc ${LocalHost} ${NCPort} | ${ZipTool} -d | tar xf - -C ${FileDir}"
}

# Backup a file with the extension '.old'
old() { 
  cp --reflink=auto "$1"{,.old} 2>/dev/null || cp "$1"{,.old}
}

# A function to print a specific line from a file
printline() {
  # If $1 is empty, print a usage message
  if [[ -z $1 ]]; then
    printf '%s\n' "Usage:  printline n [file]" ""
    printf "\t%s\n" "Print the Nth line of FILE." "" \
      "With no FILE or when FILE is -, read standard input instead."
    return 0
  fi

  # Check that $1 is a number, if it isn't print an error message
  # If it is, blindly convert it to base10 to remove any leading zeroes
  case $1 in
    ''|*[!0-9]*)  printf '%s\n' "[ERROR] printline: '$1' does not appear to be a number." "" \
                    "Run 'printline' with no arguments for usage.";
                  return 1 ;;
    *)            local lineNo="$((10#$1))" ;;
  esac

  # Next, if $2 is set, check that we can actually read it
  if [[ -n "$2" ]]; then
    if [[ ! -r "$2" ]]; then
      printf '%s\n' "[ERROR] printline: '$2' does not appear to exist or I can't read it." "" \
        "Run 'printline' with no arguments for usage."
      return 1
    else
      local file="$2"
    fi
  fi

  # Finally after all that testing is done, we throw in a cursory test for 'sed'
  if command -v sed &>/dev/null; then
    sed -ne "${lineNo}{p;q;}" -e "\$s/.*/[ERROR] printline: End of stream reached./" -e '$ w /dev/stderr' "${file:-/dev/stdin}"
  # Otherwise we print a message that 'sed' isn't available
  else
    printf '%s\n' "[ERROR] printline: This function depends on 'sed' which was not found."
    return 1
  fi
}

# Start an HTTP server from a directory, optionally specifying the port
quickserve() {
  local port="${1:-8000}"
  sleep 1 && open "http://localhost:${port}/" &
  # Set the default Content-Type to `text/plain` instead of `application/octet-stream`
  # And serve everything as UTF-8 (although not technically correct, this doesn.t break anything for binary files)
  python -m "SimpleHTTPServer" "$port"
}

# Check if 'rev' is available, if not, enable a stop-gap function
if ! command -v rev &>/dev/null; then
  rev() {
    # Check that stdin or $1 isn't empty
    if [[ -t 0 ]] && [[ -z $1 ]]; then
      printf '%s\n' "Usage:  rev string|file" ""
      printf "\t%s\n"  "Reverse the order of characters in STRING or FILE." "" \
        "With no STRING or FILE, read standard input instead." "" \
        "Note: This is a bash function to provide the basic functionality of the command 'rev'"
      return 0
    # Disallow both piping in strings and declaring strings
    elif [[ ! -t 0 ]] && [[ ! -z $1 ]]; then
      printf '%s\n' "[ERROR] rev: Please select either piping in or declaring a string to reverse, not both."
      return 1
    fi

    # If parameter is a file, or stdin in used, action that first
    if [[ -f $1 ]]||[[ ! -t 0 ]]; then
      while read -r Line; do
        len=${#Line}
        rev=
        for((i=len-1;i>=0;i--)); do
          rev="$rev${Line:$i:1}"
        done
        printf '%s\n' "${rev}"
      done < "${1:-/dev/stdin}"
    # Else, if parameter exists, action that
    elif [[ ! -z "$@" ]]; then
      Line=$*
      rev=
      len=${#Line}
      for((i=len-1;i>=0;i--)); do 
        rev="$rev${Line:$i:1}"
      done
      printf '%s\n' "${rev}"
    fi
  }
fi

# A function to repeat an action any number of times
repeat() {
  # check that $1 is a digit, if not error out, if so, set the repeatNum variable
  case "$1" in
    (*[!0-9]*|'') printf '%s\n' "[ERROR]: '$1' is not a number.  Usage: 'repeat n command'"; return 1;;
    (*)           local repeatNum=$1;;
  esac
  # shift so that the rest of the line is the command to execute
  shift

  # Run the command in a while loop repeatNum times
  while [ $(( repeatNum -= 1 )) -ge 0 ]; do
    "$@"
  done
}

# Create the file structure for an Ansible role
rolesetup() {
  if [[ -z "$1" ]]; then
    printf '%s\n' "rolesetup - setup the file structure for an Ansible role." \
      "By default this creates into the current directory" \
      "and you can recursively copy the structure from there." "" \
      "Usage: rolesetup rolename" ""
    return 1
  fi

  if [[ ! -w . ]]; then
    printf '%s\n' "Unable to write to the current directory"
    return 1
  elif [[ -d "$1" ]]; then
    printf '%s\n' "The directory '$1' seems to already exist!"
    return 1
  else
    mkdir -p "$1"/{defaults,files,handlers,meta,templates,tasks,vars}
    printf '%s\n' "---" > "$1"/{defaults,files,handlers,meta,templates,tasks,vars}/main.yml
  fi
}

# Check if 'seq' is available, if not, provide a basic replacement function
if ! command -v seq &>/dev/null; then
  seq() {
    # If no parameters are given, print out usage
    if [[ -z "$@" ]]; then
      printf '%s\n' "Usage: seq x [y]"
      return 0
    fi
    
    # If only one number is given, we assume 1..n
    if [[ -z $2 ]]; then
      for ((i=1; i<=$1; i++))
        do printf '%s\n' "$i"
      done
      
    # If two numbers are given in ascending order, we print ascending
    elif [[ $1 -lt $2 ]]; then
      for ((i=$1; i<=$2; i++))
        do printf '%s\n' "$i"
      done
      
    # Otherwise, we assume descending order
    else
      for ((i=$1; i>=$2; i--))
        do printf '%s\n' "$i"
      done
    fi
  }
fi

# Check if 'shuf' is available, if not, provide basic shuffle functionality
if ! command -v shuf &>/dev/null; then
  shuf() {
    local OPTIND

    # Handle the input, checking that stdin or $1 isn't empty
    if [[ -t 0 ]] && [[ -z $1 ]]; then
      printf '%s\n' "Usage:  shuf string|file" ""
      printf '\t%s\n'  "Write a random permutation of the input lines to standard output." "" \
        "With no FILE, or when FILE is -, read standard input." "" \
        "Note: This is a bash function to provide the basic functionality of the command 'shuf'"
      return 0
    # Disallow both piping in strings and declaring strings
    elif [[ ! -t 0 ]] && [[ ! -z $1 ]]; then
      printf '%s\n' "[ERROR] shuf: Please select either piping in or declaring a filename to shuffle, not both."
      return 1
    fi

    # Check that we have the prerequisite 'rand' command
    if ! command -v rand &>/dev/null; then
      printf '%s\n' "[ERROR] shuf: The command 'rand' is required but was not found."
      return 1
    fi

    # Default the command variable for when '-n' is not used
    # I don't like using a nested function, but this is required for older bash versions
    headOut() { cat -; }

    while getopts ":ei:hn:v" Flags; do
      case "${Flags}" in
        (e) shift "$(( OPTIND - 1 ))";
            for randInt in $(rand -M "${#@}" -N "${numCount:-${#@}}"); do
              printf '%s\n' "${@[randInt]}"
            done
            return 0;;
        (h)  printf '%s\n' "" "shuf - generate random permutations" \
               "" "Options:" \
               "  -e, echo.                Treat each ARG as an input line" \
               "  -h, help.                Print a summary of the options" \
               "  -i, input-range LO-HI.   Treat each number LO through HI as an input line" \
               "  -n, count.               Output at most n lines" \
               "  -v, version.             Print the version information" ""
             return 0;;
        (i) rand -m "${OPTARG%-*}" -M "${OPTARG##*-}" -N "${numCount:-${OPTARG##*-}}"
            return 0;;
        (n)  local numCount="${OPTARG}";
             headOut() { head -n "${numCount}"; }
             ;;
        (v)  printf '%s\n' "shuf.  This is a bashrc function knockoff that steps in if the real 'shuf' is not found."
             return 0;;
        (\?)  printf '%s\n' "shuf: invalid option -- '-$OPTARG'." \
                "Try -h for usage or -v for version info." >&2
              return 1;;
        (:)  printf '%s\n' "shuf: option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
             return 1;;
      esac
    done

    # If parameter is a file, suck it into an array, generate a permutated
    # array of random numbers of equal size, and then output
    # Check commit history for a range of alternative methods - ruby, perl, python etc
    if [[ -f $1 ]]; then
      # mapfile is bash-4, but I have a mapfile step-in function on the way too!
      mapfile -t shufArray < "$1"
      mapfile -t numArray < <(rand -M "${numCount:-${#shufArray[@]}}" -N "${numCount:-${#shufArray[@]}}")

      # Now go through numArray and print the matching elements from shufArray
      for randInt in "${numArray[@]}"; do
        randInt=$(( randInt - 1 )) # Adjust for arrays being 0th'd
        printf -- '%s\n' "${shufArray[randInt]}"
      done

    # Otherwise, if stdin is used, we use reservoir sampling
    elif [[ ! -t 0 ]]; then

      : #no-op for now.

    fi    
    
    # Don't let headOut go global
    unset headOut
  }
fi

# Silence ssh motd's etc using "-q"
# Adding "-o StrictHostKeyChecking=no" prevents key prompts
# and automatically adds them to ~/.ssh/known_hosts
ssh() {
  /usr/bin/ssh -o StrictHostKeyChecking=no -q "$@"
}

# Display the fingerprint for a host
ssh-fingerprint() {
  if [[ -z $1 ]]; then
    printf '%s\n' "Usage: ssh-fingerprint [hostname]"
    return 1
  fi

  fingerprint=$(mktemp)

  # Test if the local host supports ed25519
  # Older versions of ssh don't have '-Q' so also likely won't have ed25519
  # If you wanted a more portable test: 'man ssh | grep ed25519' might be it
  if ssh -Q key 2>/dev/null | grep -q ed25519; then
    ssh-keyscan -t ed25519,rsa,ecdsa "$1" > "${fingerprint}" 2> /dev/null
  else
    ssh-keyscan "$1" > "${fingerprint}" 2> /dev/null
  fi
  ssh-keygen -l -f "${fingerprint}"
  rm -f "${fingerprint}"
}

# Provide a very simple 'tac' step-in function
if ! command -v tac &>/dev/null; then
  tac() {
    if command -v perl &>/dev/null; then
      perl -e 'print reverse<>' < "${1:-/dev/stdin}"
    elif command -v awk &>/dev/null; then
      awk '{line[NR]=$0} END {for (i=NR; i>=1; i--) print line[i]}' < "${1:-/dev/stdin}"
    elif command -v sed &>/dev/null; then
      sed -e '1!G;h;$!d' < "${1:-/dev/stdin}"
    fi
  }
fi

# Throttle stdout
throttle() {
  # Check that stdin isn't empty
  if [[ -t 0 ]]; then
    printf '%s\n' "Usage:  pipe | to | throttle [n]" ""
    printf "\t%s\n"  "Increment line by line through the output of other commands" "" \
      "Delay between each increment can be defined.  Default is 1 second."
    return 0
  fi

  # Default the sleep time to 1 second
  if [[ -z $1 ]]; then
    Sleep=1
  else
    Sleep="$1"
    # We do another check for portability
    # (GNU sleep can handle fractional seconds, non-GNU cannot)
    if ! sleep "${Sleep}" &>/dev/null; then
      printf '%s\n' "[INFO] throttle: That time increment is not supported, defaulting to 1s"
      Sleep=1
    fi
  fi

  # Now we output line by line with a sleep in the middle
  while read -r Line; do
    printf '%s\n' "${Line}"
    sleep "${Sleep}"
  done
}

# Check if 'timeout' is available, if not, enable a stop-gap function
if ! command -v timeout &>/dev/null; then
  timeout() {

    # $# should be at least 1, if not, print a usage message
    if (($# == 0 )); then
      printf '%s\n' "Usage:  timeout DURATION COMMAND" ""
      printf "\t%s\n" "Start COMMAND, and kill it if still running after DURATION." "" \
        "DURATION is an integer with an optional  suffix:  's'  for" \
        "seconds (the default), 'm' for minutes, 'h' for hours or 'd' for days." "" \
        "Note: This is a bash function to provide the basic functionality of the command 'timeout'"
      return 0
    fi
    
    # Check that $1 complies, if not error out, if so, set the duration variable
    case "$1" in
      (*[!0-9smhd]*|'') printf '%s\n' "[ERROR] timeout: '$1' is not valid.  Run 'timeout' for usage."; return 1;;
      (*)           local duration=$1;;
    esac
    # shift so that the rest of the line is the command to execute
    shift

    # Convert timeout period into seconds
    # If it contains 'm', then convert to minutes
    if echo "${duration}" | grep "m" &>/dev/null; then
      # Make the variable numeric only
      duration="${duration//[!0-9]/}" 
      duration=$(( duration * 60 ))
      
    # ...and 'h' is for hours...
    elif echo "${duration}" | grep "h" &>/dev/null; then
      duration="${duration//[!0-9]/}" 
      duration=$(( duration * 60 * 60 ))
      
    # ...and 'd' is for days...
    elif echo "${duration}" | grep "d" &>/dev/null; then
      duration="${duration//[!0-9]/}" 
      duration=$(( duration * 60 * 60 * 24 ))
      
    # Otherwise, sanitise the variable of any other non-numeric characters
    else
      duration="${duration//[!0-9]/}"
    fi

    # If 'perl' is available, it has a few pretty good one-line options
    # see: http://stackoverflow.com/questions/601543/command-line-command-to-auto-kill-a-command-after-a-certain-amount-of-time
    if command -v perl &>/dev/null; then
      perl -e '$s = shift; $SIG{ALRM} = sub { kill INT => $p; exit 77 }; exec(@ARGV) unless $p = fork; alarm $s; waitpid $p, 0; exit ($? >> 8)' "${duration}" "$@"
      #perl -MPOSIX -e '$SIG{ALRM} = sub { kill(SIGTERM, -$$); }; alarm shift; $exit = system @ARGV; exit(WIFEXITED($exit) ? WEXITSTATUS($exit) : WTERMSIG($exit));' "$@"

    # Otherwise we offer a shell based failover.
    # I tested a few, this one works nicely and is fairly simple
    # http://stackoverflow.com/questions/24412721/elegant-solution-to-implement-timeout-for-bash-commands-and-functions/24413646?noredirect=1#24413646
    else
      # Run in a subshell to avoid job control messages
      ( "$@" &
        child=$! # Grab the PID of the COMMAND
        
        # Avoid default notification in non-interactive shell for SIGTERM
        trap -- "" SIGTERM
        ( sleep "${duration}"
          kill "${child}" 
        ) 2> /dev/null &
        
        wait "${child}"
      )
    fi
  }
fi

# Functions to quickly upper or lowercase some input
tolower() {
  if command -v awk >/dev/null 2>&1; then
    awk '{print tolower($0)}'
  elif command -v tr >/dev/null 2>&1; then
    tr '[:upper:]' '[:lower:]'
  else
    printf '%s\n' "tolower - no available method found" >&2
    return 1
  fi < "${1:-/dev/stdin}"
}

toupper() {
  if command -v awk >/dev/null 2>&1; then
    awk '{print toupper($0)}'
  elif command -v tr >/dev/null 2>&1; then
    tr '[:lower:]' '[:upper:]'
  else
    printf '%s\n' "toupper - no available method found" >&2
    return 1
  fi < "${1:-/dev/stdin}"
}

# Add -p option to 'touch' to combine 'mkdir -p' and 'touch'
# The trick here is that we use 'command' to launch 'touch',
# as it overrides the shell's lookup order.. essentially speaking.
touch() {
  # Check if '-p' is present.
  # For bash3+ you could use 'if [[ "$@" =~ -p ]];'
  if echo "$@" | grep "\\-p" >/dev/null 2>&1; then

    # Transfer everything to a local array
    local argArray=( "$@" )

    # We need to remove '-p' no matter where it is in the array
    # This means searching for it, unsetting it, and reindexing
    # Newer bash versions could use "${!argArray[@]}" style handling
    for (( index=0; index<"${#argArray[@]}"; index++ )); do
      if [[ "${argArray[index]}" = "-p" ]]; then
        unset -- argArray["${index}"]
        argArray=( "${argArray[@]}" )
      fi
    done

    # Next extract a list of directories to process
    local dirArray=( "$(printf '%s\n' "${argArray[@]}" | grep "/$")" )
    for file in $(printf '%s\n' "${argArray[@]}" | grep "/" | grep -v "/$"); do
      dirArray+=( "$(dirname "${file}")" )
    done

    # As before, we sanitise the array to prevent issues
    # In this case, 'mkdir -p "" '
    for (( index=0; index<"${#dirArray[@]}"; index++ )); do
      if [[ -z "${dirArray[index]}" ]]; then
        unset -- dirArray["${index}"]
        dirArray=( "${dirArray[@]}" )
      fi
    done   

    # Okay, first, let's deal with the directories
    if (( "${#dirArray[*]}" > 0 )); then
      mkdir -p "${dirArray[@]}"
    fi

    # Now we can just run 'touch' with the sanitised array
    command touch "${argArray[@]}"

  # If '-p' isn't present, just use 'touch' as normal
  else
    command touch "$@"
  fi
}

# A small function to trim whitespace either side of a (sub)string
trim() {
  awk '{$1=$1};1'
}

# Provide normal, no-options ssh for error checking
unssh() {
  /usr/bin/ssh "$@"
}

# Provide 'up', so instead of 'cd ../../../' you simply type 'up 3'
up() {
  if (( "$#" < 1 )); then
    cd ..
  else
    cdstr=""
    for ((i=0; i<$1; i++)); do
      cdstr="../${cdstr}"
    done
    cd "${cdstr}" || exit
  fi
}

# Check if 'watch' is available, if not, enable a stop-gap function
if ! command -v watch &>/dev/null; then
  watch() {
  # Set the default values for Sleep, Title and Command
  Sleep=2
  Title=true
  Command=
  local OPTIND

  while getopts ":hn:vt" Flags; do
    case "${Flags}" in
      (h)  printf '%s\n' "Usage:" " watch [-hntv] <command>" "" \
             "Options:" \
             "  -h, help.      Print a summary of the options" \
             "  -n, interval.  Seconds to wait between updates" \
             "  -v, version.   Print the version number" \
             "  -t, no title.  Turns off showing the header"
           return 0;;
      (n)  Sleep="${OPTARG}";;
      (v)  printf '%s\n' "watch.  This is a bashrc function knockoff that steps in if the real watch is not found."
           return 0;;
      (t)  Title=false;;
      (\?)  printf '%s\n' "ERROR: This version of watch does not support '-$OPTARG'.  Try -h for usage or -v for version info." >&2
            return 1;;
      (:)  printf '%s\n' "ERROR: Option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
           return 1;;
    esac
  done

  shift $(( OPTIND -1 ))
  Command=$*

  if [[ -z "${Command}" ]]; then
    printf '%s\n' "ERROR: watch needs a command to watch.  Please try 'watch -h' for usage information."
    return 1
  fi

  while true; do
    clear
    if [[ "${Title}" = "true" ]]; then
      Date=$(date)
      let Col=$(tput cols)-${#Date}
      printf "%s%${Col}s" "Every ${Sleep}s: ${Command}" "${Date}"
      tput sgr0
      printf '%s\n' "" ""
    fi
    eval "${Command}"
    sleep "${Sleep}"
  done
  }
fi

# Get local weather and present it nicely
weather() {
  # We require 'curl' so check for it
  if ! command -v curl &>/dev/null; then
    printf '%s\n' "[ERROR] weather: This command requires 'curl', please install it."
    return 1
  fi

  # If no arg is given, default to Wellington NZ
  curl -m 10 "http://wttr.in/${*:-Wellington}" 2>/dev/null || printf '%s\n' "[ERROR] weather: Could not connect to weather service."
}

# Enable piping to Windows Clipboard from with PuTTY
# Uses modified PuTTY from http://ericmason.net/2010/04/putty-ssh-windows-clipboard-integration/
wclip() {
  echo -ne '\e''[5i'
  cat "$*"
  echo -ne '\e''[4i'
  echo "Copied to Windows clipboard" 1>&2
}

# Function to display a list of users and their memory and cpu usage
# Non-portable swap: for file in /proc/*/status ; do awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r
what() {
  # Start processing $1.  I initially tried coding this with getopts but it blew up
  if [[ "$1" = "-c" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | sort -k7 -rn
  elif [[ "$1" = "-m" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }' | sort -k4 -rn
  elif [[ -z "$1" ]]; then
    ps -eo pcpu,vsz,user | tail -n +2 | awk '{ cpu[$3]+=$1; vsz[$3]+=$2 } END { for (user in cpu) printf("%-10s - Memory: %10.1f KiB, CPU: %4.1f%\n", user, vsz[user]/1024, cpu[user]); }'
  else
    printf '%s\n' "what - list all users and their memory/cpu usage (think 'who' and 'what')" "Usage: what [-c (sort by cpu usage) -m (sort by memory usage)]"
  fi
}

# Function to get the owner of a file
whoowns() {
  # First we try GNU-style 'stat'
  if stat -c '%U' "$1" >/dev/null 2>&1; then
     stat -c '%U' "$1"
  # Next is BSD-style 'stat'
  elif stat -f '%Su' "$1" >/dev/null 2>&1; then
    stat -f '%Su' "$1"
  # Otherwise, we failover to 'ls', which is not usually desireable
  else
    ls -ld "$1" | awk 'NR==1 {print $3}'
  fi
}

################################################################################
# genpasswd password generator
################################################################################

# Password generator function for when pwgen or apg aren't available
genpasswd() {
  # Declare OPTIND as local for safety
  local OPTIND

  # Default the vars
  PwdChars=10
  PwdNum=1
  PwdSet="[:alnum:]"
  PwdCols=cat
  PwdKrypt="false"
  PwdKryptMode=1
  KryptMethod=
  ReqSet=
  PwdCheck="false"
  SpecialChar="false"
  InputChars=(\! \@ \# \$ \% \^ \( \) \_ \+ \? \> \< \~)

  while getopts ":Cc:Dhk:Ln:SsUY" Flags; do
    case "${Flags}" in
      (C)  if command -v column &>/dev/null; then
             PwdCols=column
           else
             printf '%s\n' "[ERROR] genpasswd: '-C' requires the 'column' command which was not found."
             return 1
           fi
           ;;
      (c)  PwdChars="${OPTARG}";;
      (D)  ReqSet="${ReqSet}[0-9]+"
           PwdCheck="true";;
      (h)  printf '%s\n' "" "genpasswd - a poor sysadmin's pwgen" \
             "" "Usage: genpasswd [options]" "" \
             "Optional arguments:" \
             "-C [Attempt to output into columns (Default:off)]" \
             "-c [Number of characters. Minimum is 4. (Default:${PwdChars})]" \
             "-D [Require at least one digit (Default:off)]" \
             "-h [Help]" \
             "-k [Krypt, generates a hashed password for tools like 'newusers', 'usermod -p' and 'chpasswd -e'." \
             "    Crypt method can be set using '-k 1' (MD5, default), '-k 5' (SHA256) or '-k 6' (SHA512)" \
             "    Any other arguments fed to '-k' will default to MD5.  (Default:off)]" \
             "-L [Require at least one lowercase character (Default:off)]" \
             "-n [Number of passwords (Default:${PwdNum})]" \
             "-s [Strong mode, seeds a limited amount of special characters into the mix (Default:off)]" \
             "-S [Stronger mode, complete mix of characters (Default:off)]" \
             "-U [Require at least one uppercase character (Default:off)]" \
             "-Y [Require at least one special character (Default:off)]" \
             "" "Note1: Broken Pipe errors, (older bash versions) can be ignored" \
             "Note2: If you get umlauts, cyrillic etc, export LC_ALL= to something like en_US.UTF-8"
           return 0;;
      (k)  PwdKrypt="true"
           PwdKryptMode="${OPTARG}";;
      (L)  ReqSet="${ReqSet}[a-z]+"
           PwdCheck="true";;
      (n)  PwdNum="${OPTARG}";;
      # Attempted to randomise special chars using 7 random chars from [:punct:] but reliably
      # got "reverse collating sequence order" errors.  Seeded 9 special chars manually instead.
      (s)  PwdSet="[:alnum:]#$&+/<}^%@";;
      (S)  PwdSet="[:graph:]";;
      (U)  ReqSet="${ReqSet}[A-Z]+"
           PwdCheck="true";;
      # If a special character is required, we feed in more special chars than in -s
      # This improves performance a bit by better guaranteeing seeding and matching
      (Y)  #ReqSet="${ReqSet}[#$&\+/<}^%?@!]+"
           SpecialChar="true"
           PwdCheck="true";;
      (\?)  printf '%s\n' "[ERROR] genpasswd: Invalid option: $OPTARG.  Try 'genpasswd -h' for usage." >&2
            return 1;;
      
      (:)  echo "[ERROR] genpasswd: Option '-$OPTARG' requires an argument, e.g. '-$OPTARG 5'." >&2
           return 1;;
    esac
  done

  # We need to check that the character length is more than 4 to protect against
  # infinite loops caused by the character checks.  i.e. 4 character checks on a 3 character password
  if [[ "${PwdChars}" -lt 4 ]]; then
    printf '%s\n' "[ERROR] genpasswd: Password length must be greater than four characters."
    return 1
  fi

  # Now generate the password(s)
  # Despite best efforts with the PwdSet's, spaces still crept in, so there's a cursory tr -d ' ' to kill those

  # If these two are false, there's no point doing further checks.  We just slam through
  # the absolute simplest bit of code in this function.  This is here for performance reasons.
  if [[ "${PwdKrypt}" = "false" && "${PwdCheck}" = "false" ]]; then
    tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -n "${PwdNum}" | "${PwdCols}" 2> /dev/null
    return 0
  fi

  # Let's start with checking for the Krypt option
  if [[ "${PwdKrypt}" = "true" ]]; then
    # Let's make sure we get the right number of passwords
    n=0
    while [[ "${n}" -lt "${PwdNum}" ]]; do
      # And let's get these variables figured out.  Needs to be inside the loop
      # to correctly pickup other arg values and to rotate properly
      Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -n 1) 2> /dev/null
      
      # Now we ensure that Pwd matches any character requirements
      if [[ "${PwdCheck}" = "true" ]]; then
        while ! printf '%s\n' "${Pwd}" | egrep "${ReqSet}" &> /dev/null; do
          Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -n 1 2> /dev/null)
        done
      fi

      # If -Y is set, we need to mix in a special character
      if [[ "${SpecialChar}" = "true" ]]; then
        PwdSeed="${InputChars[*]:$((RANDOM % ${#InputChars[@]})):1}"
        SeedLoc=$((RANDOM % ${#Pwd}))
        Pwd=$(printf '%s\n' "${Pwd:0:$(( ${#Pwd} - 1 ))}" | sed "s/^\(.\{$SeedLoc\}\)/\1${PwdSeed}/")
      fi

      # Feed the generated password to the cryptpasswd function
      cryptpasswd "${Pwd}" "${PwdKryptMode}"
      
      # And we tick the counter up by one increment
      ((n = n + 1))
    done
    return 0
  fi
  
  # Otherwise, let's just do plain old passwords.  This is considerably more straightforward
  # First, if the character check variable is true, then we go through that process
  if [[ "${PwdCheck}" = "true" ]]; then
      n=0
      while [[ "${n}" -lt "${PwdNum}" ]]; do
        Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -n 1 2> /dev/null)
        # Now we run through a loop that will grep out generated passwords that match
        # the required character classes.  For portability, we shunt the lot to /dev/null
        # Because Solaris egrep doesn't behave with -q or -s as it should.
        while ! printf '%s\n' "${Pwd}" | egrep "${ReqSet}" &> /dev/null; do
          Pwd=$(tr -dc "${PwdSet}" < /dev/urandom | tr -d ' ' | fold -w "${PwdChars}" | head -n 1 2> /dev/null)
        done
        # For each matched password, print it out, iterate and loop again.
        # But first we need to check if -Y is set, and if so, force in a random special character
        if [[ "${SpecialChar}" = "true" ]]; then
          # Select a random character from the array by selecting a random number
          # based on the array length, then selecting the appropriate element
          PwdSeed="${InputChars[*]:$((RANDOM % ${#InputChars[@]})):1}"
          # Choose a random location within the max password length in which to insert it
          SeedLoc=$((RANDOM % ${#Pwd}))
          # Print out the password with one less character, 
          # then use sed to insert the special character into the preselected place
          printf '%s\n' "${Pwd:0:$(( ${#Pwd} - 1 ))}" | sed "s/^\(.\{$SeedLoc\}\)/\1${PwdSeed}/"
        # If -Y isn't set, just print it out.  Easy!
        else
          printf '%s\n' "${Pwd}"
        fi
      ((n = n + 1))
      done | "${PwdCols}" 2>/dev/null
  fi
}
################################################################################

# A separate password encryption tool, so that you can encrypt passwords of your own choice
cryptpasswd() {
  # Declare OPTIND as local for safety
  local OPTIND

  # Default the vars
  Pwd="${1}"
  Salt=$(tr -dc '[:alnum:]' < /dev/urandom | tr '[:upper:]' '[:lower:]' | tr -d ' ' | fold -w 8 | head -n 1) 2> /dev/null
  PwdKryptMode="${2}"
  
  if [[ -z "${1}" ]]; then
    printf '%s\n' "" "cryptpasswd - a tool for hashing passwords" "" \
    "Usage: cryptpasswd [password to hash] [1|5|6]" \
    "    Crypt method can be set using '1' (MD5, default), '5' (SHA256) or '6' (SHA512)" \
    "    Any other arguments will default to MD5."
    return 0
  fi

  # We don't want to mess around with other options as it requires more error handling than I can be bothered with
  # If the crypt mode isn't 5 or 6, default it to 1, otherwise leave it be
  if [[ "${PwdKryptMode}" -ne 5 && "${PwdKryptMode}" -ne 6 ]]; then
    # Otherwise, default to MD5.
    PwdKryptMode=1
  fi

  # We check for python and if it's there, we use it
  if command -v python &>/dev/null; then
    PwdSalted=$(python -c "import crypt; print crypt.crypt('${Pwd}', '\$${PwdKryptMode}\$${Salt}')")
    # Alternative
    #python -c 'import crypt; print(crypt.crypt('${Pwd}', crypt.mksalt(crypt.METHOD_SHA512)))'
  # Next we failover to perl
  elif command -v perl &>/dev/null; then
    PwdSalted=$(perl -e "print crypt('${Pwd}','\$${PwdKryptMode}\$${Salt}\$')")
  # Otherwise, we failover to openssl
  # If command can't find it, we try to search some common Linux and Solaris paths for it
  elif ! command -v openssl &>/dev/null; then
    OpenSSL=$(command -v {,/usr/bin/,/usr/local/ssl/bin/,/opt/csw/bin/,/usr/sfw/bin/}openssl 2>/dev/null | head -n 1)
    # We can only generate an MD5 password using OpenSSL
    PwdSalted=$("${OpenSSL}" passwd -1 -salt "${Salt}" "${Pwd}")
    KryptMethod=OpenSSL
  fi

  # Now let's print out the result.  People can always awk/cut to get just the crypted password
  # This should probably be tee'd off to a dotfile so that they can get the original password too
  printf '%s\n' "Original: ${Pwd} Crypted: ${PwdSalted}"

  # In case OpenSSL is used, give an FYI before we exit out
  if [[ "${KryptMethod}" = "OpenSSL" ]]; then
    printf '%s\n' "Password encryption was handled by OpenSSL which is only MD5 capable."
  fi
}

################################################################################
# genphrase passphrase generator
################################################################################
# A passphrase generator, because: why not?
# Note: This will only generate XKCD "Correct Horse Battery Staple" level phrases, 
# which arguably aren't that secure without some character randomisation.
# See the Schneier Method alternative i.e. "This little piggy went to market" = "tlpWENT2m"
genphrase() {
  # Some examples of methods to do this (fastest to slowest):
  # shuf:         printf '%s\n' "$(shuf -n 3 ~/.pwords.dict | tr -d "\n")"
  # perl:         printf '%s\n' "perl -nle '$word = $_ if rand($.) < 1; END { print $word }' ~/.pwords.dict"
  # sed:          printf "$s\n" "sed -n $((RANDOM%$(wc -l < ~/.pwords.dict)+1))p ~/.pwords.dict"
  # python:       printf '%s\n' "$(python -c 'import random, sys; print("".join(random.sample(sys.stdin.readlines(), "${PphraseWords}")).rstrip("\n"))' < ~/.pwords.dict | tr -d "\n")"
  # oawk/nawk:    printf '%s\n' "$(for i in {1..3}; do sed -n "$(echo "$RANDOM" $(wc -l <~/.pwords.dict) | awk '{ printf("%.0f\n",(1.0 * $1/32768 * $2)+1) }')p" ~/.pwords.dict; done | tr -d "\n")"
  # gawk:         printf '%s\n' "$(awk 'BEGIN{ srand(systime() + PROCINFO["pid"]); } { printf( "%.5f %s\n", rand(), $0); }' ~/.pwords.dict | sort -k 1n,1 | sed 's/^[^ ]* //' | head -3 | tr -d "\n")"
  # sort -R:      printf '%s\n' "$(sort -R ~/.pwords.dict | head -3 | tr -d "\n")"
  # bash $RANDOM: printf '%s\n' "$(for i in $(<~/.pwords.dict); do echo "$RANDOM $i"; done | sort | cut -d' ' -f2 | head -3 | tr -d "\n")"

  # perl, sed, oawk/nawk and bash are the most portable options in order of speed.  The bash $RANDOM example is horribly slow, but reliable.  Avoid if possible.

  # First, double check that the dictionary file exists.
  if [[ ! -f ~/.pwords.dict ]] ; then
    # Test if we can download our wordlist, otherwise use the standard 'words' file to generate something usable
    if ! wget -T 2 https://raw.githubusercontent.com/rawiriblundell/dotfiles/master/.pwords.dict -O ~/.pwords.dict &>/dev/null; then
      # Alternatively, we could just use grep -v "[[:punct:]]", but we err on the side of portability
      grep -Eh '^.{3,9}$' /usr/{,share/}dict/words 2>/dev/null | grep -Ev "é|'|-|\.|/|&" > ~/.pwords.dict
    fi
  fi

  # Test we have the capitalise function available
  if ! type capitalise &>/dev/null; then
    printf '%s\n' "[ERROR] genphrase: 'capitalise' function is required but was not found." \
      "This function can be retrieved from https://github.com/rawiriblundell"
    return 1
  fi

  # localise our vars for safety
  local OPTIND  PphraseWords PphraseNum PphraseCols PphraseSeed PphraseSeedDoc SeedWord totalWords

  # Default the vars
  PphraseWords=3
  PphraseNum=1
  PphraseCols=cat
  PphraseSeed="False"
  PphraseSeedDoc="False"
  SeedWord=

  while getopts ":Chn:s:Sw:" Flags; do
    case "${Flags}" in
      (C)  if command -v column &>/dev/null; then
             PphraseCols=column
           else
             printf '%s\n' "[ERROR] genphrase: '-C' requires the 'column' command which was not found."
             return 1
           fi
           ;;
      (h)  printf '%s\n' "" "genphrase - a basic passphrase generator" \
             "" "Optional Arguments:" \
             "-C [attempt to output into columns (Default:off)]" \
             "-h [help]" \
             "-n [number of passphrases to generate (Default:${PphraseNum})]" \
             "-s [seed your own word.  Use 'genphrase -S' to read about this option.]" \
             "-S [explanation for the word seeding option: -s]" \
             "-w [number of random words to use (Default:${PphraseWords})]" ""
           return 0;;
      (n)  PphraseNum="${OPTARG}";;
      (s)  PphraseSeed="True"
           SeedWord="[${OPTARG}]";;
      (S)  PphraseSeedDoc="True";;
      (w)  PphraseWords="${OPTARG}";;
      (\?)  echo "ERROR: Invalid option: '-$OPTARG'.  Try 'genphrase -h' for usage." >&2
            return 1;;
      (:)  echo "Option '-$OPTARG' requires an argument. e.g. '-$OPTARG 10'" >&2
           return 1;;
    esac
  done
  
  # If -S is selected, print out the documentation for word seeding
  if [[ "${PphraseSeedDoc}" = "True" ]]; then
    printf '%s\n' \
    "======================================================================" \
    "genphrase and the -s option: Why you would want to seed your own word?" \
    "======================================================================" \
    "One method for effectively using passphrases is known as 'root and extension.'" \
    "This can be expressed in a few ways, but in this context, it's to choose" \
    "at least two random words (your 'root') and to seed those two words" \
    "with a task specific word (your 'extension')." "" \
    "So let's take two words:" \
    "---" "pings genre" "---" "" \
    "Now if we capitalise both words to get TitleCasing, we meet the usual"\
    "UPPER and lowercase password requirements, as well as very likely" \
    "meeting the password length requirement: 'PingsGenre'" ""\
    "So then we add a task specific word: Let's say this passphrase is for" \
    "your online banking, so we add the word 'bank' into the mix and get:" \
    "'PingsGenrebank'" "" \
    "For social networking, you might have 'PingsGenreFBook' and so on." \
    "The random words are the same, but the task-specific word is the key." \
    "" "Problem is, this arguably isn't good enough.  According to Bruce Schneier" \
    "CorrectHorseBatteryStaple is not that secure.  Others argue otherwise." \
    "See: https://goo.gl/ZGlkfm and http://goo.gl/kunYbu." "" \
    "So we need to randomise those words, introduce some special characters," \
    "and some numbers.  'PingsGenrebank' becomes 'Pings{B4nk}Genre'" \
    "and likewise 'PingsGenreFBook' becomes '(FB0ok)GenrePings'." \
    "" "So, this is a very easy to remember system which meets most usual" \
    "password requirements, and it makes most lame password checkers happy." \
    "You could also argue that this borders on multi-factor auth" \
    "i.e. something you are/have/know = username/root/extension." \
    "" "genphrase will always put the seeded word in square brackets and if" \
    "possible it will randomise its location in the phrase, it's over to" \
    "you to make sure that your seeded word has numerals etc." "" \
    "Note: You can always use genphrase to generate the base phrase and" \
    "      then manually embellish it to your taste."
    return 0
  fi
  
  # Next test if a word is being seeded in
  if [[ "${PphraseSeed}" = "True" ]]; then
    # If so, make space for the seed word
    ((PphraseWords = PphraseWords - 1))
  fi

  # Calculate the total number of words we might process
  totalWords=$(( PphraseWords * PphraseNum ))
  
  # Now generate the passphrase(s)
  # First we test to see if shuf is available.  This should now work with the
  # 'shuf' step-in function and 'rand' scripts available from https://github.com/rawiriblundell
  # Also requires the 'capitalise' function from said source.
  if command -v shuf &>/dev/null; then
    # If we're using bash4, then use mapfile for safety
    if (( BASH_VERSINFO == 4 )); then
      # Basically we're using shuf and awk to generate lines of random words
      # and assigning each line to an array element
      mapfile -t wordArray < <(shuf -n "${totalWords}" ~/.pwords.dict | awk -v w="${PphraseWords}" 'ORS=NR%w?FS:RS')
    # This older method should be ok for this particular usage,
    # but otherwise is not a direct replacement for mapfile
    # See: http://mywiki.wooledge.org/BashFAQ/005#Loading_lines_from_a_file_or_stream
    else
      IFS=$'\n' read -d '' -r -a wordArray < <(shuf -n "${totalWords}" ~/.pwords.dict | awk -v w="${PphraseWords}" 'ORS=NR%w?FS:RS')
    fi

    # Iterate through each line of the array
    for line in "${wordArray[@]}"; do
      # Convert the line to an array of its own and add any seed word
      lineArray=( ${SeedWord} ${line} )
      if (( BASH_VERSINFO == 4 )); then
        shuf -e "${lineArray[@]^}"
      else
        shuf -e "${lineArray[@]}" | capitalise
      fi | paste -sd '\0'
    done | "${PphraseCols}"
    return 0 # Prevent subsequent run of bash
  
  # Otherwise, we switch to bash.  This is the fastest way I've found to perform this
  else
    if ! command -v rand &>/dev/null; then
      printf '%s\n' "[ERROR] genphrase: This function requires the 'rand' external script, which was not found." \
        "You can get this script from https://github.com/rawiriblundell"
      return 1
    fi

    # We test for 'mapfile' which indicates bash4 or some step-in function
    if command -v mapfile &>/dev/null; then
      # Create two arrays, one with all the words, and one with a bunch of random numbers
      mapfile -t dictArray < ~/.pwords.dict
      mapfile -t numArray < <(rand -M "${#dictArray[@]}" -r -N "${totalWords}")
    # Otherwise we take the classic approach
    else
      read -d '' -r -a dictArray < ~/.pwords.dict
      read -d '' -r -a numArray < <(rand -M "${#dictArray[@]}" -r -N "${totalWords}")
    fi

    # Setup the following vars for iterating through and slicing up 'numArray'
    loWord=0
    hiWord=$(( PphraseWords - 1 ))

    # Now start working our way through both arrays
    while (( hiWord <= totalWords )); do
      # Group all the following output
      {
        # We print out a random number with each word, this allows us to sort
        # all of the output, which randomises the location of any seed word
        printf '%s\n' "${RANDOM} ${SeedWord}"
        for randInt in "${numArray[@]:loWord:PphraseWords}"; do
          if (( BASH_VERSINFO == 4 )); then
            printf '%s\n' "${RANDOM} ${dictArray[randInt]^}"
          else
            printf '%s\n' "${RANDOM} ${dictArray[randInt]}" | capitalise
          fi
        done
      # Pass the grouped output for some cleanup
      } | sort | awk '{print $2}' | paste -sd '\0'
      # Iterate our boundary vars up and loop again until completion
      loWord=$(( hiWord + 1 ))
      hiWord=$(( hiWord + PphraseWords ))
    done | "${PphraseCols}"
  fi
}

# Password strength check function.  Can be fed a password most ways.
# TO-DO: add a verbose output switch
pwcheck () {
  # Read password in, if it's blank, prompt the user
  if [[ "${*}" = "" ]]; then
    read -resp $'Please enter the password/phrase you would like checked:\n' PwdIn
  else
    # Otherwise, whatever is fed in is the password to check
    PwdIn="${*}"
  fi

  # Check password, attempt with cracklib-check, failover to something a little more exhaustive
  if [[ -f /usr/sbin/cracklib-check ]]; then
    Method="cracklib-check"
    Result="$(echo "${PwdIn}" | /usr/sbin/cracklib-check)"
    Okay="$(awk -F': ' '{print $2}' <<<"${Result}")"
  else  
    # I think we have a common theme here.  Writing portable code sucks, but it keeps things interesting.
    
    Method="pwcheck"
    # Force 3 of the following complexity categories:  Uppercase, Lowercase, Numeric, Symbols, No spaces, No dicts
    # Start by giving a credential score to be subtracted from, then default the initial vars
    CredCount=4
    PWCheck="true"
    ResultChar="[OK]: Character count"
    ResultDigit="[OK]: Digit count"
    ResultUpper="[OK]: UPPERCASE count"
    ResultLower="[OK]: lowercase count"
    ResultPunct="[OK]: Special character count"
    ResultSpace="[OK]: No spaces found"
    ResultDict="[OK]: Doesn't seem to match any dictionary words"

    while [[ "${PWCheck}" = "true" ]]; do
      # Start cycling through each complexity requirement
      # We instantly fail for short passwords
      if [[ "${#PwdIn}" -lt "8" ]]; then
        printf '%s\n' "pwcheck: Password must have a minimum of 8 characters.  Further testing stopped.  (Score = 0)"
        return 1
      # And we instantly fail for passwords with spaces in them
      elif [[ "${PwdIn}" == *[[:blank:]]* ]]; then
        printf '%s\n' "pwcheck: Password cannot contain spaces.  Further testing stopped.  (Score = 0)"
        return 1
      fi
      # Check against the dictionary
      if grep -qh "${PwdIn}" /usr/{,share/}dict/words 2>/dev/null; then
        ResultDict="${PwdIn}: Password cannot contain a dictionary word.  (Score = 0)"
        CredCount=0 # Punish hard for dictionary words
      fi
      # Check for a digit
      if [[ ! "${PwdIn}" == *[[:digit:]]* ]]; then
        ResultDigit="[FAIL]: Password should contain at least one digit.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      # Check for UPPERCASE
      if [[ ! "${PwdIn}" == *[[:upper:]]* ]]; then
        ResultUpper="[FAIL]: Password should contain at least one uppercase letter.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      # Check for lowercase
      if [[ ! "${PwdIn}" == *[[:lower:]]* ]]; then
        ResultLower="[FAIL]: Password should contain at least one lowercase letter.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      # Check for special characters
      if [[ ! "${PwdIn}" == *[[:punct:]]* ]]; then
        ResultPunct="[FAIL]: Password should contain at least one special character.  (Score -1)"
        ((CredCount = CredCount - 1))
      fi
      Result="$(printf '%s\n' "pwcheck: A score of 3 is required to pass testing, '${PwdIn}' scored ${CredCount}." \
        "${ResultChar}" "${ResultSpace}" "${ResultDict}" "${ResultDigit}" "${ResultUpper}" "${ResultLower}" "${ResultPunct}")"
      PWCheck="false" #Exit condition for the loop
    done

    # Now check password score, if it's less than three, then it fails
    # Here is where we force the three complexity catergories
    if [[ "${CredCount}" -lt "3" ]]; then
      # Rejected password, set variables appropriately
      Okay="NotOK"
    # Otherwise, it's a valid password
    else
      Okay="OK"
    fi
  fi

  # Output result
  if [[ "${Okay}" == "OK" ]]; then
    printf '%s\n' "pwcheck: The password/phrase passed my testing."
    return 0
  else
    printf '%s\n' "pwcheck: The check failed for password '${PwdIn}' using the ${Method} test." "${Result}" "Please try again."
    return 1
  fi
}

################################################################################
# Standardise the Command Prompt
# First, let's map some colours, uncomment to use:
#txtblk='\e[0;30m\]' # Black - Regular
#txtred='\e[0;31m\]' # Red
txtgrn='\e[0;32m\]' # Green
#txtylw='\e[0;33m\]' # Yellow
#txtblu='\e[0;34m\]' # Blue
#txtpur='\e[0;35m\]' # Purple
#txtcyn='\e[0;36m\]' # Cyan
#txtwht='\e[0;37m\]' # White
#bldblk='\e[1;30m\]' # Black - Bold
bldred='\e[1;31m\]' # Red
#bldgrn='\e[1;32m\]' # Green
bldylw='\e[1;33m\]' # Yellow
#bldblu='\e[1;34m\]' # Blue
#bldpur='\e[1;35m\]' # Purple
#bldcyn='\e[1;36m\]' # Cyan
#bldwht='\e[1;37m\]' # White
#unkblk='\e[4;30m\]' # Black - Underline
#undred='\e[4;31m\]' # Red
#undgrn='\e[4;32m\]' # Green
#undylw='\e[4;33m\]' # Yellow
#undblu='\e[4;34m\]' # Blue
#undpur='\e[4;35m\]' # Purple
#undcyn='\e[4;36m\]' # Cyan
#undwht='\e[4;37m\]' # White
#bakblk='\e[40m\]'   # Black - Background
#bakred='\e[41m\]'   # Red
#bakgrn='\e[42m\]'   # Green
#bakylw='\e[43m\]'   # Yellow
#bakblu='\e[44m\]'   # Blue
#bakpur='\e[45m\]'   # Purple
#bakcyn='\e[46m\]'   # Cyan
#bakwht='\e[47m\]'   # White
txtrst='\e[0m\]'    # Text Reset

# NOTE for customisation: Any non-printing escape characters must be enclosed, otherwise bash will miscount
# and get confused about where the prompt starts.  All sorts of line wrapping weirdness and prompt overwrites
# will then occur.  This is why all of the variables have '\]' enclosing them.  Don't mess with that.
# 
# Bad:    \\[\e[0m\e[1;31m[\$(date +%y%m%d/%H:%M)]\[\e[0m
# Better:  \\[\e[0m\]\e[1;31m\][\$(date +%y%m%d/%H:%M)]\[\e[0m\]

# The double backslash at the start also helps with this behaviour.

# Try to find out if we're authenticating locally or remotely
if grep "^${USER}:" /etc/passwd &>/dev/null; then
  auth="LCL"
else
  auth="AD"
fi

# Throw it all together, starting with checking if we're root
# Previously this tried to failover to a tput based alternative but it didn't work well on Solaris...
if [[ -w / ]]; then
  export PS1="\\[${bldred}[\$(date +%y%m%d/%H:%M)][${auth}]\[${bldylw}[\u@\h\[${txtrst} \W\[${bldylw}]\[${txtrst}$ "
# Otherwise show the usual prompt
else
  export PS1="\\[${bldred}[\$(date +%y%m%d/%H:%M)][${auth}]\[${txtgrn}[\u@\h\[${txtrst} \W\[${txtgrn}]\[${txtrst}$ "
fi

# Alias the root PS1 into sudo for edge cases
alias sudo="PS1='\\[${bldred}[\$(date +%y%m%d/%H:%M)][$auth]\[${bldylw}[\u@\h\[${txtrst} \W\[${bldylw}]\[${txtrst}$ ' sudo"

# Useful for debugging
export PS4='+$BASH_SOURCE:$LINENO:${FUNCNAME:-}: '
