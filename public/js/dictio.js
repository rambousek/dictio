function do_translate() {
  var search = $('.search__wrapper #expression_trans').val();
  if (search != '') {
    var dict = $('.search__wrapper #translate-from').val();
    var target = $('.search__wrapper #translate-to').val();
    var url = '/'+dict+'/translate/'+target+'/text/'+search;
    var params = new Array();
    if ($('.search__wrapper [name=deklin]').prop('checked')) {
      params.push('deklin=on')
    }
    if (params.length > 0) {
      url += '?' + params.join('&')
    }
    window.location = url;
  }
}
function do_mobile_translate() {
  var search = $('.mobile-search__input-wrap input').val();
  if (search != '') {
    var dict = $('.mobile-search__source .mobile-search__selected').attr('value');
    var target = $('.mobile-search__target .mobile-search__selected').attr('value');
    //var target = $('.search__wrapper #translate-to').val();
    var url = '/'+dict+'/translate/'+target+'/text/'+search;
    var params = new Array();
    if ($('.search__wrapper [name=deklin]').prop('checked')) {
      params.push('deklin=on')
    }
    if (params.length > 0) {
      url += '?' + params.join('&')
    }
    window.location = url;
  }
}
function do_search() {
  var search = $('.search-alt__wrap #expression_search').val();
  if (search != '') {
    var dict = $('.search-alt__wrap #translate-from').val();
    var url = '/'+dict+'/search/text/'+search;
    var params = new Array();
    if ($('.search-alt__wrap [name=deklin]').prop('checked')) {
      params.push('deklin=on')
    }
    if ($('.search-alt__wrap [name=diak]').prop('checked')) {
      params.push('diak=on')
    }
    if ($('.search-alt__wrap [name=spojeni]').prop('checked')) {
      params.push('spojeni=on')
    }
    if (params.length > 0) {
      url += '?' + params.join('&')
    }
    window.location = url;
  }
}

$('.search__wrapper .btn--search').click(do_translate);
$('.search-alt__wrap .btn--search').click(do_search);

$('.search-alt__wrap #expression_search').keypress(function(event) {
    var keycode = (event.keyCode ? event.keyCode : event.which);
    if (keycode == '13') {
      do_search();
    }
});
$('.search__wrapper #expression_trans').keypress(function(event) {
    var keycode = (event.keyCode ? event.keyCode : event.which);
    if (keycode == '13') {
      do_translate();
    }
});
$('.mobile-search__input-wrap input').keypress(function(event) {
    var keycode = (event.keyCode ? event.keyCode : event.which);
    if (keycode == '13') {
      do_mobile_translate();
    }
});

$('.mobile-search__source ul li').click(function(event) {
  $('.mobile-search__source .mobile-search__selected').attr('value', $(this).attr('value'))
  $('.mobile-search__source .mobile-search__selected').text($(this).text())
  $('.mobile-search__select').removeClass('is-open');
});
$('.mobile-search__target ul li').click(function(event) {
  $('.mobile-search__target .mobile-search__selected').attr('value', $(this).attr('value'))
  $('.mobile-search__target .mobile-search__selected').text($(this).text())
  $('.mobile-search__select').removeClass('is-open');
});

/* clickable video */
$('.video-link').on('click', function(event) {
  event.preventDefault();
  window.location = $(this).data('url');
});

/* switch front/back video */
$('.btn-side').on('click', function(event) {
  $('.btn-side').removeClass('btn--secondary');
  $('.btn-front').addClass('btn--secondary');
  $('.video-top .video-side').show();
  $('.video-top .video-front').hide();
});
$('.btn-front').on('click', function(event) {
  $('.btn-front').removeClass('btn--secondary');
  $('.btn-side').addClass('btn--secondary');
  $('.video-top .video-front').show();
  $('.video-top .video-side').hide();
});


