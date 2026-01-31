// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require_tree .

document.addEventListener("DOMContentLoaded", function () {
  // Admin cluster rows - reload page on successful AJAX
  document
    .querySelectorAll(".admin-macro-cluster-row, .admin-micro-cluster-row")
    .forEach(function (el) {
      el.addEventListener("ajax:success", function () {
        location.reload();
      });
    });

  // Video elements - hide on successful AJAX
  document.querySelectorAll(".video").forEach(function (el) {
    el.addEventListener("ajax:success", function () {
      this.style.display = "none";
    });
  });

  // Blog alerts - mark as read when dismissed
  document.querySelectorAll(".blog-alert").forEach(function (el) {
    el.addEventListener("closed.bs.alert", function () {
      console.log(this);
      var url = "/reading_statuses/" + this.dataset.id;
      console.log(url);
      function csrfToken() {
        var tokenElement = document.querySelector("meta[name='csrf-token']");
        return tokenElement ? tokenElement.getAttribute("content") : null;
      }
      fetch(url, { method: "PUT", headers: { "X-CSRF-Token": csrfToken() } });
    });
  });

  // Ink review submission form - clear on success
  var ink_review_submission_form = document.getElementById("new_ink_review_submission");
  if (ink_review_submission_form) {
    ink_review_submission_form.addEventListener("ajax:success", function () {
      ink_review_submission_form.querySelectorAll("input").forEach(function (input) {
        input.value = "";
      });
      var formText = ink_review_submission_form.querySelector(".form-text");
      if (formText) {
        formText.textContent = "URL successful submitted!";
      }
    });
  }
});
