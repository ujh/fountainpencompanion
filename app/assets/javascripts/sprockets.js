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
//= require jquery
//= require jquery_ujs
//= require jquery-ui
//= require select2
//= require_tree .

$(function () {
  $(".admin-macro-cluster-row, .admin-micro-cluster-row").on(
    "ajax:success",
    function () {
      location.reload();
    }
  );
});

$(function () {
  $(".video").on("ajax:success", function () {
    $(this).hide();
  });
});

$(function () {
  $(".blog-alert").on("closed.bs.alert", function () {
    console.log(this);
    var url = "/reading_statuses/" + $(this).data("id");
    console.log(url);
    function csrfToken() {
      var tokenElement = document.querySelector("meta[name='csrf-token']");
      return tokenElement ? tokenElement.getAttribute("content") : null;
    }
    fetch(url, { method: "PUT", headers: { "X-CSRF-Token": csrfToken() } });
  });
});

$(function () {
  var ink_review_submission_form = $("#new_ink_review_submission");
  ink_review_submission_form.on("ajax:success", () => {
    ink_review_submission_form.find("input").val("");
    ink_review_submission_form
      .find(".form-text")
      .text("URL successful submitted!");
  });
});
