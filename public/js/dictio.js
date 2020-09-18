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
    var type = 'text';
    if ($('.search-alt__wrap #expression_search').data('codes_hand') != undefined && $('.search-alt__wrap #expression_search').data('codes_hand') != '') {
      type = 'key';
    }
    var url = '/'+dict+'/search/'+type+'/'+search;
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

/* show keyboard */
$('#expression_search').on('focus', function(event) {
  var dict = $('.search-alt__wrap #translate-from').val();
  if (['czj','spj','asl','is','ogs'].includes(dict)) {
    $('.search-alt__wrapper .keyboard').show();
    $('.search-alt').addClass('keyboard-target');
  }
});
$('.search-alt .keyboard-images').on('click', function(event) {
  var dict = $('.search-alt__wrap #translate-from').val();
  $('.search-alt__wrapper .keyboard').show();
  $('.search-alt').addClass('keyboard-target');
});
/* hide keyboard */
$('.search-alt__wrapper .keyboard .keyboard-hide').on('click', function(event) {
  $('.search-alt__wrapper .keyboard').hide();
  $('.search-alt').removeClass('keyboard-target');
});

/* hide keyboard by default */
$('.keyboard').hide();
$('.keyboard-images').hide();
    $('.search-alt').addClass('keyboard-target');

if ($('.keyboard').length) {
  $('.js-key').on('click', function (event) {
    event.preventDefault();
    // switch class
    if ($(this).data('hand')) {
      if ($(this).hasClass('js-key-selected')) {
        $(this).removeClass('js-key-selected');
      } else {
        $(this).addClass('js-key-selected');
      }
    }

    // display images and collect codes
    var codes_hand = new Array();
    var codes_place = new Array();
    var hands = new Array()
    var places = new Array()
    $('.keyboard-target .keyboard-images img').remove();
    $(this).parents('.keyboard').find('.js-key-selected').each(function() {
      if ($(this).parent().hasClass('buttons-hand')) {
        codes_hand = codes_hand.concat($(this).data('key').split(','));
        hands.push($(this).data('hand'));
        $('.keyboard-target .keyboard-images').append('<img src="http://www.dictio.info/media/search/images/Hand_'+$(this).data('hand')+'.png"/>');
      }
      if ($(this).parent().hasClass('buttons-place')) {
        codes_place = codes_place.concat($(this).data('key').split(','));
        places.push($(this).data('hand'));
        $('.keyboard-target .keyboard-images').append('<img src="http://www.dictio.info/media/search/images/'+$(this).data('hand')+'.jpg"/>');
      }
    });
    $('.keyboard-target .expression').val(codes_hand.join(',')+'|'+codes_place.join(','));
    $('.keyboard-target .expression').data('codes_hand', codes_hand.join(','));
    $('.keyboard-target .expression').data('codes_place', codes_place.join(','));
    $('.keyboard-target .expression').data('hands', hands.join(','));
    $('.keyboard-target .expression').data('places', places.join(','));
    $('.keyboard-target .keyboard-images').show();
  });

  $('.keyboard .buttons-place').hide();
  $('.keyboard .keyboard-place').on('click', function() {
    $(this).parents('.keyboard').find('.buttons-place').show();
    $(this).parents('.keyboard').find('.buttons-hand').hide();
  });
  $('.keyboard .keyboard-hand').on('click', function() {
    $(this).parents('.keyboard').find('.buttons-hand').show();
    $(this).parents('.keyboard').find('.buttons-place').hide();
  });
}
