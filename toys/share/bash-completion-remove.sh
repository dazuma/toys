if [[ $# -eq 0 ]]; then
  set -- "toys"
fi
for arg in "$@"; do
  complete -r "$arg"
done
