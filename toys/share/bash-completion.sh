if [[ $# -eq 0 ]]; then
  set -- "toys"
fi
for arg in "$@"; do
  complete -C "toys system bash-completion eval 2>/dev/null" -o nospace "$arg"
done
