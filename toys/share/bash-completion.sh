if [[ $# -eq 0 ]]; then
  set -- "toys"
fi
for arg in "$@"; do
  complete -C "toys system bash-completion eval" -o nospace "$arg"
done
