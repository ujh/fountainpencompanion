$(function () {
  $("#cookie-alert").on("closed.bs.alert", function () {
    Cookies.set("cookie-alert", "dismissed", { expires: 365 });
  });
});
