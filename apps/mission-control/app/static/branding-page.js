document.addEventListener("DOMContentLoaded", () => {
  const form = document.querySelector("#branding-theme-form");
  const customFields = document.querySelector("#custom-colors");
  const themeInputs = document.querySelectorAll(
    'input[name="theme_name"]'
  );

  if (!form || !customFields || themeInputs.length === 0) {
    return;
  }

  const updateCustomVisibility = () => {
    const selected = form.querySelector(
      'input[name="theme_name"]:checked'
    );

    customFields.classList.toggle(
      "visible",
      selected?.value === "custom"
    );
  };

  for (const input of themeInputs) {
    input.addEventListener("change", updateCustomVisibility);
  }

  updateCustomVisibility();
});
