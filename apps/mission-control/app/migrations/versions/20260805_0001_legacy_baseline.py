"""Schema legado do Mission Control 0.3.0.

Revision ID: 20260805_0001
Revises:
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260805_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "permissions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(length=100), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column(
            "description",
            sa.String(length=300),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_permissions_code",
        "permissions",
        ["code"],
        unique=True,
    )

    op.create_table(
        "roles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column(
            "description",
            sa.String(length=300),
            nullable=False,
        ),
        sa.Column("is_system", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_roles_slug",
        "roles",
        ["slug"],
        unique=True,
    )

    op.create_table(
        "role_permissions",
        sa.Column(
            "role_id",
            sa.Integer(),
            sa.ForeignKey("roles.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "permission_id",
            sa.Integer(),
            sa.ForeignKey(
                "permissions.id",
                ondelete="CASCADE",
            ),
            primary_key=True,
        ),
    )

    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "username",
            sa.String(length=64),
            nullable=False,
        ),
        sa.Column(
            "email",
            sa.String(length=320),
            nullable=True,
        ),
        sa.Column(
            "full_name",
            sa.String(length=160),
            nullable=False,
        ),
        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "phone",
            sa.String(length=40),
            nullable=True,
        ),
        sa.Column(
            "job_title",
            sa.String(length=120),
            nullable=True,
        ),
        sa.Column(
            "department",
            sa.String(length=120),
            nullable=True,
        ),
        sa.Column(
            "timezone",
            sa.String(length=80),
            nullable=False,
        ),
        sa.Column(
            "locale",
            sa.String(length=20),
            nullable=False,
        ),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column(
            "role_id",
            sa.Integer(),
            sa.ForeignKey("roles.id"),
            nullable=False,
        ),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column(
            "profile_completed",
            sa.Boolean(),
            nullable=False,
        ),
        sa.Column(
            "session_version",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "last_login_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "password_changed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "username",
            name="uq_users_username",
        ),
        sa.UniqueConstraint(
            "email",
            name="uq_users_email",
        ),
    )
    op.create_index(
        "ix_users_username",
        "users",
        ["username"],
        unique=False,
    )
    op.create_index(
        "ix_users_email",
        "users",
        ["email"],
        unique=False,
    )

    op.create_table(
        "audit_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey(
                "users.id",
                ondelete="SET NULL",
            ),
            nullable=True,
        ),
        sa.Column(
            "action",
            sa.String(length=100),
            nullable=False,
        ),
        sa.Column(
            "resource_type",
            sa.String(length=80),
            nullable=False,
        ),
        sa.Column(
            "resource_id",
            sa.String(length=100),
            nullable=True,
        ),
        sa.Column(
            "description",
            sa.String(length=500),
            nullable=False,
        ),
        sa.Column(
            "ip_address",
            sa.String(length=80),
            nullable=True,
        ),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_audit_events_user_id",
        "audit_events",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_audit_events_action",
        "audit_events",
        ["action"],
        unique=False,
    )
    op.create_index(
        "ix_audit_events_created_at",
        "audit_events",
        ["created_at"],
        unique=False,
    )

    op.create_table(
        "branding_settings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "theme_name",
            sa.String(length=40),
            nullable=False,
        ),
        sa.Column(
            "background",
            sa.String(length=7),
            nullable=False,
        ),
        sa.Column(
            "surface",
            sa.String(length=7),
            nullable=False,
        ),
        sa.Column(
            "surface_soft",
            sa.String(length=7),
            nullable=False,
        ),
        sa.Column(
            "accent",
            sa.String(length=7),
            nullable=False,
        ),
        sa.Column(
            "accent_strong",
            sa.String(length=7),
            nullable=False,
        ),
        sa.Column(
            "text",
            sa.String(length=7),
            nullable=False,
        ),
        sa.Column(
            "muted",
            sa.String(length=7),
            nullable=False,
        ),
        sa.Column(
            "logo_data",
            sa.LargeBinary(),
            nullable=True,
        ),
        sa.Column(
            "logo_content_type",
            sa.String(length=50),
            nullable=True,
        ),
        sa.Column(
            "logo_filename",
            sa.String(length=255),
            nullable=True,
        ),
        sa.Column(
            "logo_updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "updated_by_user_id",
            sa.Uuid(),
            sa.ForeignKey(
                "users.id",
                ondelete="SET NULL",
            ),
            nullable=True,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("branding_settings")

    op.drop_index(
        "ix_audit_events_created_at",
        table_name="audit_events",
    )
    op.drop_index(
        "ix_audit_events_action",
        table_name="audit_events",
    )
    op.drop_index(
        "ix_audit_events_user_id",
        table_name="audit_events",
    )
    op.drop_table("audit_events")

    op.drop_index(
        "ix_users_email",
        table_name="users",
    )
    op.drop_index(
        "ix_users_username",
        table_name="users",
    )
    op.drop_table("users")
    op.drop_table("role_permissions")

    op.drop_index(
        "ix_roles_slug",
        table_name="roles",
    )
    op.drop_table("roles")

    op.drop_index(
        "ix_permissions_code",
        table_name="permissions",
    )
    op.drop_table("permissions")
