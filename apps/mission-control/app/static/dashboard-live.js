document.addEventListener("DOMContentLoaded", () => {
  const liveTargets = document.querySelectorAll(
    "[data-live-service]"
  );
  const connectionLabels = document.querySelectorAll(
    "[data-live-connection]"
  );
  const updatedLabels = document.querySelectorAll(
    "[data-live-updated]"
  );
  const serviceCount = document.querySelector(
    "[data-live-service-count]"
  );

  if (
    liveTargets.length === 0
    && connectionLabels.length === 0
  ) {
    return;
  }

  const setConnection = (text, state) => {
    for (const label of connectionLabels) {
      label.textContent = text;
      label.dataset.state = state;
    }
  };

  const formatTime = (value) => {
    if (!value) {
      return "aguardando";
    }

    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
      return "desconhecida";
    }

    return new Intl.DateTimeFormat(
      "pt-BR",
      {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      }
    ).format(date);
  };

  const updateElement = (element, service) => {
    const dot = element.querySelector(
      "[data-live-status-dot]"
    );
    const detail = element.querySelector(
      "[data-live-detail]"
    );
    const latency = element.querySelector(
      "[data-live-latency]"
    );
    const badge = element.querySelector(
      "[data-live-status-badge]"
    );

    const healthy = service.status === "healthy";
    const collecting = service.status === "collecting";

    element.classList.toggle(
      "offline",
      !healthy && !collecting
    );
    element.classList.toggle(
      "collecting",
      collecting
    );

    if (dot) {
      dot.classList.toggle(
        "offline",
        !healthy && !collecting
      );
      dot.classList.toggle(
        "collecting",
        collecting
      );
    }

    if (detail) {
      detail.textContent =
        service.detail || "Sem detalhes.";
    }

    if (latency) {
      latency.textContent =
        service.latency_ms === null
        || service.latency_ms === undefined
          ? "—"
          : `${service.latency_ms} ms`;
    }

    if (badge) {
      badge.textContent = collecting
        ? "Coletando"
        : healthy
          ? "Disponível"
          : "Indisponível";

      badge.classList.toggle(
        "inactive",
        !healthy && !collecting
      );
      badge.classList.toggle(
        "collecting",
        collecting
      );
    }
  };

  const renderSummary = (summary) => {
    const services = Array.isArray(summary.services)
      ? summary.services
      : [];

    for (const service of services) {
      const selector = [
        "[data-live-service=\"",
        CSS.escape(String(service.slug || "")),
        "\"]",
      ].join("");

      for (const element of document.querySelectorAll(
        selector
      )) {
        updateElement(element, service);
      }
    }

    if (serviceCount && summary.counts) {
      serviceCount.textContent = [
        summary.counts.healthy ?? 0,
        summary.counts.total ?? services.length,
      ].join("/");
    }

    for (const label of updatedLabels) {
      label.textContent = formatTime(
        summary.generated_at
      );
    }

    if (summary.stale) {
      setConnection(
        "Dados desatualizados",
        "warning"
      );
    } else {
      setConnection("Ao vivo", "online");
    }
  };

  if (!("EventSource" in window)) {
    setConnection(
      "Atualização ao vivo indisponível",
      "warning"
    );
    return;
  }

  setConnection("Conectando...", "connecting");

  const stream = new EventSource(
    "/api/v1/system/events",
    { withCredentials: true }
  );

  stream.addEventListener(
    "system.summary",
    (event) => {
      try {
        renderSummary(JSON.parse(event.data));
      } catch (_error) {
        setConnection(
          "Resposta de status inválida",
          "warning"
        );
      }
    }
  );

  stream.onopen = () => {
    setConnection("Ao vivo", "online");
  };

  stream.onerror = () => {
    setConnection(
      "Reconectando...",
      "connecting"
    );
  };

  window.addEventListener("beforeunload", () => {
    stream.close();
  });
});
