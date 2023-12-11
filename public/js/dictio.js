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

function onLoadSearchResult() {
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

  /* load revcolloc */
  $('.revcolloc-headline').click(function(event) {
    $('#revcolloc').empty();
    $('.revcolloc-headline').addClass('waiting');
    var load_url = $('.revcolloc-headline').data('url');
    $.get(load_url, function(response) {
      $('#revcolloc').append(response);
      $('.revcolloc-headline').removeClass('waiting');
      $("#revcolloc .dropdown__item__name").click(function(e) {
        $(this).parent().hasClass("is-open") ? ($(this).next(".dropdown__item__detail").slideUp(200), $(this).parent().removeClass("is-open")) : ($(this).next(".dropdown__item__detail").slideDown(200), $(this).parent().addClass("is-open"))
      });
    });
  });

  /* load revderivat */
  $('.revderivat-headline').click(function(event) {
    $('#revderivat').empty();
    $('.revderivat-headline').addClass('waiting');
    var load_url = $('.revderivat-headline').data('url');
    $.get(load_url, function(response) {
      $('#revderivat').append(response);
      $('.revderivat-headline').removeClass('waiting');
      $("#revderivat .dropdown__item__name").click(function(e) {
        $(this).parent().hasClass("is-open") ? ($(this).next(".dropdown__item__detail").slideUp(200), $(this).parent().removeClass("is-open")) : ($(this).next(".dropdown__item__detail").slideDown(200), $(this).parent().addClass("is-open"))
      });
    });
  });

  /* load revkompozitum */
  $('.revkompozitum-headline').click(function(event) {
    $('#revkompozitum').empty();
    $('.revkompozitum-headline').addClass('waiting');
    var load_url = $('.revkompozitum-headline').data('url');
    $.get(load_url, function(response) {
      $('#revkompozitum').append(response);
      $('.revkompozitum-headline').removeClass('waiting');
      $("#revkompozitum .dropdown__item__name").click(function(e) {
        $(this).parent().hasClass("is-open") ? ($(this).next(".dropdown__item__detail").slideUp(200), $(this).parent().removeClass("is-open")) : ($(this).next(".dropdown__item__detail").slideDown(200), $(this).parent().addClass("is-open"))
      });
    });
  });
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
    if ($(this).data('url') && $(this).data('url') != "") {
      window.location = $(this).data('url');
    } else {
      loadSearchResult(this);
    }
  });


  /* add comment on notrans */
  $('.notranscomment').click(function(event) {
    console.log($(this))
    var text = $(this).siblings('textarea');
    var koment = text.val();
    var box = text.data('box');
    var dict = text.data('dict');
    var entryid = text.data('id');
    $.post('/'+dict+'/add_comment', {entry: entryid, box: box, text: koment}, (response) => {
      if (response.success) {
        location.reload();
      }
    });
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
    $('.load_next_search').addClass('waiting');
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
              var newli = '<li><a href="" data-dict="'+entry.dict+'" data-entryid="'+entry.id+'" onclick="return loadSearchResult(this)">'+entry.lemma.title+'</a>';
              if (response.is_edit) {
                newli += '<span class="trans__badge trans__badge__'+entry.dict+'" style="position: relative; margin-left: 5px">'; 
                newli += '<a class="edit" href="https://edit.dictio.info/editor'+entry.dict+'/?id='+entry.id+'">'+entry.dict+'-'+entry.id+'</a>';
              }
              newli += '</li>';
              $('.search-results-write').append(newli);
            }
            if ($('.search-results-sign').length) {
              // new sign entry
              var video_content = '<video class="video-link" width="100%" onmouseover="this.play()" onmouseout="this.pause()" loop="loop" data-dict="'+entry.dict+'" data-entryid="'+entry.id+'" poster="/thumb/video'+entry.dict+'/'+entry.lemma.video_front+'" muted="muted"><source src="https://files.dictio.info/video'+entry.dict+'/'+entry.lemma.video_front+'" type="video/mp4"/></video>';
              if (entry.media && entry.media.video_front && entry.media.video_front.orient) {
                video_content = '<span class="video-orient">'+entry.media.video_front.orient.charAt(0).toUpperCase()+'</span>' + video_content;
              }
              var video_controls = '<a href="/'+entry.dict+'/show/'+entry.id+'" class="video__link"><span class="icon icon--open-new-window"><svg class="icon__svg" xmlns:xlink="http://www.w3.org/1999/xlink"><use height="100%" width="100%" x="0" xlink:href="/img/icons.svg#open-new-window" y="0"></use></svg></span></a>';
              if (entry.lemma && entry.lemma.sw) {
                video_controls += '<span class="video__sign"><img src="/sw/signwriting.png?generator[sw]='+entry.lemma.sw[0]['_text']+'&generator[align]=top_left&generator[set]=sw10"/></span>';
              }
              var newdiv = '';
              if (response.is_edit) {
                newdiv += '<span class="trans__badge trans__badge__'+entry.dict+'" style="position: relative;">'; 
                newdiv += '<a class="edit" href="https://edit.dictio.info/editor'+entry.dict+'/?id='+entry.id+'">'+entry.dict+'-'+entry.id+'</a>';
              }
              newdiv += '<div style="width:70%"><div class="video video--small"><div class="video__content">'+video_content+'</div><div class="video__controls">'+video_controls+'</div></div</div>';
              $('.search-results-sign').append(newdiv);
            }
            current_count += 1;
          });
        }
      }).always(function() {
        // after adding
        $('.load_next_search').removeClass('waiting');
        // maybe hide button
        if (current_count >= total_results) {
          $('.load_next_search').hide();
        }
        //activate video links
        $('.video-link').on('click', function(event) {
          event.preventDefault();
          if ($(this).data('url') && $(this).data('url') != "") {
            window.location = $(this).data('url');
          } else {
            loadSearchResult(this);
          }
        });
      });
    }
  });

  // load more translate results
  $('.load_next_trans').click(function() {
    $('.load_next_trans').addClass('waiting');
    var current_count;
    current_count = $('.translate-results > div.translate-box').length;
    console.log(current_count);
    var search_path = $('.load_next_trans').data('search');
    var search_url = search_path.replace('/translate/', '/translatelist/') + '/' + current_count + '/9';
    console.log(search_url)
    $.get(search_url, function(response) {
      $('.translate-results').append(response);
    }).always(function() {
      // after adding
      // hide duplicate
      var rels = {};
      $('div.translate-box').each(function() {
        if (rels[$(this).data('relinfo')] == undefined) {
          rels[$(this).data('relinfo')] = 1;
        } else {
          rels[$(this).data('relinfo')] += 1;
        }
      });
      Object.entries(rels).forEach(([rel,count])=>{
        if (count > 1) {
          $('[data-relinfo='+rel+']:gt(0)').hide();
          $('[data-relinfo='+rel+']:eq(0) span.pluscount').html('+ ' + (count-1));
        }
      });
      // maybe hide button
      $('.load_next_trans').removeClass('waiting');
      current_count = $('.translate-results > div.translate-box').length;
      $('.translate-results').data('resultcount', $('.col[data-resultcount]').data('resultcount'));
      maxcount = $('.translate-results').data('resultcount');
      if (current_count >= maxcount) {
        $('.load_next_trans').hide();
      }
      if (maxcount == 0 || maxcount == "") {
        $('#no-search-results').show();
      }
      //activate video links
      $('.video-link').on('click', function(event) {
        event.preventDefault();
        window.location = $(this).data('url');
      });
    });
  });

  // load more report results
  $('.load_next_report').click(function() {
    var current_count = $('.report-row').length;
    var report_url = '/' + $('.load_next_report').data('dict') + '/reportlist/' + current_count + '/15' + window.location.search;
    console.log(report_url)
    $.get(report_url, function(response) {
      $('.report-results').append(response);
    }).always(function() {
      // after adding
      // maybe hide button
      current_count = $('.report-row').length;
      maxcount = $('.report-results').data('resultcount');
      if (current_count >= maxcount) {
        $('.load_next_report').hide();
      }
    });
  });

  // load more videoreport results
  $('.load_next_videoreport').click(function() {
    var current_count = $('.report-row').length;
    var report_url = '/' + $('.load_next_videoreport').data('dict') + '/videoreportlist/' + current_count + '/15' + window.location.search;
    console.log(report_url)
    $.get(report_url, function(response) {
      $('.report-table').append(response);
    }).always(function() {
      // after adding
      // maybe hide button
      current_count = $('.report-row').length;
      maxcount = $('.report-table').data('resultcount');
      if (current_count >= maxcount) {
        $('.load_next_videoreport').hide();
      }
    });
  });

  // search results, onload, load first
  if ($('.search-results-write li').length > 0 && $('.entry-content .detail-word').length == 0) {
    loadSearchResult($('.search-results-write li a')[0]);
  }
  if ($('.search-results-sign .video-link').length > 0 && $('.entry-content .detail__head').length == 0) {
    loadSearchResult($('.search-results-sign .video-link')[0]);
  }

  onLoadSearchResult();
});

// load search result entry
function loadSearchResult(ev) {
  var entryid = ev.getAttribute('data-entryid');
  var dict = ev.getAttribute('data-dict');
  $.get('/'+dict+'/searchentry/'+entryid, function(response) {
    $('.entry-content').html(response);
    $('.entry-content')[0].scrollIntoView();
    onLoadSearchResult();
  });
  return false;
}

// run translation on document load
$( document ).ready(function() {
  $('.load_next_trans').click();
});

// user admin
$( document ).ready(function() {
  $('.save-user').click(function() {
    var table = $(this).parents('.user-info');
    var user = {};
    user.login = table.find('[name=login]').val();
    if (table.find('[name=pass]').val() != '') {
      user.password = table.find('[name=pass]').val();
    } else {
      user.password = '';
    }
    user.name = table.find('[name=name]').val()
    user.email = table.find('[name=email]').val()
    user.autor = table.find('[name=autor]').val()
    user.copy = table.find('[name=copy]').val()
    user.zdroj = table.find('[name=zdroj]').val()
    if (table.find('[name=admin]').is(':checked')) {
      user.admin = true;
    } else {
      user.admin = false;
    }
    user.editor = [];
    user.revizor = [];
    user.lang = [];
    user.skupina = [];
    table.find('[name=editor] option:selected').each(function() {
      user.editor.push($(this).val());
    });
    table.find('[name=revizor] option:selected').each(function() {
      user.revizor.push($(this).val());
    });
    table.find('[name=skupina] option:selected').each(function() {
      user.skupina.push($(this).val());
    });
    table.find('[name=langs] option:selected').each(function() {
      user.lang.push($(this).val());
    });
    console.log(user)
    $.post('/users/save', {user: JSON.stringify(user)}, (response) => {
      if (response.success) {
        $(this).val('uloženo');
        if (table.hasClass('new-user')) {
          document.location.reload();
        }
      } else {
        alert(response.msg);
      }
    });
  });
  $('.delete-user').click(function() {
    if (confirm('opravdu smazat?')) {
      var table = $(this).parents('.user-info');
      var login = table.find('[name=login]').val();
      $.post('/users/delete', {login: login}, (response) => {
        if (response.success) {
          document.location.reload();
        } else {
          alert(response.msg);
        }
      });
    }
  });
});

// history, compare edit
$( document ).ready(function() {
  $('a.compareedit').click(function() {
    var href = $(this).data('href');
    window.open(href+'&type=old', 'historyold');
    window.open(href+'&type=new', 'historynew');
    return false;
  })
});

//import, gather data, start import
$( document ).ready(function() {
  $('#import-start').click(function() {
    let data = {srcdict: $('#srcdict').val(), targetdict: $('#targetdict').val(), dir: $('#import-dir').val(), files:[]}
    $('.import-file').each(function() {
      data.files.push({
        file: $(this).val(),
        label: $('.import-label[data-file="'+$(this).val()+'"]').val(),
        trans: $('.import-trans[data-file="'+$(this).val()+'"]').val(),
        autor: $('.import-autor[data-file="'+$(this).val()+'"]').val(),
        video: $('.import-video[data-file="'+$(this).val()+'"]').val(),
        zdroj: $('.import-zdroj[data-file="'+$(this).val()+'"]').val(),
        eid: $('.import-eid[data-file="'+$(this).val()+'"]').val(),
        orient: $('.import-orient[data-file="'+$(this).val()+'"]').val(),
      });
    });
    console.log(data);
    $.post('/importstart2', {data: data}, (response) => {
      console.log(response)
      window.location = '/importlog?logid='+response.logid;
    })
  })
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

var showhide_obj="";

    function showhide(id) {
       var e = document.getElementById(id);
       if(showhide_obj!="")
          showhide_obj.style.display="none";
       if(e.style.display == 'block')
          e.style.display = 'none';
       else
          e.style.display = 'block';
          e.video.style.currentTime = 0;
       showhide_obj=e;
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
          document.location = 'https://dictio.info';
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

function URLChange2 (param1,value1,param2,value2) {
    var queryParams = new URLSearchParams(window.location.search);      
    queryParams.set(param1, value1);
    queryParams.set(param2, value2);
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
