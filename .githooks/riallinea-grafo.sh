#!/bin/sh
# Lanciato in background da post-commit: `graphify update .` e, se il grafo e'
# cambiato, un commit di sola graphify-out/. Un giro alla volta per repo: i
# commit arrivati nel frattempo fanno ripartire il giro alla fine.
# Log: $TMPDIR/graphify-riallinea-<id>.log

# git passa ai hook il proprio indice temporaneo, che sparisce a commit finito
unset GIT_INDEX_FILE GIT_DIR GIT_WORK_TREE GIT_PREFIX
radice="$1"
cd "$radice" || exit 0
id=$(printf '%s' "$radice" | cksum | cut -d' ' -f1)
blocco="${TMPDIR:-/tmp}/graphify-riallinea-$id"
log="$blocco.log"

# un blocco piu' vecchio di 30 minuti viene da un giro morto a meta'
if [ -d "$blocco" ] && [ -n "$(find "$blocco" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
  rmdir "$blocco" 2>/dev/null
fi
if ! mkdir "$blocco" 2>/dev/null; then
  touch "$blocco.ancora"
  exit 0
fi

[ "$(wc -c < "$log" 2>/dev/null || echo 0)" -gt 1000000 ] && : > "$log"

{
  echo "== $(date '+%Y-%m-%d %H:%M:%S') $radice"
  while :; do
    rm -f "$blocco.ancora"
    graphify update .
    [ -f "$blocco.ancora" ] || break
  done
  git add -- graphify-out
  if git diff --cached --quiet -- graphify-out; then
    echo "grafo invariato, nessun commit"
  else
    n=0
    while [ -e "$(git rev-parse --git-path index.lock)" ] && [ "$n" -lt 60 ]; do
      sleep 2
      n=$((n + 1))
    done
    # con il percorso esplicito git committa solo graphify-out, anche se nello
    # stage c'e' altro lavoro in corso
    git commit -q -m "chore(graphify): grafo riallineato" -- graphify-out && echo "commit fatto"
  fi
} >> "$log" 2>&1

rmdir "$blocco" 2>/dev/null
# un commit arrivato proprio mentre si chiudeva il giro
[ -f "$blocco.ancora" ] && exec sh "$0" "$radice"
exit 0
