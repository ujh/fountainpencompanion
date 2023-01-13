$(function () {
  $(".alert-dismissible").on("closed.bs.alert", function (e) {
    if (e.target.id) {
      Cookies.set(e.target.id, "dismissed", { expires: 365 });
    }
  });
});
