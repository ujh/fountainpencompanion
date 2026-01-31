document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll(".alert-dismissible").forEach(function (alert) {
    alert.addEventListener("closed.bs.alert", function (e) {
      if (e.target.id) {
        Cookies.set(e.target.id, "dismissed", { expires: 365 });
      }
    });
  });
});
