document.addEventListener("DOMContentLoaded", () => {
  const button = document.querySelector("[data-sidebar-toggle]");
  const sidebar = document.querySelector("#sidebar");

  if (!button || !sidebar) {
    return;
  }

  button.addEventListener("click", () => {
    sidebar.classList.toggle("open");
  });

  document.addEventListener("click", (event) => {
    const target = event.target;

    if (
      window.innerWidth <= 880 &&
      sidebar.classList.contains("open") &&
      !sidebar.contains(target) &&
      !button.contains(target)
    ) {
      sidebar.classList.remove("open");
    }
  });
});
