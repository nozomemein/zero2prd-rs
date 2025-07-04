#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v sqlx)" ]; then
  echo >&2 "Error: sqlx is not installed."
  echo >&2 "Use:"
  echo >&2 "    cargo install --version='~0.8' sqlx-cli \
--no-default-features --features rustls,postgres"
  echo >&2 "to install it."
  exit 1
fi

DB_PORT="${POSTGRES_PORT:-5432}"
SUPERUSE="${SUPERUSER:=postgres}"
SUPERUSER_PWD="${SUPERUSER_PWD:=password}"

APP_USER="${APP_USER:=app}"
APP_USER_PWD="${APP_USER_PWD:=secret}"
APP_DB_NAME="${APP_DB_NAME:=newsletter}"

# Initialize the database
if [[ -z "${SKIP_DOCKER}" ]]; then
  CONTAINER_NAME="zero2prd-rs-postgres"
  docker run \
    --env "POSTGRES_USER=${SUPERUSER}" \
    --env "POSTGRES_PASSWORD=${SUPERUSER_PWD}" \
    --env "POSTGRES_DB=${SUPERUSER}" \
    --env "POSTGRES_PORT=${DB_PORT}" \
    --health-cmd="pg_isready -U ${SUPERUSER} || exit 1" \
    --health-interval=1s \
    --health-timeout=5s \
    --health-retries=5 \
    --name "${CONTAINER_NAME}" \
    -p "${DB_PORT}:${DB_PORT}" \
    -d \
    postgres -N 1000 # Increase the maximum number of connections for test cases


  until [ "$(docker inspect "${CONTAINER_NAME}" --format '{{.State.Health.Status}}')" == "healthy" ]; do
    >&2 echo "Waiting for database to be ready..."
    sleep 1
  done

  # Create the application user
  CREATE_QUERY="CREATE USER ${APP_USER} WITH PASSWORD '${APP_USER_PWD}';"
  docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -d "${SUPERUSER}" -c "${CREATE_QUERY}"

  # Grant create db privilages to the app user
  GRANT_QUERY="ALTER USER ${APP_USER} CREATEDB;"
  docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -d "${SUPERUSER}" -c "${GRANT_QUERY}"

  >&2 echo "Database is ready!"
fi

>&2 echo "Postgres is up and running on port ${DB_PORT}! - running migrations now..."


DATABASE_URL=postgres://${APP_USER}:${APP_USER_PWD}@localhost:${DB_PORT}/${APP_DB_NAME}
export DATABASE_URL
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go!"
