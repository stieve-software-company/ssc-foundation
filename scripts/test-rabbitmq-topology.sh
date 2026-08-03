#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly BASE_COMPOSE="${PROJECT_ROOT}/compose.yaml"
readonly ACCESS_COMPOSE="${PROJECT_ROOT}/compose.access.yaml"

readonly REQUIRED_EXCHANGES=(
  companyos.commands
  companyos.events
  companyos.retry.5s
  companyos.retry.30s
  companyos.retry.5m
  companyos.dead-letter
)

readonly REQUIRED_QUEUES=(
  companyos.workflow.commands
  companyos.agent.commands
  companyos.audit.events
  companyos.notifications.events
  companyos.retry.5s
  companyos.retry.30s
  companyos.retry.5m
  companyos.dead-letter
)

readonly REQUIRED_POLICIES=(
  companyos-work-dead-letter
  companyos-event-dead-letter
  companyos-retry-5s
  companyos-retry-30s
  companyos-retry-5m
)

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

    docker compose \
      --env-file "${ENV_FILE}" \
      -f "${BASE_COMPOSE}" \
      -f "${ACCESS_COMPOSE}" \
      "$@"
  )
}

check_requirements() {
  [[ -s "${ENV_FILE}" ]] || fail "Arquivo ausente: ${ENV_FILE}"

  docker info >/dev/null 2>&1 \
    || fail "Docker daemon não está acessível."

  compose ps --status running rabbitmq |
    grep -q rabbitmq \
    || fail "RabbitMQ não está em execução."

  compose ps --status running mission-control |
    grep -q mission-control \
    || fail "Mission Control não está em execução."
}

check_named_resources() {
  local resource_type=$1
  shift
  local -a required=("$@")
  local output

  case "${resource_type}" in
    exchange)
      output="$(
        compose exec \
          -T \
          rabbitmq \
          rabbitmqctl \
          --quiet \
          list_exchanges \
          --vhost development \
          --no-table-headers
      )"
      ;;
    queue)
      output="$(
        compose exec \
          -T \
          rabbitmq \
          rabbitmqctl \
          --quiet \
          list_queues \
          --vhost development \
          --no-table-headers
      )"
      ;;
    policy)
      output="$(
        compose exec \
          -T \
          rabbitmq \
          rabbitmqctl \
          --quiet \
          list_policies \
          --vhost development \
          --no-table-headers
      )"
      ;;
    *)
      fail "Tipo de recurso desconhecido: ${resource_type}"
      ;;
  esac

  local name
  for name in "${required[@]}"; do
    grep -Fq -- "${name}" <<< "${output}" \
      || fail "${resource_type} ausente: ${name}"
  done
}

check_structure() {
  info "Validando exchanges."
  check_named_resources exchange "${REQUIRED_EXCHANGES[@]}"
  ok "Todas as exchanges existem."

  info "Validando filas."
  check_named_resources queue "${REQUIRED_QUEUES[@]}"
  ok "Todas as filas existem."

  info "Validando políticas."
  check_named_resources policy "${REQUIRED_POLICIES[@]}"
  ok "Todas as políticas existem."
}

run_functional_test() {
  info "Executando testes funcionais pelo Mission Control."

  compose exec \
    -T \
    mission-control \
    python - <<'PY'
from __future__ import annotations

import json
import time
import uuid
from typing import Any

import pika

from app.config import settings


EXCHANGES = {
    "companyos.commands": "direct",
    "companyos.events": "topic",
    "companyos.retry.5s": "direct",
    "companyos.retry.30s": "direct",
    "companyos.retry.5m": "direct",
    "companyos.dead-letter": "topic",
}

QUEUES = [
    "companyos.workflow.commands",
    "companyos.agent.commands",
    "companyos.audit.events",
    "companyos.notifications.events",
    "companyos.retry.5s",
    "companyos.retry.30s",
    "companyos.retry.5m",
    "companyos.dead-letter",
]


def fail(message: str) -> None:
    raise RuntimeError(message)


def payload(test_id: str, test_type: str) -> bytes:
    return json.dumps(
        {
            "test_id": test_id,
            "test_type": test_type,
            "source": "test-rabbitmq-topology.sh",
        }
    ).encode("utf-8")


def properties(test_id: str) -> pika.BasicProperties:
    return pika.BasicProperties(
        content_type="application/json",
        delivery_mode=2,
        correlation_id=test_id,
        headers={"ssc_test": True},
    )


def wait_for_message(
    channel: pika.adapters.blocking_connection.BlockingChannel,
    queue: str,
    test_id: str,
    timeout_seconds: float,
) -> tuple[Any, pika.BasicProperties, bytes]:
    deadline = time.monotonic() + timeout_seconds
    held_tags: list[int] = []

    try:
        while time.monotonic() < deadline:
            method, props, body = channel.basic_get(
                queue=queue,
                auto_ack=False,
            )

            if method is None:
                time.sleep(0.2)
                continue

            if props.correlation_id == test_id:
                return method, props, body

            held_tags.append(method.delivery_tag)

        fail(f"Timeout aguardando mensagem em {queue}.")
    finally:
        for delivery_tag in held_tags:
            channel.basic_nack(
                delivery_tag=delivery_tag,
                requeue=True,
            )

    raise AssertionError("unreachable")


parameters = pika.URLParameters(settings.rabbitmq_url)
parameters.socket_timeout = 10
parameters.blocked_connection_timeout = 10
parameters.connection_attempts = 1

connection = pika.BlockingConnection(parameters)
channel = connection.channel()
channel.confirm_delivery()

try:
    for exchange, exchange_type in EXCHANGES.items():
        channel.exchange_declare(
            exchange=exchange,
            exchange_type=exchange_type,
            passive=True,
        )

    for queue in QUEUES:
        channel.queue_declare(queue=queue, passive=True)

    # Direct exchange.
    command_id = str(uuid.uuid4())
    command_key = f"ssc.test.command.{command_id}"
    command_queue = channel.queue_declare(
        queue="",
        exclusive=True,
        auto_delete=True,
    ).method.queue

    channel.queue_bind(
        queue=command_queue,
        exchange="companyos.commands",
        routing_key=command_key,
    )

    channel.basic_publish(
        exchange="companyos.commands",
        routing_key=command_key,
        body=payload(command_id, "command"),
        properties=properties(command_id),
        mandatory=True,
    )

    method, _, _ = wait_for_message(
        channel,
        command_queue,
        command_id,
        5,
    )
    channel.basic_ack(method.delivery_tag)
    print("[OK] Roteamento de command validado.")

    # Topic exchange.
    event_id = str(uuid.uuid4())
    event_key = f"ssc.test.event.{event_id}"
    event_queue = channel.queue_declare(
        queue="",
        exclusive=True,
        auto_delete=True,
    ).method.queue

    channel.queue_bind(
        queue=event_queue,
        exchange="companyos.events",
        routing_key="ssc.test.event.#",
    )

    channel.basic_publish(
        exchange="companyos.events",
        routing_key=event_key,
        body=payload(event_id, "event"),
        properties=properties(event_id),
        mandatory=True,
    )

    method, _, _ = wait_for_message(
        channel,
        event_queue,
        event_id,
        5,
    )
    channel.basic_ack(method.delivery_tag)
    print("[OK] Roteamento de event validado.")

    # Retry de 5 segundos.
    retry_id = str(uuid.uuid4())
    retry_key = f"ssc.test.retry.{retry_id}"
    retry_destination = channel.queue_declare(
        queue="",
        exclusive=True,
        auto_delete=True,
    ).method.queue

    channel.queue_bind(
        queue="companyos.retry.5s",
        exchange="companyos.retry.5s",
        routing_key=retry_key,
    )
    channel.queue_bind(
        queue=retry_destination,
        exchange="companyos.commands",
        routing_key=retry_key,
    )

    try:
        channel.basic_publish(
            exchange="companyos.retry.5s",
            routing_key=retry_key,
            body=payload(retry_id, "retry"),
            properties=properties(retry_id),
            mandatory=True,
        )

        method, props, _ = wait_for_message(
            channel,
            retry_destination,
            retry_id,
            15,
        )

        x_death = (props.headers or {}).get("x-death", [])
        if not x_death:
            fail("Retry chegou sem o header x-death.")

        channel.basic_ack(method.delivery_tag)
        print("[OK] Retry de 5 segundos validado.")
    finally:
        channel.queue_unbind(
            queue="companyos.retry.5s",
            exchange="companyos.retry.5s",
            routing_key=retry_key,
        )

    # Dead-letter da fila operacional.
    dead_id = str(uuid.uuid4())
    dead_key = f"ssc.test.dead.{dead_id}"

    channel.queue_bind(
        queue="companyos.workflow.commands",
        exchange="companyos.commands",
        routing_key=dead_key,
    )

    try:
        channel.basic_publish(
            exchange="companyos.commands",
            routing_key=dead_key,
            body=payload(dead_id, "dead-letter"),
            properties=properties(dead_id),
            mandatory=True,
        )

        method, _, _ = wait_for_message(
            channel,
            "companyos.workflow.commands",
            dead_id,
            5,
        )
        channel.basic_nack(
            delivery_tag=method.delivery_tag,
            requeue=False,
        )

        method, props, _ = wait_for_message(
            channel,
            "companyos.dead-letter",
            dead_id,
            10,
        )

        x_death = (props.headers or {}).get("x-death", [])
        if not x_death:
            fail("Dead-letter chegou sem o header x-death.")

        channel.basic_ack(method.delivery_tag)
        print("[OK] Dead-letter validado.")
    finally:
        channel.queue_unbind(
            queue="companyos.workflow.commands",
            exchange="companyos.commands",
            routing_key=dead_key,
        )

finally:
    if connection.is_open:
        connection.close()

print("[OK] Testes funcionais RabbitMQ concluídos.")
PY
}

main() {
  check_requirements
  check_structure
  run_functional_test

  printf '\n'
  ok "Topologia RabbitMQ validada."
}

main "$@"
