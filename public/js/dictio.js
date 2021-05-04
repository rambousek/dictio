function do_translate() {
  var search = $('.search__wrapper #expression_trans').val();
  if (search != '') {
    var dict = $('.search__wrapper .translate-from').val();
    var target = $('.search__wrapper #translate-to').val();
    var type = 'text';
    if (($('.search__wrapper #expression_trans').data('codes_hand') != undefined && $('.search__wrapper #expression_trans').data('codes_hand') != '') || ($('.search__wrapper #expression_trans').data('codes_place') != undefined && $('.search__wrapper #expression_trans').data('codes_place') != '')) {
      type = 'key';
    }
    var url = '/'+dict+'/translate/'+target+'/'+type+'/'+search;
    window.location = url;
  }
}
function do_mobile_translate(target) {
  var searchParent = target.parents('.mobile-search')
  var search = searchParent.find('.mobile-search__input-wrap input').val();
  if (search != '') {
    var dict = searchParent.find('.mobile-search__source .mobile-search__selected').attr('value');
    var target = searchParent.find('.mobile-search__target .mobile-search__selected').attr('value');
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
  var dict = $('.search-alt__wrap .translate-from').val();
  var slovniDruh = $('.search-alt__wrap #slovni_druh_'+dict).val();
  if (search != '' || slovniDruh != '') {
    var type = 'text';
    if (($('.search-alt__wrap #expression_search').data('codes_hand') != undefined && $('.search-alt__wrap #expression_search').data('codes_hand') != '') || ($('.search-alt__wrap #expression_search').data('codes_place') != undefined && $('.search-alt__wrap #expression_search').data('codes_place') != '')) {
      type = 'key';
    }
    if (search == '') {
      var url = '/'+dict+'/search/'+type+'/_';
    } else {
      var url = '/'+dict+'/search/'+type+'/'+search;
    }
    if (slovniDruh != '') url += '?slovni_druh='+slovniDruh;
    window.location = url;
  }
}

function show_pos_list() {
  var dict = $('.search-alt__wrap .translate-from').val();
  $('.advanced-search .slovni_druh').hide();
  $('.advanced-search #slovni_druh_'+dict).show();
}
function change_pos_list() {
  var dict = $('.search-alt__wrap .translate-from').val();
  if ($('.advanced-search .slovni_druh:visible').length > 0) {
    $('.advanced-search .slovni_druh').hide();
    $('.advanced-search #slovni_druh_'+dict).show();
  }
}

$( document ).ready(function() {
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
      do_mobile_translate($(this));
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

  // advanced search
  $('#advanced-search-toggle').click(show_pos_list);
  $('.search-alt__wrap .select-items div').click(change_pos_list);

  /* switch direction translate */
  $('.search__switch').click(function(event) {
    var source = $('.search__wrapper .translate-from').val();
    var target = $('.search__wrapper #translate-to').val();
    $('.search__wrapper .translate-from').val(target).change();
    $('.search__wrapper .translate-from ~ .select-selected').html( $('.search__wrapper .translate-from option[value='+$('.search__wrapper .translate-from').val()+']').html() );
    $('.search__wrapper #translate-to').val(source).change();
    $('.search__wrapper #translate-to ~ .select-selected').html( $('.search__wrapper #translate-to option[value='+$('.search__wrapper #translate-to').val()+']').html() );
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

  /* hide more examples, write */
  $('.detail__block').each(function() {
    if ($(this).find('p.example').length > 2) {
      $(this).find('p.example:gt(1)').hide();
      $(this).find('.more-example').show();
      $(this).find('.more-example').click(function(event) {
        $(this).parent().find('.example').show();
        $(this).hide();
      });
    }
  });
  /* hide more translations, write */
  $('.translation-group-write').each(function() {
    if ($(this).find('p').length > 3) {
      $(this).find('p:gt(1)').hide();
      $(this).find('.more-trans').show();
      $(this).find('.more-trans').click(function(event) {
        $(this).parent().find('p').show();
        $(this).hide();
      });
    }
  });
  /* hide more translations, sign (synonym, antonym, examples) */
  $('.translation-group-sign').each(function() {
    if ($(this).find('div.col').length > 2) {
      $(this).find('div.col:gt(1)').hide();
      $(this).find('.more-trans').show();
      $(this).find('.more-trans').click(function(event) {
        $(this).parent().find('div.col').show();
        $(this).hide();
      });
    }
  });

  /* show keyboard */
  $('#expression_search').on('focus', function(event) {
    var dict = $('.search-alt__wrap .translate-from').val();
    if (['czj','spj','asl','is','ogs'].includes(dict)) {
      $('.search-alt__wrapper .keyboard').show();
      $('.search-alt').addClass('keyboard-target');
    }
  });
  $('#expression_trans').on('focus', function(event) {
    var dict = $('.search__wrapper .translate-from').val();
    if (['czj','spj','asl','is','ogs'].includes(dict)) {
      $('.search .keyboard').show();
      $('.search').addClass('keyboard-target');
    }
  });
  $('.search-alt .keyboard-images').on('click', function(event) {
    $('.search-alt__wrapper .keyboard').show();
    $('.search-alt').addClass('keyboard-target');
  });
  $('.search .keyboard-images').on('click', function(event) {
    $('.search .keyboard').show();
    $('.search').addClass('keyboard-target');
  });
  /* hide keyboard */
  $('.search-alt__wrapper .keyboard .keyboard-hide').on('click', function(event) {
    $('.search-alt__wrapper .keyboard').hide();
    $('.search-alt').removeClass('keyboard-target');
  });
  $('.search .keyboard .keyboard-hide').on('click', function(event) {
    $('.search .keyboard').hide();
    $('.search').removeClass('keyboard-target');
  });
  /* switch back from keyboard */
  $('.search-alt .select-items div').on('click', function(event) {
    var dict = $('.search-alt__wrap .translate-from').val();
    if (!(['czj','spj','asl','is','ogs'].includes(dict))) {
      $('.search-alt .expression').show();
      $('.search-alt .keyboard-images').hide();
      $('.keyboard').hide();
      $('.keyboard-target .expression').val('');
      $('.keyboard-target .expression').data('codes_hand', '');
      $('.keyboard-target .expression').data('codes_place', '');
      $('.keyboard-target .expression').data('codes_two', '');
      $('.keyboard-target .expression').data('places', '');
      $('.keyboard-target .expression').data('hands', '');
      $('.keyboard-target .expression').data('two', '');
      $('.js-key').removeClass('js-key-selected');
    }
  });
  $('.search .select-items div').on('click', function(event) {
    var dict = $('.search__wrapper .translate-from').val();
    if (!(['czj','spj','asl','is','ogs'].includes(dict))) {
      $('.search .expression').show();
      $('.search .keyboard-images').hide();
      $('.keyboard').hide();
      $('.keyboard-target .expression').val('');
      $('.keyboard-target .expression').data('codes_hand', '');
      $('.keyboard-target .expression').data('codes_place', '');
      $('.keyboard-target .expression').data('codes_two', '');
      $('.keyboard-target .expression').data('places', '');
      $('.keyboard-target .expression').data('hands', '');
      $('.keyboard-target .expression').data('two', '');
      $('.js-key').removeClass('js-key-selected');
    }
  });

  /* hide keyboard by default */
  $('.keyboard').hide();
  $('.keyboard-images').hide();
  if ($('.keyboard-target').length > 1) {
    $('.keyboard-target').removeClass('keyboard-target');
  }

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
      var codes_two = new Array();
      var hands = new Array()
      var places = new Array()
      var two = new Array();
      $('.keyboard-target .keyboard-images img').remove();
      $(this).parents('.keyboard').find('.js-key-selected').each(function() {
        if ($(this).parent().hasClass('buttons-hand')) {
          codes_hand = codes_hand.concat($(this).data('key').split(','));
          hands.push($(this).data('hand'));
          $('.keyboard-target .keyboard-images').append('<img data-type="hand" data-hand="'+$(this).data('hand')+'" src="/img/keys/Hand_'+$(this).data('hand')+'.png"/>');
        }
        if ($(this).parent().hasClass('buttons-place')) {
          codes_place = codes_place.concat($(this).data('key').split(','));
          places.push($(this).data('hand'));
          $('.keyboard-target .keyboard-images').append('<img data-type="place" data-hand="'+$(this).data('hand')+'" src="/img/keys/'+$(this).data('hand')+'.jpg"/>');
        }
        if ($(this).parent().hasClass('buttons-two')) {
          codes_two = codes_two.concat($(this).data('key').split(','));
          two.push($(this).data('hand'));
          $('.keyboard-target .keyboard-images').append('<img data-type="two" data-hand="'+$(this).data('hand')+'" src="/img/keys_dark/'+$(this).data('hand')+'.png"/>');
        }
      });
      $('.keyboard-target .expression').data('codes_hand', codes_hand.join(','));
      $('.keyboard-target .expression').data('codes_place', codes_place.join(','));
      $('.keyboard-target .expression').data('codes_two', codes_two.join(','));
      $('.keyboard-target .expression').data('hands', hands.join(','));
      $('.keyboard-target .expression').data('places', places.join(','));
      $('.keyboard-target .expression').data('two', two.join(','));
      if (codes_hand.length == 0 && codes_place.length == 0 && codes_two.length == 0) {
        $('.keyboard-target .keyboard-images').hide();
        $('.keyboard-target .expression').val('');
        $('.keyboard-target .expression').show();
      } else {
        $('.keyboard-target .expression').val(codes_hand.join(',')+'|'+codes_place.join(',')+'|'+codes_two.join(','));
        $('.keyboard-target .keyboard-images').show();
        $('.keyboard-target .expression').hide();

        //click on selected image to delete
        $('.keyboard-images img').on("click", function() {
          var path = '.keyboard-target .keyboard .buttons-'+$(this).data('type')+' button[data-hand='+$(this).data('hand')+']';
          $(path).trigger('click');
        });
      }
    });

    //delete all key
    $('.js-key-back').on('click', function (event) {
      $('.keyboard-target .keyboard-images').hide();
      $('.keyboard-target .expression').val('');
      $('.keyboard-target .expression').show();
      $('.keyboard-target .expression').data('codes_hand', '');
      $('.keyboard-target .expression').data('codes_place', '');
      $('.keyboard-target .expression').data('codes_two', '');
      $('.keyboard-target .expression').data('places', '');
      $('.keyboard-target .expression').data('hands', '');
      $('.keyboard-target .expression').data('two', '');
      $('.js-key').removeClass('js-key-selected');
    });

    // switch keyboard tabs
    $('.keyboard .buttons-place').hide();
    $('.keyboard .buttons-two').hide();
    $('.keyboard .keyboard-place').on('click', function() {
      $(this).parents('.keyboard').find('.buttons-place').show();
      $(this).parents('.keyboard').find('.buttons-hand').hide();
      $(this).parents('.keyboard').find('.buttons-two').hide();
    });
    $('.keyboard .keyboard-hand').on('click', function() {
      $(this).parents('.keyboard').find('.buttons-hand').show();
      $(this).parents('.keyboard').find('.buttons-place').hide();
      $(this).parents('.keyboard').find('.buttons-two').hide();
    });
    $('.keyboard .keyboard-two').on('click', function() {
      $(this).parents('.keyboard').find('.buttons-hand').hide();
      $(this).parents('.keyboard').find('.buttons-place').hide();
      $(this).parents('.keyboard').find('.buttons-two').show();
    });

    // if search string, select correct images
    if (($('.keyboard-target .expression').data('codes_hand') && $('.keyboard-target .expression').data('codes_hand') != '') || ($('.keyboard-target .expression').data('codes_place') && $('.keyboard-target .expression').data('codes_place') != '')) {
      $('.keyboard-target .keyboard-images').show();
      var codes_hand = $('.keyboard-target .expression').data('codes_hand');
      var codes_place = $('.keyboard-target .expression').data('codes_place');
      var codes_two = $('.keyboard-target .expression').data('codes_two');
      var hands = new Array();
      var places = new Array();
      var two = new Array();
      $('.keyboard-target .keyboard-images img').remove();
      $('.keyboard .buttons-hand button').each(function() {
        if (codes_hand.includes($(this).data('key'))) {
          hands.push($(this).data('hand'));
          $('.keyboard-target .keyboard-images').append('<img data-type="hand" data-hand="'+$(this).data('hand')+'" src="/img/keys/Hand_'+$(this).data('hand')+'.png"/>');
          $(this).addClass('js-key-selected');
        }
      });
      $('.keyboard .buttons-place button').each(function() {
        if (codes_place.includes($(this).data('key'))) {
          places.push($(this).data('hand'));
          $('.keyboard-target .keyboard-images').append('<img data-type="place" data-hand="'+$(this).data('hand')+'" src="/img/keys/'+$(this).data('hand')+'.jpg"/>');
          $(this).addClass('js-key-selected');
        }
      });
      $('.keyboard .buttons-two button').each(function() {
        if (codes_two.includes($(this).data('key'))) {
          two.push($(this).data('hand'));
          $('.keyboard-target .keyboard-images').append('<img data-type="two" data-hand="'+$(this).data('hand')+'" src="/img/keys_dark/'+$(this).data('hand')+'.png"/>');
          $(this).addClass('js-key-selected');
        }
      });
      $('.keyboard-target .expression').data('hands', hands.join(','));
      $('.keyboard-target .expression').data('places', places.join(','));
      $('.keyboard-target .expression').data('two', two.join(','));
      $('.keyboard-target .expression').hide();

      //click on selected image to delete
      $('.keyboard-images img').on("click", function() {
        var path = '.keyboard-target .keyboard .buttons-'+$(this).data('type')+' button[data-hand='+$(this).data('hand')+']';
        $(path).trigger('click');
      });
    }
  }

  // load more search results
  $('.load_next_search').click(function() {
    var total_results = $('.result-count').data('count');
    var current_count;
    if ($('.search-results-write').length) {
      current_count = $('.search-results-write > li').length;
    }
    if ($('.search-results-sign').length) {
      current_count = $('.search-results-sign > div').length;
    }
    console.log(current_count)
    if (current_count < total_results) {
      var search_path = $('.load_next_search').data('search');
      var dict = search_path.split('/')[1];
      var slovniDruh = $('.search-alt__wrap #slovni_druh_'+dict).val();
      var search_url = search_path.replace('/search/', '/jsonsearch/') + '/' + current_count + '/10?slovni_druh='+slovniDruh;
      $.get(search_url, function(response) {
        if (response.entries) {
          response.entries.forEach((entry) => {
            if ($('.search-results-write').length) {
              // new write entry
              $('.search-results-write').append('<li><a href="'+search_path+'/'+entry.id+'">'+entry.lemma.title+'</a></li>');
            }
            if ($('.search-results-sign').length) {
              // new sign entry
              var video_content = '<video class="video-link" width="100%" onmouseover="this.play()" onmouseout="this.pause()" loop="loop" data-url="'+search_path+'/'+entry.id+'" poster="/thumb/video'+entry.dict+'/'+entry.lemma.video_front+'" muted="muted"><source src="https://files.dictio.info/video'+entry.dict+'/'+entry.lemma.video_front+'" type="video/mp4"/></video>';
              if (entry.media && entry.media.video_front && entry.media.video_front.orient) {
                video_content = '<span class="video-orient">'+entry.media.video_front.orient.charAt(0).toUpperCase()+'</span>' + video_content;
              }
              var video_controls = '<a href="'+search_path+'/'+entry.id+'" class="video__link"><span class="icon icon--open-new-window"><svg class="icon__svg" xmlns:xlink="http://www.w3.org/1999/xlink"><use height="100%" width="100%" x="0" xlink:href="/img/icons.svg#open-new-window" y="0"></use></svg></span></a>';
              if (entry.lemma && entry.lemma.sw) {
                video_controls += '<span class="video__sign"><img src="/sw/signwriting.png?generator[sw]='+entry.lemma.sw[0]['_text']+'&generator[align]=top_left&generator[set]=sw10"/></span>';
              }
              $('.search-results-sign').append('<div style="width:70%"><div class="video video--small"><div class="video__content">'+video_content+'</div><div class="video__controls">'+video_controls+'</div></div</div>');
            }
            current_count += 1;
          });
        }
      }).always(function() {
        // after adding
        // maybe hide button
        if (current_count >= total_results) {
          $('.load_next_search').hide();
        }
        //activate video links
        $('.video-link').on('click', function(event) {
          event.preventDefault();
          window.location = $(this).data('url');
        });
      });
    }
  });

  // load more translate results
  $('.load_next_trans').click(function() {
    var current_count;
    current_count = $('.translate-results > div').length;
    console.log(current_count);
    var search_path = $('.load_next_trans').data('search');
    var search_url = search_path.replace('/translate/', '/translatelist/') + '/' + current_count + '/9';
    console.log(search_url)
    $.get(search_url, function(response) {
      $('.translate-results').append(response);
    }).always(function() {
      // after adding
      // maybe hide button
      current_count = $('.translate-results > div').length;
      maxcount = $('.translate-results').data('resultcount');
      if (current_count >= maxcount) {
        $('.load_next_trans').hide();
      }
      //activate video links
      $('.video-link').on('click', function(event) {
        event.preventDefault();
        window.location = $(this).data('url');
      });
    });
  });
});
// add class on scroll for mobile search
window.onscroll = function() {
  if ($('main.homepage').length == 0) {
    var navbar = document.getElementById("navbar");
    if (navbar) {
      var sticky = navbar.offsetTop;
      if ((window.pageYOffset-sticky)>64) {
        $('#navbar').addClass("sticky");
        $('#mobilespacetop').addClass("mobile-space-top")
      } else {
        $('#navbar').removeClass("sticky");
        $('#mobilespacetop').removeClass("mobile-space-top")
      }
    }
  }
}

// show hide element
    function showhide(id) {
       var e = document.getElementById(id);
       if(e.style.display == 'block')
          e.style.display = 'none';
       else
          e.style.display = 'block';
    }

function logout() {
  // HTTPAuth Logout code based on: http://tom-mcgee.com/blog/archives/4435
  try {
    // This is for Firefox
    $.ajax({
      // This can be any path on your same domain which requires HTTPAuth
      url: "/",
      username: "reset",
      password: "reset",
      // If the return is 401, refresh the page to request new details.
      statusCode: { 401: function() {
          document.location = 'https://beta.dictio.info';
        }
      }
    });
  } catch (exception) {
    // Firefox throws an exception since we didn't handle anything but a 401 above
    // This line works only in IE
    if (!document.execCommand("ClearAuthenticationCache")) {
      // exeCommand returns false if it didn't work (which happens in Chrome) so as a last
      // resort refresh the page providing new, invalid details.
      document.location = "https://reset:reset@" + document.location.hostname;
    }
  }
}

function URLChange (param,value) {
    var queryParams = new URLSearchParams(window.location.search);      
    queryParams.set(param, value);
    window.location.href = 'report?' + queryParams;
}
  
function URLAppend (param) {
    var queryParams = new URLSearchParams(window.location.search);
    var value = 'ano';      
    queryParams.set(param, value);
    window.location.href = 'report?' + queryParams;
}  
  
function URLRemove (param) {
    var queryParams = new URLSearchParams(window.location.search);      
    queryParams.delete(param)    
    window.location.href = 'report?' + queryParams;
}

function URLRemove2 (param1, param2) {
    var queryParams = new URLSearchParams(window.location.search);      
    queryParams.delete(param1)    
    queryParams.delete(param2)
    window.location.href = 'report?' + queryParams;
}