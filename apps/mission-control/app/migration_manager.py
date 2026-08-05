from __future__ import annotations

import argparse
import os
import re
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import inspect, text

from app.database import engine


BASELINE_REVISION = "20260805_0001"
HEAD_REVISION = "20260805_0002"
MIGRATION_LOCK_ID = 920260805

LEGACY_TABLES = {
    "permissions",
    "roles",
    "role_permissions",
    "users",
    "audit_events",
    "branding_settings",
}


def alembic_config() -> Config:
    path = Path(__file__).resolve().parent / "alembic.ini"
    config = Config(str(path))
    config.set_main_option(
        "script_location",
        str(path.parent / "migrations"),
    )
    return config


def database_state(connection=None) -> str:
    inspector = (
        inspect(connection)
        if connection is not None
        else inspect(engine)
    )
    tables = set(inspector.get_table_names())

    if "alembic_version" in tables:
        return "managed"

    business_tables = tables - {"alembic_version"}

    if not business_tables:
        return "fresh"

    if business_tables == LEGACY_TABLES:
        return "legacy"

    return "unexpected"


def current_revision(connection=None) -> str | None:
    inspector = (
        inspect(connection)
        if connection is not None
        else inspect(engine)
    )

    if "alembic_version" not in inspector.get_table_names():
        return None

    statement = text(
        "SELECT version_num FROM alembic_version"
    )

    if connection is not None:
        value = connection.execute(
            statement
        ).scalar_one_or_none()
    else:
        with engine.connect() as runtime_connection:
            value = runtime_connection.execute(
                statement
            ).scalar_one_or_none()

    return str(value) if value else None


def validated_migration_role() -> str:
    role = os.getenv(
        "SSC_MIGRATION_ROLE",
        "",
    ).strip()

    if not re.fullmatch(
        r"[a-z_][a-z0-9_]{0,62}",
        role,
    ):
        raise RuntimeError(
            "SSC_MIGRATION_ROLE ausente ou inválido."
        )

    return role


def set_local_migration_role(
    connection,
    role: str,
) -> None:
    quoted = '"' + role.replace('"', '""') + '"'
    connection.exec_driver_sql(
        f"SET LOCAL ROLE {quoted}"
    )


def upgrade_database() -> None:
    role = validated_migration_role()
    config = alembic_config()

    with engine.begin() as connection:
        connection.execute(
            text(
                "SELECT pg_advisory_xact_lock(:lock_id)"
            ),
            {"lock_id": MIGRATION_LOCK_ID},
        )

        set_local_migration_role(
            connection,
            role,
        )

        state = database_state(connection)

        if state == "unexpected":
            raise RuntimeError(
                "Schema parcial ou desconhecido. "
                "Migração abortada."
            )

        config.attributes["connection"] = connection

        if state == "legacy":
            command.stamp(
                config,
                BASELINE_REVISION,
            )

        command.upgrade(config, "head")

        revision = current_revision(connection)

        if revision != HEAD_REVISION:
            raise RuntimeError(
                "Migração incompleta. "
                f"Esperado={HEAD_REVISION} "
                f"atual={revision}"
            )


def assert_database_revision() -> None:
    revision = current_revision()

    if revision != HEAD_REVISION:
        raise RuntimeError(
            "Banco fora da revisão esperada. "
            f"Esperado={HEAD_REVISION} "
            f"atual={revision or '<absent>'}. "
            "Execute a migração one-shot."
        )


def print_status() -> None:
    print(f"state={database_state()}")
    print(f"current_revision={current_revision()}")
    print(f"expected_revision={HEAD_REVISION}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action",
        choices=("status", "upgrade", "validate"),
    )
    args = parser.parse_args()

    if args.action == "status":
        print_status()
        return

    if args.action == "validate":
        assert_database_revision()
        print_status()
        return

    upgrade_database()
    print_status()


if __name__ == "__main__":
    main()
