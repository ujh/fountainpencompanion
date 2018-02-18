$(function() {
  $('#currently-inked, #currently-inked-archive').find('select').select2();

  $('#currently_inked_inked_on, #currently_inked_archived_on').datepicker({
    dateFormat: 'yy-mm-dd'
  });
})
