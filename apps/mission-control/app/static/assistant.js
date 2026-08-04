document.addEventListener("DOMContentLoaded", () => {
  const form = document.querySelector("#assistant-form");
  const input = document.querySelector("#assistant-input");
  const submit = document.querySelector("#assistant-submit");
  const messages = document.querySelector(
    "#assistant-messages"
  );
  const shortcuts = document.querySelectorAll(
    "[data-assistant-question]"
  );

  if (!form || !input || !submit || !messages) {
    return;
  }

  const createElement = (
    tag,
    value = "",
    className = ""
  ) => {
    const element = document.createElement(tag);
    element.textContent = String(value ?? "");

    if (className) {
      element.className = className;
    }

    return element;
  };

  const scrollToBottom = () => {
    messages.scrollTop = messages.scrollHeight;
  };

  const renderServiceStatus = (component) => {
    const list = createElement(
      "div",
      "",
      "assistant-service-list"
    );

    for (const item of component.items || []) {
      const row = createElement(
        "div",
        "",
        "assistant-service"
      );
      const dot = createElement(
        "span",
        "",
        "status-dot"
      );

      if (item.status !== "healthy") {
        dot.classList.add("offline");
      }

      const detail = createElement("div");
      detail.append(
        createElement("strong", item.name),
        createElement("small", item.detail)
      );

      const latency = createElement(
        "span",
        item.latency_ms === null ||
        item.latency_ms === undefined
          ? "—"
          : `${item.latency_ms} ms`,
        "assistant-service-latency"
      );

      row.append(dot, detail, latency);
      list.append(row);
    }

    return list;
  };

  const renderTable = (component) => {
    const wrapper = createElement(
      "div",
      "",
      "assistant-table-wrap"
    );
    const table = createElement(
      "table",
      "",
      "assistant-table"
    );
    const head = document.createElement("thead");
    const headRow = document.createElement("tr");
    const body = document.createElement("tbody");

    for (const column of component.columns || []) {
      headRow.append(
        createElement("th", column.label)
      );
    }

    head.append(headRow);

    for (const row of component.rows || []) {
      const bodyRow = document.createElement("tr");

      for (const column of component.columns || []) {
        bodyRow.append(
          createElement(
            "td",
            row[column.key] ?? "—"
          )
        );
      }

      body.append(bodyRow);
    }

    table.append(head, body);
    wrapper.append(table);
    return wrapper;
  };

  const renderSummary = (component) => {
    const summary = createElement(
      "div",
      "",
      "assistant-summary"
    );

    for (const item of component.items || []) {
      const card = createElement(
        "div",
        "",
        "assistant-summary-item"
      );
      card.append(
        createElement("strong", item.value),
        createElement("small", item.label)
      );
      summary.append(card);
    }

    return summary;
  };

  const renderList = (component) => {
    const list = createElement(
      "ul",
      "",
      "assistant-list"
    );

    for (const item of component.items || []) {
      list.append(
        createElement("li", item)
      );
    }

    return list;
  };

  const renderComponent = (component) => {
    if (!component || typeof component !== "object") {
      return null;
    }

    let content = null;

    if (component.type === "service_status") {
      content = renderServiceStatus(component);
    } else if (component.type === "table") {
      content = renderTable(component);
    } else if (component.type === "summary") {
      content = renderSummary(component);
    } else if (component.type === "list") {
      content = renderList(component);
    }

    if (!content) {
      return null;
    }

    const wrapper = createElement(
      "div",
      "",
      "assistant-component"
    );
    wrapper.append(content);
    return wrapper;
  };

  const appendMessage = ({
    role,
    text,
    component = null,
    error = false,
  }) => {
    const article = createElement(
      "article",
      "",
      `assistant-message ${role}`
    );

    if (error) {
      article.classList.add("error");
    }

    article.append(
      createElement(
        "div",
        role === "user" ? "Você" : "Assistant",
        "assistant-message-label"
      ),
      createElement("p", text)
    );

    const rendered = renderComponent(component);

    if (rendered) {
      article.append(rendered);
    }

    messages.append(article);
    scrollToBottom();
  };

  const sendMessage = async (question) => {
    const cleaned = question.trim();

    if (!cleaned || submit.disabled) {
      return;
    }

    appendMessage({
      role: "user",
      text: cleaned,
    });

    input.value = "";
    submit.disabled = true;
    form.classList.add("assistant-loading");
    submit.textContent = "Consultando...";

    const formData = new FormData(form);
    formData.set("message", cleaned);

    try {
      const response = await fetch(
        "/assistant/message",
        {
          method: "POST",
          body: formData,
          credentials: "same-origin",
          headers: {
            Accept: "application/json",
          },
        }
      );

      const payload = await response.json();

      appendMessage({
        role: "assistant",
        text:
          payload.message ||
          "O Assistant não retornou uma mensagem.",
        component: payload.component,
        error: !response.ok || !payload.ok,
      });

      if (response.status === 401) {
        window.setTimeout(() => {
          window.location.assign("/login");
        }, 1200);
      }
    } catch (_error) {
      appendMessage({
        role: "assistant",
        text:
          "Não foi possível comunicar com "
          + "o Mission Control.",
        error: true,
      });
    } finally {
      submit.disabled = false;
      form.classList.remove("assistant-loading");
      submit.textContent = "Enviar";
      input.focus();
    }
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    sendMessage(input.value);
  });

  input.addEventListener("keydown", (event) => {
    if (
      event.key === "Enter"
      && !event.shiftKey
      && !event.isComposing
    ) {
      event.preventDefault();
      sendMessage(input.value);
    }
  });

  for (const shortcut of shortcuts) {
    shortcut.addEventListener("click", () => {
      sendMessage(
        shortcut.dataset.assistantQuestion || ""
      );
    });
  }

  scrollToBottom();
});
