function do_translate() {
  let search_expr = $('.search__wrapper #expression_trans');
  let search = search_expr.val();
  let dict = $('.search__wrapper .translate-from').val();
  let target = $('.search__wrapper #translate-to').val();
  let slovniDruh = $('.search__wrapper .slovni_druh_'+target).val();
  let styl = $('.search__wrapper .stylpriznak_'+target).val();
  let oblast = $('.search__wrapper .oblast_'+target).val();
  if (search !== '' || slovniDruh !== '' || oblast !== '' || styl !== '') {
    let type = 'text';
    if ((search_expr.data('codes_hand') !== undefined && search_expr.data('codes_hand') !== '') ||
        (search_expr.data('codes_place') !== undefined && search_expr.data('codes_place') !== '')) {
      type = 'key';
    }
    let url;
    if (search !== '') {
      url = '/' + dict + '/translate/' + target + '/' + type + '/' + search;
    } else {
      url = '/' + dict + '/translate/' + target + '/' + type + '/_';
    }
    let moreParams = [];
    if (slovniDruh !== '') moreParams.push('slovni_druh=' + slovniDruh);
    if (styl !== undefined && styl !== '') moreParams.push('stylpriznak=' + styl);
    if (oblast !== undefined && oblast !== '') moreParams.push('oblast=' + oblast);
    if (moreParams.length > 0) url += '?' + moreParams.join('&');
    window.location = url;
  }
}
function do_mobile_translate(target) {
  let searchParent = target.parents('.mobile-search');
  let search = searchParent.find('.mobile-search__input-wrap input').val();
  if (search !== '') {
    let dict = searchParent.find('.mobile-search__source .mobile-search__selected').attr('value');
    let target = searchParent.find('.mobile-search__target .mobile-search__selected').attr('value');
    let url = '/'+dict+'/translate/'+target+'/text/'+search;
    let params = [];
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
  let expr_search =  $('.search-alt__wrap #expression_search');
  let search = expr_search.val();
  let dict = $('.search-alt__wrap .translate-from').val();
  let slovniDruh = $('.search-alt__wrap #slovni_druh_'+dict).val();
  let styl = $('.search-alt__wrap #stylpriznak_'+dict).val();
  let oblast = $('.search-alt__wrap #oblast_'+dict).val();
  if (search !== '' || slovniDruh !== '' || oblast !== '' || styl !== '') {
    let type = 'text';
    if ((expr_search.data('codes_hand') !== undefined && expr_search.data('codes_hand') !== '') ||
        (expr_search.data('codes_place') !== undefined && expr_search.data('codes_place') !== '')) {
      type = 'key';
    }
    let url;
    if (search === '') {
      url = '/'+dict+'/search/'+type+'/_';
    } else {
      url = '/'+dict+'/search/'+type+'/'+search;
    }
    let moreParams = [];
    if (slovniDruh !== '') moreParams.push('slovni_druh=' + slovniDruh);
    if (styl !== undefined && styl !== '') moreParams.push('stylpriznak=' + styl);
    if (oblast !== undefined && oblast !== '') moreParams.push('oblast=' + oblast);
    if (moreParams.length > 0) url += '?' + moreParams.join('&');
    window.location = url;
  }
}

function initializeSearchInteraction(inputId, buttonId, linkId) {
  const inputField = document.getElementById(inputId);
  const searchButton = document.getElementById(buttonId);
  const searchLink = document.getElementById(linkId);

  if (!inputField || !searchButton || !searchLink) {
      console.error('Required elements not found: input, button, or link');
      return;
  }

  // Při kliknutí na odkaz nastav znak '*' a simuluj kliknutí na tlačítko
  searchLink.addEventListener('click', (event) => {
      event.preventDefault(); // Zamezí navigaci odkazu
      inputField.value = '*'; // Nastaví znak '*' do input pole
      searchButton.click();  // Simuluje kliknutí na tlačítko hledání
  });
}

// Inicializace na straně klienta
document.addEventListener('DOMContentLoaded', function () {
  initializeSearchInteraction('expression_trans', 'trans-button', 'trans-link');
});

function show_pos_list() {
  let dict = $('.search-alt__wrap .translate-from').val();
  $('.advanced-search .slovni_druh').hide();
  $('.advanced-search .stylpriznak').hide();
  $('.advanced-search .oblast').hide();
  $('.advanced-search #slovni_druh_'+dict).show();
  $('.advanced-search #stylpriznak_'+dict).show();
  $('.advanced-search #oblast_'+dict).show();
}
function change_pos_list() {
  if ($('.advanced-search .slovni_druh:visible').length > 0) {
    show_pos_list();
  }
}
function show_advanced_trans() {
  let dict = $('.search__wrapper #translate-to').val();
  $('.advanced-trans .slovni_druh').hide();
  $('.advanced-trans .stylpriznak').hide();
  $('.advanced-trans .oblast').hide();
  $('.advanced-trans .slovni_druh_'+dict).show();
  $('.advanced-trans .stylpriznak_'+dict).show();
  $('.advanced-trans .oblast_'+dict).show();
}
function change_trans_pos_list() {
  if ($('.advanced-trans .slovni_druh:visible').length > 0) {
    show_advanced_trans();
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

  /* load reverse collocation/derivative/compound lists */
  ['revcolloc', 'revderivat', 'revkompozitum'].forEach(function(name) {
    $('.'+name+'-headline').click(function(event) {
      $('#'+name).empty();
      $('.'+name+'-headline').addClass('waiting');
      var load_url = $('.'+name+'-headline').data('url');
      $.get(load_url, function(response) {
        $('#'+name).append(response);
        $('.'+name+'-headline').removeClass('waiting');
        $('#'+name+' .dropdown__item__name').click(toggleDropdownItem);
      });
    });
  });

  addSearchLinks();
}

function toggleDropdownItem() {
  if ($(this).parent().hasClass('is-open')) {
    $(this).next('.dropdown__item__detail').slideUp(200);
    $(this).parent().removeClass('is-open');
  } else {
    $(this).next('.dropdown__item__detail').slideDown(200);
    $(this).parent().addClass('is-open');
  }
}

/* keyboard search: clear selected keys and entered codes */
function resetKeyboardInput() {
  let keyboard_expr = $('.keyboard-target .expression');
  keyboard_expr.val('');
  keyboard_expr.data('codes_hand', '');
  keyboard_expr.data('codes_place', '');
  keyboard_expr.data('codes_two', '');
  keyboard_expr.data('places', '');
  keyboard_expr.data('hands', '');
  keyboard_expr.data('two', '');
  $('.js-key').removeClass('js-key-selected');
}

/* keyboard search: show the image for a selected key */
function appendKeyImage(type, hand) {
  var src = {
    hand: '/img/keys/Hand_'+hand+'.png',
    place: '/img/keys/'+hand+'.jpg',
    two: '/img/keys_dark/'+hand+'.png'
  }[type];
  $('.keyboard-target .keyboard-images').append('<img data-type="'+type+'" data-hand="'+hand+'" src="'+src+'"/>');
}

/* keyboard search: click on selected image to delete */
function activateKeyImageDelete() {
  $('.keyboard-images img').on("click", function() {
    var path = '.keyboard-target .keyboard .buttons-'+$(this).data('type')+' button[data-hand='+$(this).data('hand')+']';
    $(path).trigger('click');
  });
}

$( document ).ready(function() {
  $('.search__wrapper .btn--search').click(do_translate);
  $('.search-alt__wrap .btn--search').click(do_search);

  $('.search-alt__wrap #expression_search').keypress(function(event) {
    var keycode = (event.keyCode ? event.keyCode : event.which);
    if (keycode === 13) {
      do_search();
    }
  });
  $('.search__wrapper #expression_trans').keypress(function(event) {
    var keycode = (event.keyCode ? event.keyCode : event.which);
    if (keycode === 13) {
      do_translate();
    }
  });
  $('.mobile-search__input-wrap input').keypress(function(event) {
    var keycode = (event.keyCode ? event.keyCode : event.which);
    if (keycode === 13) {
      do_mobile_translate($(this));
    }
  });

  $('.mobile-search__source ul li').click(function(event) {
    let search_expr = $('.mobile-search__source .mobile-search__selected');
    search_expr.attr('value', $(this).attr('value'))
    search_expr.text($(this).text())
    $('.mobile-search__select').removeClass('is-open');
  });
  $('.mobile-search__target ul li').click(function(event) {
    let search_expr = $('.mobile-search__target .mobile-search__selected');
    search_expr.attr('value', $(this).attr('value'))
    search_expr.text($(this).text())
    $('.mobile-search__select').removeClass('is-open');
  });

  // advanced search
  $('#advanced-search-toggle').click(show_pos_list);
  $('.search-alt__wrap .select-items div').click(change_pos_list);
  $('#advanced-trans-toggle').click(show_advanced_trans);
  $('.search__wrapper .select-items div').click(change_trans_pos_list);

  /* switch direction translate */
  $('.search__switch').click(function(event) {
    let source_expr = $('.search__wrapper .translate-from');
    let target_expr = $('.search__wrapper #translate-to');
    let source = source_expr.val();
    let target = target_expr.val();
    source_expr.val(target).change();
    $('.search__wrapper .translate-from ~ .select-selected').html( $('.search__wrapper .translate-from option[value=' + source_expr.val() + ']').html() );
    target_expr.val(source).change();
    $('.search__wrapper #translate-to ~ .select-selected').html( $('.search__wrapper #translate-to option[value=' + target_expr.val() + ']').html() );
    change_trans_pos_list();
  });

  /* clickable video (delegated so it also works for results loaded via AJAX) */
  $(document).on('click', '.video-link', function(event) {
    event.preventDefault();
    if ($(this).data('url') && $(this).data('url') !== "") {
      window.location = $(this).data('url');
    } else {
      loadSearchResult(this);
    }
  });


  /* show keyboard */
  $('#expression_search').on('focus', function(event) {
    var dict = $('.search-alt__wrap .translate-from').val();
    if (['czj','spj','asl','is','ogs','uzm'].includes(dict)) {
      $('.search .keyboard').hide();
      $('.search').removeClass('keyboard-target');
      $('.search-alt__wrapper .keyboard').show();
      $('.search-alt').addClass('keyboard-target');
    }
  });
  $('#expression_trans').on('focus', function(event) {
    var dict = $('.search__wrapper .translate-from').val();
    if (['czj','spj','asl','is','ogs'].includes(dict)) {
      $('.search-alt__wrapper .keyboard').hide();
      $('.search-alt').removeClass('keyboard-target');
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
    let dict = $('.search-alt__wrap .translate-from').val();
    if (!(['czj','spj','asl','is','ogs'].includes(dict))) {
      $('.search-alt .expression').show();
      $('.search-alt .keyboard-images').hide();
      $('.keyboard').hide();
      resetKeyboardInput();
    }
  });
  $('.search .select-items div').on('click', function(event) {
    let dict = $('.search__wrapper .translate-from').val();
    if (!(['czj','spj','asl','is','ogs'].includes(dict))) {
      $('.search .expression').show();
      $('.search .keyboard-images').hide();
      $('.keyboard').hide();
      resetKeyboardInput();
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
      let codes_hand = [];
      let codes_place = [];
      let codes_two = [];
      let hands = [];
      let places = []
      let two = [];
      $('.keyboard-target .keyboard-images img').remove();
      $(this).parents('.keyboard').find('.js-key-selected').each(function() {
        if ($(this).parent().hasClass('buttons-hand')) {
          codes_hand = codes_hand.concat($(this).data('key').split(','));
          hands.push($(this).data('hand'));
          appendKeyImage('hand', $(this).data('hand'));
        }
        if ($(this).parent().hasClass('buttons-place')) {
          codes_place = codes_place.concat($(this).data('key').split(','));
          places.push($(this).data('hand'));
          appendKeyImage('place', $(this).data('hand'));
        }
        if ($(this).parent().hasClass('buttons-two')) {
          codes_two = codes_two.concat($(this).data('key').split(','));
          two.push($(this).data('hand'));
          appendKeyImage('two', $(this).data('hand'));
        }
      });
      let keyboard_expr = $('.keyboard-target .expression');
      keyboard_expr.data('codes_hand', codes_hand.join(','));
      keyboard_expr.data('codes_place', codes_place.join(','));
      keyboard_expr.data('codes_two', codes_two.join(','));
      keyboard_expr.data('hands', hands.join(','));
      keyboard_expr.data('places', places.join(','));
      keyboard_expr.data('two', two.join(','));
      if (codes_hand.length === 0 && codes_place.length === 0 && codes_two.length === 0) {
        $('.keyboard-target .keyboard-images').hide();
        keyboard_expr.val('');
        keyboard_expr.show();
      } else {
        keyboard_expr.val(codes_hand.join(',')+'|'+codes_place.join(',')+'|'+codes_two.join(','));
        $('.keyboard-target .keyboard-images').show();
        keyboard_expr.hide();
        activateKeyImageDelete();
      }
    });

    //delete all key
    $('.js-key-back').on('click', function (event) {
      $('.keyboard-target .keyboard-images').hide();
      $('.keyboard-target .expression').show();
      resetKeyboardInput();
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
          appendKeyImage('hand', $(this).data('hand'));
          $(this).addClass('js-key-selected');
        }
      });
      $('.keyboard .buttons-place button').each(function() {
        if (codes_place.includes($(this).data('key'))) {
          places.push($(this).data('hand'));
          appendKeyImage('place', $(this).data('hand'));
          $(this).addClass('js-key-selected');
        }
      });
      $('.keyboard .buttons-two button').each(function() {
        if (codes_two.includes($(this).data('key'))) {
          two.push($(this).data('hand'));
          appendKeyImage('two', $(this).data('hand'));
          $(this).addClass('js-key-selected');
        }
      });
      $('.keyboard-target .expression').data('hands', hands.join(','));
      $('.keyboard-target .expression').data('places', places.join(','));
      $('.keyboard-target .expression').data('two', two.join(','));
      $('.keyboard-target .expression').hide();
      activateKeyImageDelete();
    }
  }

  // load more search results
  $('.load_next_search').click(function() {
    $('.load_next_search').addClass('waiting');
    var total_results = $('.result-count').data('count');
    let current_count;
    if ($('.search-results-write').length) {
      current_count = $('.search-results-write > li').length;
    }
    if ($('.search-results-sign').length) {
      current_count = $('.search-results-sign > div').length;
    }
    if (current_count < total_results) {
      var search_path = $('.load_next_search').data('search');
      var dict = search_path.split('/')[1];
      var slovniDruh = $('.search-alt__wrap #slovni_druh_'+dict).val();
      var styl = $('.search-alt__wrap #stylpriznak_'+dict).val();
      var oblast = $('.search-alt__wrap #oblast_'+dict).val();
      let moreParams = [];
      if (slovniDruh != '') moreParams.push('slovni_druh=' + slovniDruh);
      if (styl != undefined && styl != '') moreParams.push('stylpriznak=' + styl);
      if (oblast != undefined && oblast != '') moreParams.push('oblast=' + oblast);
      let search_url = search_path.replace('/search/', '/jsonsearch/') + '/' + current_count + '/10';
      if (moreParams.length > 0) search_url += '?' + moreParams.join('&');
      $.get(search_url, function(response) {
        if (response.entries) {
          response.entries.forEach((entry) => {
            if ($('.search-results-write').length) {
              // new write entry
              let entry_title = ' ';
              if (entry.lemma && entry.lemma.title) {
                entry_title = entry.lemma.title;
              }
              var newli = '<li><a href="" data-dict="'+entry.dict+'" data-entryid="'+entry.id+'" onclick="return loadSearchResult(this)">'+entry_title+'</a>';
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
                video_controls += '<span class="video__sign"><img src="https://sign.dictio.info/fsw/sign/png/'+entry.lemma.sw[0]['@fsw']+'-CG_white_"/></span>';
              }
              var newdiv = '';
              if (response.is_edit) {
                newdiv += '<span class="trans__badge trans__badge__'+entry.dict+'" style="position: relative;">'; 
                newdiv += '<a class="edit" href="https://edit.dictio.info/editor'+entry.dict+'/?id='+entry.id+'">'+entry.dict+'-'+entry.id+'</a></span>';
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
      });
    }
  });

  // load more translate results
  $('.load_next_trans').click(function() {
    let trans_button = $('.load_next_trans');
    trans_button.addClass('waiting');
    let current_count;
    current_count = $('.translate-results > div.translate-box').length;
    let search_path = trans_button.data('search');
    let search_url = search_path.replace('/translate/', '/translatelist/') + '/' + current_count + '/9';
    if (trans_button.data('urlparams') != '') {
      search_url += '?' + trans_button.data('urlparams');
    }
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
      let result_expr = $('.translate-results');
      result_expr.data('resultcount', $('.col[data-resultcount]').data('resultcount'));
      let maxcount = result_expr.data('resultcount');
      if (current_count >= maxcount) {
        $('.load_next_trans').hide();
      }
      if (maxcount === 0 || maxcount === "") {
        $('#no-search-results').show();
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

  // run translation on document load
  $('.load_next_trans').click();
});

// load search result entry
function loadSearchResult(ev) {
  let entryid = ev.getAttribute('data-entryid');
  let dict = ev.getAttribute('data-dict');
  let url = ev.getAttribute('href');
  window.history.pushState({}, '', url); //add entry url to browser history
  $.get('/'+dict+'/searchentry/'+entryid, function(response) {
    $('.entry-content').html(response);
    let el_cite = $('.entry-content #citeInfo');
    if (el_cite) {
      $('footer #citeInfo').remove();
      el_cite.data('cite-text',
          el_cite.data('cite-text')
              .replace(/https:\/\/www.dictio.info\/.*searchentry\/[0-9]+/, 'https://www.dictio.info' + window.location.pathname)
      );
      el_cite.detach().appendTo('footer');
    }
    $('.entry-content')[0].scrollIntoView();
    onLoadSearchResult();
    // update window title
    let title = $('#search-title-meta title');
    if (title && title.html() != '') {
      document.title = title.html();
    }
    // update share url
    $('.showlink_public').val('https://www.dictio.info' + url);
    $('.showlink_edit').val('https://edit.dictio.info' + url);
  });
  return false;
}

// change /show/ link to /search/ url
function addSearchLinks() {
  let orig_url = window.location.pathname;
  let orig_url_ar = orig_url.split('/');
  if (!orig_url.includes('/show/')) {
    $('.add-search-link,.video-link').each(function () {
      if (this.getAttribute('href') != '' && this.getAttribute('href').includes('/show/')) {
        let link_ar = this.getAttribute('href').split('/');
        let new_url_ar = [...orig_url_ar];
        new_url_ar[1] = link_ar[1];
        new_url_ar[5] = link_ar[3];
        let new_url = new_url_ar.join('/');
        this.setAttribute('href', new_url + window.location.search);
        this.setAttribute('data-dict', link_ar[1]);
        this.setAttribute('data-entryid', link_ar[3]);
        if (!$(this).hasClass('video-link')) {
          this.setAttribute('onclick', 'return loadSearchResult(this)');
        }
      }
    })
  }
}

// add class on scroll for mobile search
window.onscroll = function() {
  if ($('main.homepage').length === 0) {
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

function citaceGen() { /* funkce předávající hodnoty ze stránky pro citace */
  document.getElementById("modalText").innerHTML = $('footer #citeInfo').data('cite-text');
  document.getElementById("modal").style.display = "flex";
}

function kopirovatText() {
  const textElement = document.getElementById("modalText");
  const copyButton = document.getElementById("copyButton");

  if (!textElement || !copyButton) return;

  const textToCopy = textElement.innerText || textElement.textContent;

  navigator.clipboard.writeText(textToCopy)
    .then(() => {
      // změna textu tlačítka
      copyButton.textContent = "Zkopírováno do schránky";
      copyButton.disabled = true; // volitelně – deaktivace tlačítka

      // po 3 sekundách vrátit původní text
      setTimeout(() => {
        copyButton.textContent = "Zkopírovat do schránky";
        copyButton.disabled = false;
      }, 10000);
    })
}

function zavriModal() {
  document.getElementById("modal").style.display = "none";
}
