$(function() {
  $('#currently-inked, #currently-inked-archive').find('select').select2();

  $('#currently_inked_inked_on, #currently_inked_archived_inked_on, #currently_inked_archived_on').datepicker({
    dateFormat: 'yy-mm-dd'
  });

  $('#currently-inked .actions .usage').bind('ajax:complete', function() {
    $(this).find('i').addClass('fa-bookmark-o').removeClass('fa-bookmark')
    $(this).attr("title", "Already recorded usage for today")
  })
})
