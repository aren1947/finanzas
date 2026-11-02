#!/usr/bin/env bash
# Corre cada tests/casos/*.sql en una base nueva armada con el repo, contra un Postgres 17 LOCAL.
# Uso: PGHOST=/tmp PGPORT=55432 PGUSER=postgres tests/correr.sh [filtro]
# Un caso pasa si psql termina sin error (los casos usan assert). Los que figuran en
# tests/fallas_conocidas.txt documentan bugs abiertos: se espera que fallen hasta que se arreglen.
set -uo pipefail
cd "$(dirname "$0")/.."
DB=finanzas_test
conocidas=$(grep -v '^#' tests/fallas_conocidas.txt 2>/dev/null | awk '{print $1}')
armar() {
  psql -q -X -d postgres -c "drop database if exists $DB" -c "create database $DB" >/dev/null || return 1
  {
    echo '\set ON_ERROR_STOP 1'
    cat tests/supabase_stub.sql
    cat esquema/0[0-6]*.sql
    for f in etl/*.sql; do
      destino=$(sed -n '1s/^-- \([a-z_]*\):.*/\1/p' "$f")
      printf "insert into _etl_pasos (archivo, destino, sql) values (%s, %s, %s);\n" \
        "\$q\$$(basename "$f")\$q\$" "\$q\$$destino\$q\$" "\$etl\$$(sed 's/;[[:space:]]*$//' "$f")\$etl\$"
    done
    cat vistas/*.sql procedimientos/*.sql
    cat tests/semilla.sql
    cat esquema/070_acceso.sql
  } | psql -q -X -d "$DB" >/dev/null
}
ok=0; mal=0
for caso in tests/casos/*${1:-}*.sql; do
  nombre=$(basename "$caso" .sql)
  armar || { echo "no se pudo armar la base"; exit 2; }
  if salida=$(psql -q -X -v ON_ERROR_STOP=1 -d "$DB" -f "$caso" 2>&1); then r=pasa; else r=falla; fi
  if grep -qx "$nombre" <<<"$conocidas"; then
    if [ $r = falla ]; then echo "  falla conocida  $nombre"; else echo "¡ARREGLADO?!    $nombre (sacalo de fallas_conocidas.txt)"; mal=$((mal+1)); fi
  elif [ $r = pasa ]; then echo "  ok              $nombre"; ok=$((ok+1))
  else echo "  FALLA           $nombre"; echo "$salida" | grep -E 'ERROR|assert|DETAIL' | head -3 | sed 's/^/                  /'; mal=$((mal+1)); fi
done
echo "$ok ok, $mal inesperados"
[ $mal -eq 0 ]
