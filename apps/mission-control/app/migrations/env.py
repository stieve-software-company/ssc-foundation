from __future__ import annotations

from logging.config import fileConfig

from alembic import context

from app.database import engine
from app.models import Base


config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def configure_connection(connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        compare_server_default=False,
        transaction_per_migration=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_offline() -> None:
    raise RuntimeError(
        "Migrações offline não são suportadas pelo Mission Control."
    )


def run_migrations_online() -> None:
    supplied = config.attributes.get("connection")

    if supplied is not None:
        configure_connection(supplied)
        return

    with engine.connect() as connection:
        configure_connection(connection)


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
