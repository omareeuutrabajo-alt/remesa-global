#!/usr/bin/env bash
# Levanta un Postgres local para desarrollo y crea la base `remesas`.
# Alternativa recomendada si tienes Docker:
#   docker run -d --name remesas-pg -e POSTGRES_PASSWORD=postgres \
#     -e POSTGRES_DB=remesas -p 5432:5432 postgres:16
set -e
VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1)
BIN="/usr/lib/postgresql/$VER/bin"
DATA="${PGDATA:-/var/tmp/pgdata}"

if [ ! -d "$DATA" ]; then
  echo "▸ Inicializando cluster en $DATA"
  "$BIN/initdb" -D "$DATA" -U postgres --auth=trust >/dev/null
fi

"$BIN/pg_ctl" -D "$DATA" -o "-p 5432 -k /var/tmp -c listen_addresses=127.0.0.1" -l /var/tmp/pg.log start || true
sleep 2
"$BIN/psql" -h 127.0.0.1 -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='remesas'" | grep -q 1 \
  || "$BIN/createdb" -h 127.0.0.1 -U postgres remesas
echo "✔ Postgres listo → postgresql://postgres:postgres@127.0.0.1:5432/remesas"
