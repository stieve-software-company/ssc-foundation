#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"
readonly REPORT_FILE="${PROJECT_ROOT}/postgresql-audit.txt"

info() {
  printf '[INFO] %s\n' "$*"
}

ok() {
  printf '[OK] %s\n' "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

compose() {
  (
    cd "${PROJECT_ROOT}"

    local files=(
      -f "${BASE_COMPOSE}"
    )

    if [[ -s "${ACCESS_COMPOSE}" ]]; then
      files+=(
        -f "${ACCESS_COMPOSE}"
      )
    fi

    docker compose \
      --env-file "${ENV_FILE}" \
      "${files[@]}" \
      "$@"
  )
}

section() {
  printf '\n'
  printf '============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] \
    || fail "Arquivo ausente ou vazio: ${ENV_FILE}"

  [[ -s "${BASE_COMPOSE}" ]] \
    || fail "Arquivo ausente ou vazio: ${BASE_COMPOSE}"

  command -v docker >/dev/null 2>&1 \
    || fail "Docker não encontrado."

  command -v tee >/dev/null 2>&1 \
    || fail "Comando tee não encontrado."

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose config --quiet \
    || fail "Docker Compose integrado inválido."

  local container_id
  container_id="$(compose ps -q postgres)"

  [[ -n "${container_id}" ]] \
    || fail "Container PostgreSQL não encontrado."

  local state
  state="$(
    docker inspect \
      --format '{{.State.Status}}' \
      "${container_id}"
  )"

  [[ "${state}" == "running" ]] \
    || fail "PostgreSQL não está em execução: ${state}"
}

psql_exec() {
  local sql=$1

  printf '%s\n' "${sql}" |
    compose exec \
      -T \
      postgres \
      sh -ec '
        exec psql \
          -X \
          -v ON_ERROR_STOP=1 \
          -P pager=off \
          -P footer=off \
          -U "$POSTGRES_USER" \
          -d "$POSTGRES_DB"
      '
}

container_exec() {
  compose exec -T postgres "$@"
}

write_header() {
  printf 'SSC PostgreSQL Audit v2\n'
  printf 'generated_at=%s\n' "$(date --iso-8601=seconds)"
  printf 'project_root=%s\n' "${PROJECT_ROOT}"
  printf 'mode=read-only\n'
  printf 'audit_version=2\n'
  printf 'secrets_included=false\n'
}

audit_container() {
  section "CONTAINER E HEALTH"

  local container_id
  container_id="$(compose ps -q postgres)"

  printf 'container_id=%s\n' "${container_id:0:12}"

  docker inspect \
    --format \
    'image={{.Config.Image}}
state={{.State.Status}}
health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}
restart_count={{.RestartCount}}
container_user={{if .Config.User}}{{.Config.User}}{{else}}image-default{{end}}
read_only={{.HostConfig.ReadonlyRootfs}}
security_opt={{json .HostConfig.SecurityOpt}}
shm_size={{.HostConfig.ShmSize}}' \
    "${container_id}"

  printf '\nMounts:\n'
  docker inspect \
    --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}} rw={{.RW}}{{println}}{{end}}' \
    "${container_id}"

  printf '\nHealth probe:\n'
  container_exec \
    sh -ec '
      pg_isready \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB"
    '
}

audit_versions() {
  section "VERSÕES"

  container_exec postgres --version
  container_exec pg_dump --version
  container_exec pg_restore --version
  container_exec psql --version

  psql_exec "
    SELECT
      version() AS server_version,
      current_database() AS current_database,
      current_user AS current_user,
      session_user AS session_user;
  "
}

audit_application_connection() {
  section "CONEXÃO DO MISSION CONTROL — SANITIZADA"

  local mission_control_id
  mission_control_id="$(compose ps -q mission-control || true)"

  if [[ -z "${mission_control_id}" ]]; then
    printf 'mission_control=not-running\n'
    return
  fi

  compose exec \
    -T \
    mission-control \
    python - <<'PY'
from __future__ import annotations

import os
from urllib.parse import urlsplit


value = os.environ.get("DATABASE_URL", "")
parsed = urlsplit(value)

print("configured=" + ("true" if value else "false"))
print("scheme=" + (parsed.scheme or ""))
print("host=" + (parsed.hostname or ""))
print("port=" + (str(parsed.port) if parsed.port else ""))
print("database=" + parsed.path.lstrip("/"))
print("username=" + (parsed.username or ""))
print("password_present=" + ("true" if parsed.password else "false"))
PY
}

audit_cluster_settings() {
  section "CONFIGURAÇÃO DO CLUSTER"

  psql_exec "
    SELECT
      name,
      setting,
      unit,
      source,
      pending_restart
    FROM pg_settings
    WHERE name IN (
      'max_connections',
      'shared_buffers',
      'effective_cache_size',
      'work_mem',
      'maintenance_work_mem',
      'wal_level',
      'max_wal_size',
      'min_wal_size',
      'checkpoint_timeout',
      'checkpoint_completion_target',
      'max_worker_processes',
      'max_parallel_workers',
      'max_parallel_workers_per_gather',
      'autovacuum',
      'autovacuum_max_workers',
      'timezone',
      'log_timezone',
      'password_encryption',
      'ssl',
      'listen_addresses',
      'port',
      'data_directory',
      'hba_file',
      'ident_file',
      'config_file',
      'data_checksums'
    )
    ORDER BY name;
  "

  printf '\nShared preload libraries:\n'
  psql_exec "
    SELECT
      current_setting(
        'shared_preload_libraries',
        true
      ) AS shared_preload_libraries;
  "
}

audit_roles() {
  section "PAPÉIS"

  psql_exec "
    SELECT
      rolname,
      rolsuper,
      rolinherit,
      rolcreaterole,
      rolcreatedb,
      rolcanlogin,
      rolreplication,
      rolbypassrls,
      rolconnlimit,
      rolvaliduntil
    FROM pg_roles
    ORDER BY rolname;
  "

  printf '\nAssociações entre papéis:\n'
  psql_exec "
    SELECT
      parent.rolname AS granted_role,
      member.rolname AS member_role,
      grantor.rolname AS grantor,
      membership.admin_option,
      membership.inherit_option,
      membership.set_option
    FROM pg_auth_members AS membership
    JOIN pg_roles AS parent
      ON parent.oid = membership.roleid
    JOIN pg_roles AS member
      ON member.oid = membership.member
    JOIN pg_roles AS grantor
      ON grantor.oid = membership.grantor
    ORDER BY parent.rolname, member.rolname;
  "
}

audit_databases() {
  section "BANCOS"

  psql_exec "
    SELECT
      database.datname,
      owner.rolname AS owner,
      pg_encoding_to_char(
        database.encoding
      ) AS encoding,
      database.datcollate,
      database.datctype,
      database.datallowconn,
      database.datconnlimit,
      pg_size_pretty(
        pg_database_size(database.datname)
      ) AS size
    FROM pg_database AS database
    JOIN pg_roles AS owner
      ON owner.oid = database.datdba
    ORDER BY database.datname;
  "
}

audit_schemas_objects() {
  section "SCHEMAS E OBJETOS"

  psql_exec "
    SELECT
      namespace.nspname AS schema_name,
      owner.rolname AS owner
    FROM pg_namespace AS namespace
    JOIN pg_roles AS owner
      ON owner.oid = namespace.nspowner
    WHERE namespace.nspname NOT LIKE 'pg_%'
      AND namespace.nspname <> 'information_schema'
    ORDER BY namespace.nspname;
  "

  printf '\nObjetos por schema e proprietário:\n'
  psql_exec "
    SELECT
      namespace.nspname AS schema_name,
      owner.rolname AS owner,
      relation.relkind,
      count(*) AS object_count
    FROM pg_class AS relation
    JOIN pg_namespace AS namespace
      ON namespace.oid = relation.relnamespace
    JOIN pg_roles AS owner
      ON owner.oid = relation.relowner
    WHERE namespace.nspname NOT LIKE 'pg_%'
      AND namespace.nspname <> 'information_schema'
      AND relation.relkind IN (
        'r',
        'p',
        'v',
        'm',
        'S'
      )
    GROUP BY
      namespace.nspname,
      owner.rolname,
      relation.relkind
    ORDER BY
      namespace.nspname,
      owner.rolname,
      relation.relkind;
  "

  printf '\nMaiores tabelas:\n'
  psql_exec "
    SELECT
      schemaname,
      relname,
      pg_size_pretty(
        pg_total_relation_size(
          quote_ident(schemaname)
          || '.'
          || quote_ident(relname)
        )
      ) AS total_size
    FROM pg_stat_user_tables
    ORDER BY
      pg_total_relation_size(
        quote_ident(schemaname)
        || '.'
        || quote_ident(relname)
      ) DESC
    LIMIT 20;
  "
}

audit_privileges() {
  section "PRIVILÉGIOS"

  printf 'Privilégios de banco:\n'
  psql_exec "
    SELECT
      COALESCE(
        grantor.rolname,
        'unknown'
      ) AS grantor,
      CASE
        WHEN privilege.grantee = 0
          THEN 'PUBLIC'
        ELSE grantee.rolname
      END AS grantee,
      database.datname AS database_name,
      privilege.privilege_type,
      privilege.is_grantable
    FROM pg_database AS database
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        database.datacl,
        acldefault(
          'd',
          database.datdba
        )
      )
    ) AS privilege
    LEFT JOIN pg_roles AS grantor
      ON grantor.oid = privilege.grantor
    LEFT JOIN pg_roles AS grantee
      ON grantee.oid = privilege.grantee
    ORDER BY
      database.datname,
      grantee,
      privilege.privilege_type;
  "

  printf '\nPrivilégios de schema:\n'
  psql_exec "
    SELECT
      COALESCE(
        grantor.rolname,
        'unknown'
      ) AS grantor,
      CASE
        WHEN privilege.grantee = 0
          THEN 'PUBLIC'
        ELSE grantee.rolname
      END AS grantee,
      namespace.nspname AS schema_name,
      privilege.privilege_type,
      privilege.is_grantable
    FROM pg_namespace AS namespace
    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        namespace.nspacl,
        acldefault(
          'n',
          namespace.nspowner
        )
      )
    ) AS privilege
    LEFT JOIN pg_roles AS grantor
      ON grantor.oid = privilege.grantor
    LEFT JOIN pg_roles AS grantee
      ON grantee.oid = privilege.grantee
    WHERE namespace.nspname NOT LIKE 'pg_%'
      AND namespace.nspname <> 'information_schema'
    ORDER BY
      namespace.nspname,
      grantee,
      privilege.privilege_type;
  "

  printf '\nPrivilégios explícitos de tabela:\n'
  psql_exec "
    SELECT
      grantor,
      grantee,
      table_schema,
      table_name,
      privilege_type,
      is_grantable
    FROM information_schema.role_table_grants
    WHERE table_schema NOT IN (
      'pg_catalog',
      'information_schema'
    )
    ORDER BY
      table_schema,
      table_name,
      grantee,
      privilege_type;
  "

  printf '\nDefault privileges:\n'
  psql_exec "
    SELECT
      owner.rolname AS owner,
      namespace.nspname AS schema_name,
      defaults.defaclobjtype AS object_type,
      defaults.defaclacl
    FROM pg_default_acl AS defaults
    JOIN pg_roles AS owner
      ON owner.oid = defaults.defaclrole
    LEFT JOIN pg_namespace AS namespace
      ON namespace.oid = defaults.defaclnamespace
    ORDER BY
      owner.rolname,
      namespace.nspname,
      defaults.defaclobjtype;
  "
}

audit_extensions() {
  section "EXTENSÕES"

  printf 'Instaladas:\n'
  psql_exec "
    SELECT
      extension.extname,
      extension.extversion,
      namespace.nspname AS schema_name
    FROM pg_extension AS extension
    JOIN pg_namespace AS namespace
      ON namespace.oid = extension.extnamespace
    ORDER BY extension.extname;
  "

  printf '\nDisponibilidade das extensões candidatas:\n'
  psql_exec "
    SELECT
      name,
      default_version,
      installed_version,
      comment
    FROM pg_available_extensions
    WHERE name IN (
      'pgcrypto',
      'uuid-ossp',
      'citext',
      'pg_trgm',
      'btree_gin',
      'btree_gist',
      'hstore'
    )
    ORDER BY name;
  "
}

audit_connections() {
  section "CONEXÕES E ATIVIDADE"

  psql_exec "
    SELECT
      datname,
      usename,
      application_name,
      client_addr,
      state,
      count(*) AS connections
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
    GROUP BY
      datname,
      usename,
      application_name,
      client_addr,
      state
    ORDER BY
      datname,
      usename,
      application_name,
      state;
  "

  printf '\nLimite e uso de conexões:\n'
  psql_exec "
    SELECT
      current_setting(
        'max_connections'
      )::integer AS max_connections,
      count(*) AS current_connections,
      current_setting(
        'superuser_reserved_connections'
      )::integer AS superuser_reserved_connections
    FROM pg_stat_activity;
  "

  printf '\nEstatísticas dos bancos:\n'
  psql_exec "
    SELECT
      datname,
      numbackends,
      xact_commit,
      xact_rollback,
      blks_read,
      blks_hit,
      deadlocks,
      temp_files,
      pg_size_pretty(temp_bytes) AS temp_bytes
    FROM pg_stat_database
    WHERE datname IS NOT NULL
    ORDER BY datname;
  "
}

audit_hba() {
  section "AUTENTICAÇÃO PG_HBA — SEM SEGREDOS"

  psql_exec "
    SELECT
      line_number,
      type,
      database,
      user_name,
      address,
      netmask,
      auth_method,
      options,
      error
    FROM pg_hba_file_rules
    ORDER BY line_number;
  "
}

audit_persistence() {
  section "DADOS E VOLUME"

  container_exec \
    sh -ec '
      printf "PGDATA=%s\n" "${PGDATA:-not-set}"
      printf "Data directory usage:\n"
      du -sh "$(
        psql \
          -X \
          -At \
          -U "$POSTGRES_USER" \
          -d "$POSTGRES_DB" \
          -c "SHOW data_directory"
      )"
      printf "Filesystem:\n"
      df -h "$(
        psql \
          -X \
          -At \
          -U "$POSTGRES_USER" \
          -d "$POSTGRES_DB" \
          -c "SHOW data_directory"
      )"
    '
}

audit_logical_tools() {
  section "CAPACIDADE DE BACKUP LÓGICO"

  container_exec \
    sh -ec '
      test -x "$(command -v pg_dump)"
      test -x "$(command -v pg_restore)"
      test -x "$(command -v createdb)"
      test -x "$(command -v dropdb)"
      printf "pg_dump=available\n"
      printf "pg_restore=available\n"
      printf "createdb=available\n"
      printf "dropdb=available\n"
    '

  printf '\nTeste de catálogo sem criar backup:\n'
  container_exec \
    sh -ec '
      pg_dump \
        --schema-only \
        --no-owner \
        --no-privileges \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        >/dev/null
      printf "schema_only_dump=success\n"
    '
}

audit_summary() {
  section "RESUMO AUTOMÁTICO"

  psql_exec "
    SELECT
      current_database() AS database,
      current_user AS audit_user,
      (
        SELECT count(*)
        FROM pg_roles
        WHERE rolcanlogin
      ) AS login_roles,
      (
        SELECT count(*)
        FROM pg_roles
        WHERE rolsuper
      ) AS superuser_roles,
      (
        SELECT count(*)
        FROM pg_stat_user_tables
      ) AS user_tables,
      (
        SELECT count(*)
        FROM pg_extension
      ) AS installed_extensions,
      (
        SELECT count(*)
        FROM pg_stat_activity
      ) AS connections;
  "

  printf '\nAudit completed without mutations.\n'
}

main() {
  check_requirements

  umask 077
  : > "${REPORT_FILE}"

  exec > >(tee "${REPORT_FILE}") 2>&1

  write_header
  audit_container
  audit_versions
  audit_application_connection
  audit_cluster_settings
  audit_roles
  audit_databases
  audit_schemas_objects
  audit_privileges
  audit_extensions
  audit_connections
  audit_hba
  audit_persistence
  audit_logical_tools
  audit_summary

  chmod 0600 "${REPORT_FILE}"

  printf '\n'
  ok "Auditoria PostgreSQL concluída."
  printf 'Relatório local: %s\n' "${REPORT_FILE}"
  printf 'Não adicione postgresql-audit.txt ao Git.\n'
}

main "$@"
