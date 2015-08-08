$("input:radio").on('click', function(){
  var classList = $(this).attr('class').split(/\s+/);
  $.each( classList, function(index, item){
    $("input:radio." + item).prop('checked', false);
  });
  $(this).prop('checked', true);
});
