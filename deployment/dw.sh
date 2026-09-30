#!/usr/bin/env bash
# Private provisioner CLI. Publishing an empty database runs the copied
# PostDeployment script, which seeds dimensions and source data, then runs ETL.
set -euo pipefail
set +H 2>/dev/null || true
export PATH="/usr/bin:/bin:$PATH"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$HERE/../RetailDW/RetailDW.sqlproj"
DACPAC="$HERE/../RetailDW/bin/Debug/RetailDW.dacpac"
SERVER="127.0.0.1,14331"
DB="RetailDW_WorkshopNext"

if [[ ! -f "$HERE/.env" ]]; then
  umask 077
  printf 'MSSQL_SA_PASSWORD=Wk_Aa1!%s\n' "$(openssl rand -hex 24)" > "$HERE/.env"
fi
set -a
source "$HERE/.env"
set +a
: "${MSSQL_SA_PASSWORD:?Missing MSSQL_SA_PASSWORD}"

winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

case "${1:-}" in
  setup)
    "$0" up
    ready=0
    for _ in {1..30}; do
      if sqlcmd -S "$SERVER" -U sa -P "$MSSQL_SA_PASSWORD" -C -l 3 -d master -Q "SELECT 1" >/dev/null 2>&1; then
        ready=1
        break
      fi
      sleep 3
    done
    [[ $ready -eq 1 ]] || { echo "SQL Server is not ready." >&2; exit 1; }
    "$0" build
    "$0" publish
    ;;
  up)
    docker compose --env-file "$(winpath "$HERE/.env")" -f "$(winpath "$HERE/docker-compose.yml")" up -d
    ;;
  build)
    dotnet build "$(winpath "$PROJECT")"
    ;;
  publish)
    [[ -f "$DACPAC" ]] || { echo "Build the DACPAC first." >&2; exit 1; }
    MSYS_NO_PATHCONV=1 sqlpackage \
      /Action:Publish \
      /SourceFile:"$(winpath "$DACPAC")" \
      /TargetServerName:"$SERVER" \
      /TargetDatabaseName:"$DB" \
      /TargetUser:sa \
      /TargetPassword:"$MSSQL_SA_PASSWORD" \
      /TargetEncryptConnection:False \
      /TargetTrustServerCertificate:True \
      /p:DropObjectsNotInSource=False
    ;;
  sql)
    [[ $# -eq 2 ]] || { echo 'Usage: dw.sh sql "<query>"' >&2; exit 1; }
    sqlcmd -S "$SERVER" -U sa -P "$MSSQL_SA_PASSWORD" -C -b -d "$DB" -Q "$2"
    ;;
  *)
    echo "Usage: dw.sh {setup|up|build|publish|sql \"<query>\"}" >&2
    exit 1
    ;;
esac
