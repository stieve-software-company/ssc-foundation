"""Service Registry inicial.

Revision ID: 20260805_0002
Revises: 20260805_0001
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260805_0002"
down_revision = "20260805_0001"
branch_labels = None
depends_on = None


SERVICE_DEFINITIONS = (
    {
        "slug": "postgres",
        "name": "PostgreSQL",
        "category": "data",
        "criticality": "critical",
        "check_target": "postgres",
        "sort_order": 10,
    },
    {
        "slug": "redis",
        "name": "Redis",
        "category": "data",
        "criticality": "critical",
        "check_target": "redis",
        "sort_order": 20,
    },
    {
        "slug": "rabbitmq",
        "name": "RabbitMQ",
        "category": "messaging",
        "criticality": "critical",
        "check_target": "rabbitmq",
        "sort_order": 30,
    },
    {
        "slug": "minio",
        "name": "MinIO",
        "category": "storage",
        "criticality": "high",
        "check_target": "minio",
        "sort_order": 40,
    },
    {
        "slug": "ollama",
        "name": "Ollama",
        "category": "ai",
        "criticality": "normal",
        "check_target": "ollama",
        "sort_order": 50,
    },
)


def upgrade() -> None:
    op.create_table(
        "service_definitions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "slug",
            sa.String(length=80),
            nullable=False,
        ),
        sa.Column(
            "name",
            sa.String(length=120),
            nullable=False,
        ),
        sa.Column(
            "category",
            sa.String(length=80),
            nullable=False,
        ),
        sa.Column(
            "criticality",
            sa.String(length=20),
            nullable=False,
        ),
        sa.Column(
            "check_type",
            sa.String(length=40),
            nullable=False,
        ),
        sa.Column(
            "check_target",
            sa.String(length=120),
            nullable=False,
        ),
        sa.Column(
            "check_timeout_seconds",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "source",
            sa.String(length=40),
            nullable=False,
        ),
        sa.Column(
            "is_enabled",
            sa.Boolean(),
            nullable=False,
        ),
        sa.Column(
            "sort_order",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "attributes",
            sa.JSON(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_service_definitions_slug",
        "service_definitions",
        ["slug"],
        unique=True,
    )
    op.create_index(
        "ix_service_definitions_is_enabled",
        "service_definitions",
        ["is_enabled"],
        unique=False,
    )

    table = sa.table(
        "service_definitions",
        sa.column("slug", sa.String()),
        sa.column("name", sa.String()),
        sa.column("category", sa.String()),
        sa.column("criticality", sa.String()),
        sa.column("check_type", sa.String()),
        sa.column("check_target", sa.String()),
        sa.column("check_timeout_seconds", sa.Integer()),
        sa.column("source", sa.String()),
        sa.column("is_enabled", sa.Boolean()),
        sa.column("sort_order", sa.Integer()),
        sa.column("attributes", sa.JSON()),
    )

    op.bulk_insert(
        table,
        [
            {
                **definition,
                "check_type": "builtin",
                "check_timeout_seconds": 5,
                "source": "bootstrap",
                "is_enabled": True,
                "attributes": {},
            }
            for definition in SERVICE_DEFINITIONS
        ],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_service_definitions_is_enabled",
        table_name="service_definitions",
    )
    op.drop_index(
        "ix_service_definitions_slug",
        table_name="service_definitions",
    )
    op.drop_table("service_definitions")
