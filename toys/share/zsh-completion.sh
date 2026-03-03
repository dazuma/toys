_toys_completion() {
  local -a finals=() partials=()
  local line in_partials=0

  while IFS= read -r line; do
    if [[ "$line" == '--' ]]; then
      in_partials=1
    elif (( in_partials )); then
      [[ -n "$line" ]] && partials+=("$line")
    else
      [[ -n "$line" ]] && finals+=("$line")
    fi
  done < <(COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" \
           toys system zsh-completion eval 2>/dev/null)

  (( ${#finals[@]} ))   && compadd -U    -- "${finals[@]}"
  (( ${#partials[@]} )) && compadd -U -S '' -- "${partials[@]}"
}

if [[ $# -eq 0 ]]; then
  set -- "toys"
fi
for arg in "$@"; do
  compdef _toys_completion "$arg"
done
