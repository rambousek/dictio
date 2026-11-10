/* Edit/admin-only tools: reports, user admin, import, history compare, logout.
   Loaded from layout.slim only when the edit or admin host is active -
   keep public-site code in dictio.js instead. */

$( document ).ready(function() {
  var videoExportPollTimer = null;
  var pendingUserDeletion = null;
  var userDeletionDialog = document.getElementById('user-delete-wordlists-dialog');

  var submitUserDeletion = function(login, wordlistAction) {
    var data = {login: login};
    if (wordlistAction) data.wordlist_action = wordlistAction;
    $.post('/users/delete', data, (response) => {
      if (response.success) {
        document.location.reload();
      } else if (response.needs_wordlist_choice && userDeletionDialog) {
        pendingUserDeletion = login;
        document.getElementById('user-delete-wordlists-message').textContent = response.msg;
        userDeletionDialog.showModal();
      } else {
        alert(response.msg);
      }
    });
  };

  var chooseUserDeletion = function(wordlistAction) {
    if (!pendingUserDeletion || !userDeletionDialog) return;
    var login = pendingUserDeletion;
    pendingUserDeletion = null;
    userDeletionDialog.close();
    submitUserDeletion(login, wordlistAction);
  };

  $('#user-delete-wordlists-cancel').on('click', function() {
    pendingUserDeletion = null;
    if (userDeletionDialog) userDeletionDialog.close();
  });
  $('#user-delete-wordlists-keep').on('click', function() {
    chooseUserDeletion('keep');
  });
  $('#user-delete-wordlists-delete').on('click', function() {
    chooseUserDeletion('delete');
  });
  if (userDeletionDialog) {
    userDeletionDialog.addEventListener('cancel', function() {
      pendingUserDeletion = null;
    });
  }

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
      document.querySelectorAll('.loading').forEach(el => el.classList.remove('loading'));
      if (current_count >= maxcount) {
        $('.load_next_report').hide();
      }
    });
  });

  $('#video-export-open').on('click', function() {
    document.getElementById('video-export-dialog').showModal();
  });

  $('#video-export-cancel').on('click', function() {
    document.getElementById('video-export-dialog').close();
  });

  $('#idsf-mode-switch .report-filter-switch-btn').on('click', function() {
    var mode = this.dataset.mode;
    var table = document.getElementById('report-results-table');
    $('#idsf-mode-switch .report-filter-switch-btn').each(function() {
      this.classList.toggle('active', this.dataset.mode === mode);
    });
    table.dataset.idsfMode = mode;
    if (mode !== 'plus') {
      document.querySelectorAll('.report-entry-select').forEach(function(checkbox) {
        checkbox.checked = false;
      });
    }
  });

  $('#video-export-start').on('click', function() {
    var form = document.getElementById('video-export-form');
    var dialog = document.getElementById('video-export-dialog');
    var status = document.getElementById('video-export-status');
    var startButton = document.getElementById('video-export-start');
    var cancelButton = document.getElementById('video-export-cancel');
    if (!form || startButton.disabled) return;

    var messages = form.dataset;
    var setStatus = function(message) {
      status.textContent = message;
      status.style.display = 'block';
    };
    var setBusy = function(busy) {
      startButton.disabled = busy;
      cancelButton.disabled = busy;
    };
    var fail = function(message) {
      clearInterval(videoExportPollTimer);
      setBusy(false);
      setStatus(message);
    };

    setBusy(true);
    setStatus(messages.messagePreparing);

    fetch(form.dataset.startUrl, {
      method: 'POST',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: new URLSearchParams(new FormData(form))
    })
      .then(function(response) {
        if (!response.ok) throw new Error('HTTP ' + response.status);
        return response.json();
      })
      .then(function(job) {
        setStatus(messages.messageProcessing);
        var tries = 0;
        videoExportPollTimer = setInterval(function() {
          tries += 1;
          if (tries > 600) {
            fail(messages.messageFailed);
            return;
          }

          fetch(form.dataset.statusUrl + job.id)
            .then(function(response) {
              if (!response.ok) throw new Error('HTTP ' + response.status);
              return response.json();
            })
            .then(function(result) {
              if (result.status === 'done') {
                clearInterval(videoExportPollTimer);
                setStatus(messages.messageReady);
                dialog.close();
                setBusy(false);
                window.location = form.dataset.downloadUrl + job.id;
              } else if (result.status !== 'running') {
                var errorMessage = result.error === 'size_limit' ? messages.messageSizeLimit :
                  (result.error === 'estimated_size_limit' ? messages.messageEstimatedSizeLimit :
                  (result.error === 'video_count_limit' ? messages.messageVideoCountLimit : messages.messageFailed));
                fail(errorMessage);
              }
            })
            .catch(function(error) {
              fail(messages.messageFailed + ' (' + error.message + ')');
            });
        }, 3000);
      })
      .catch(function(error) {
        fail(messages.messageFailed + ' (' + error.message + ')');
      });
  });

  // load all report results
  $('.load_rest_report').click(function() {
    var current_count = $('.report-row').length;
    var maxcount = $('.report-results').data('resultcount');
    var report_url = '/' + $('.load_next_report').data('dict') + '/reportlist/' + current_count + '/' + maxcount + window.location.search;
    console.log(report_url)
    $.get(report_url, function(response) {
      $('.report-results').append(response);
    }).always(function() {
      $('.load_next_report').hide();
      $('.load_rest_report').hide();
    });
  });

  // load more videoreport results
  $('.load_next_videoreport').click(function() {
    var current_count = $('.videoreport-row').length;
    var report_url = '/' + $('.load_next_videoreport').data('dict') + '/videoreportlist/' + current_count + '/15' + window.location.search;
    console.log(report_url)
    $.get(report_url, function(response) {
      $('.report-table').append(response);
    }).always(function() {
      // after adding
      // maybe hide button
      current_count = $('.videoreport-row').length;
      maxcount = $('.report-table').data('resultcount');
      if (current_count >= maxcount) {
        $('.load_next_videoreport').hide();
      }
    });
  });

  // user admin
  $('#show-new-user').click(function() {
    $('.user-info').not('.new-user').hide();
    $('.new-user').show();
    $(this).hide();
  });

  (function() {
    var search = $('#user-search');
    var results = $('#user-search-results');
    if (!search.length || !results.length) return;

    var timer = null;
    var request = null;
    var requestNumber = 0;
    search.on('input', function() {
      var query = $.trim(search.val());
      var currentRequest = ++requestNumber;
      clearTimeout(timer);
      if (request) request.abort();
      results.empty().prop('hidden', true);
      if (query.length < 2) return;

      timer = setTimeout(function() {
        request = $.getJSON('/wordlists/users', {query: query, include_current: 'true'})
          .done(function(users) {
            if (currentRequest !== requestNumber) return;
            if (!users.length) {
              $('<li>').text(results.data('no-results')).appendTo(results);
            } else {
              users.forEach(function(user) {
                var params = new URLSearchParams({user: user.login, search: query});
                if (new URLSearchParams(window.location.search).get('all') === '1') params.set('all', '1');
                var label = user.name ? user.login + ' — ' + user.name : user.login;
                $('<li>').append($('<a>', {
                  class: 'wordlist-user-result',
                  href: '/users?' + params.toString(),
                  text: label
                })).appendTo(results);
              });
            }
            results.prop('hidden', false);
          })
          .fail(function(_xhr, status) {
            if (status === 'abort' || currentRequest !== requestNumber) return;
            $('<li>').text(results.data('search-error')).appendTo(results);
            results.prop('hidden', false);
          });
      }, 180);
    });

    search.on('keydown', function(event) {
      if (event.key === 'Escape') results.empty().prop('hidden', true);
    });
  })();

  $('#show-new-wordlist').click(function() {
    $('#new-wordlist-form').show().find('[name=name]').trigger('focus');
    $(this).hide();
  });

  $('.wordlist-user-selection').each(function() {
    var form = $(this);
    var search = form.find('[data-user-search]');
    var results = form.find('[data-user-results]');
    var selected = form.find('[data-selected-users]');
    var isMultiple = form.data('user-selection') === 'multiple';
    var request = null;
    var requestNumber = 0;

    function addUser(login, name) {
      if (!login) return;
      var hiddenInputs = form.find('input[type="hidden"][name="shared_with[]"], input[type="hidden"][data-selected-login]');
      if (hiddenInputs.filter(function() { return this.value === login; }).length) return;
      if (!isMultiple) {
        hiddenInputs.remove();
        selected.empty();
      }

      $('<input>', {
        type: 'hidden',
        name: isMultiple ? 'shared_with[]' : 'new_owner_login',
        value: login,
        'data-selected-login': isMultiple ? null : ''
      }).appendTo(form);

      var label = name ? login + ' — ' + name : login;
      var chip = $('<span>', {class: 'wordlist-user-chip'}).text(label);
      if (isMultiple) {
        $('<button>', {
          type: 'button',
          class: 'wordlist-user-remove',
          text: '×',
          'aria-label': form.data('remove-label') + ' ' + login
        }).appendTo(chip).on('click', function() {
          form.find('input[type="hidden"][name="shared_with[]"]').filter(function() {
            return this.value === login;
          }).remove();
          chip.remove();
        });
      } else {
        $('<button>', {
          type: 'button',
          class: 'wordlist-user-remove',
          text: '×',
          'aria-label': form.data('remove-label')
        }).appendTo(chip).on('click', function() {
          form.find('[data-selected-login]').remove();
          chip.remove();
        });
      }
      selected.append(chip);
    }

    var existingLogins = form.find('input[type="hidden"][name="shared_with[]"]').map(function() {
      return this.value;
    }).get();
    form.find('input[type="hidden"][name="shared_with[]"]').remove();
    existingLogins.forEach(function(login) {
      addUser(login, '');
    });

    search.on('input', function() {
      var query = $.trim(search.val());
      var currentRequest = ++requestNumber;
      if (request) request.abort();
      results.empty();
      if (query.length < 2) return;

      request = $.getJSON('/wordlists/users', {query: query})
        .done(function(users) {
          if (currentRequest !== requestNumber) return;
          if (!users.length) {
            results.append($('<li>').text(form.data('no-results')));
            return;
          }
          users.forEach(function(user) {
            var label = user.name ? user.login + ' — ' + user.name : user.login;
            $('<button>', {
              type: 'button',
              class: 'wordlist-user-result',
              role: 'option',
              text: label
            }).on('click', function() {
              addUser(user.login, user.name);
              search.val('').trigger('focus');
              results.empty();
            }).appendTo($('<li>').appendTo(results));
          });
        })
        .fail(function(_xhr, status) {
          if (status !== 'abort' && currentRequest === requestNumber) {
            results.append($('<li>').text(form.data('search-error')));
          }
        });
    });
  });

  (function() {
    var search = $('#entry-id[data-entry-autocomplete]');
    var results = $('#wordlist-entry-suggestions');
    if (!search.length || !results.length) return;

    var timer = null;
    var request = null;
    var requestNumber = 0;
    search.on('input', function() {
      var value = search.val().toString();
      var lastComma = value.lastIndexOf(',');
      var prefix = lastComma >= 0 ? value.slice(0, lastComma + 1) : '';
      var query = $.trim(value.slice(lastComma + 1));
      var currentRequest = ++requestNumber;
      clearTimeout(timer);
      if (request) request.abort();
      results.empty().prop('hidden', true);
      search.attr('aria-expanded', 'false');
      if (query.length < 2) return;

      timer = setTimeout(function() {
        var url = '/' + encodeURIComponent(search.data('entry-dict')) +
          '/jsonsearch/text/' + encodeURIComponent(query) + '/0/10';
        request = $.getJSON(url)
          .done(function(response) {
            if (currentRequest !== requestNumber) return;
            var entries = Array.isArray(response.entries) ? response.entries : [];
            if (!entries.length) {
              $('<li>').text(results.data('no-results')).appendTo(results);
            } else {
              entries.forEach(function(entry) {
                var lemma = entry.lemma || {};
                var button = $('<button>', {
                  type: 'button',
                  class: 'wordlist-entry-result',
                  role: 'option'
                });
                if (search.data('entry-type') === 'sign' && lemma.video_front) {
                  var video = document.createElement('video');
                  video.className = 'wordlist-entry-result__video';
                  video.width = 177;
                  video.height = 142;
                  video.preload = 'metadata';
                  video.muted = true;
                  video.playsInline = true;
                  video.setAttribute('aria-hidden', 'true');
                  var source = document.createElement('source');
                  source.type = 'video/mp4';
                  source.src = 'https://files.dictio.info/video' + search.data('entry-dict') + '/' + lemma.video_front;
                  video.appendChild(source);
                  button.addClass('wordlist-entry-result--sign')
                    .append(video)
                    .append($('<span>').text(entry.id))
                    .on('mouseenter', function() {
                      video.play().catch(function() {});
                    })
                    .on('mouseleave', function() {
                      video.pause();
                      video.currentTime = 0;
                    });
                } else {
                  var title = lemma.title || '';
                  button.text(title ? entry.id + ' — ' + title : entry.id);
                }
                button.on('click', function() {
                  search.val((prefix ? prefix + ' ' : '') + entry.id).trigger('focus');
                  results.empty().prop('hidden', true);
                  search.attr('aria-expanded', 'false');
                  var form = search.closest('form')[0];
                  if (form.requestSubmit) {
                    form.requestSubmit();
                  } else {
                    form.submit();
                  }
                });
                $('<li>').append(button).appendTo(results);
              });
            }
            results.prop('hidden', false);
            search.attr('aria-expanded', 'true');
          })
          .fail(function(_xhr, status) {
            if (status === 'abort' || currentRequest !== requestNumber) return;
            $('<li>').text(results.data('search-error')).appendTo(results);
            results.prop('hidden', false);
            search.attr('aria-expanded', 'true');
          });
      }, 180);
    });

    search.on('keydown', function(event) {
      if (event.key === 'Escape') {
        results.empty().prop('hidden', true);
        search.attr('aria-expanded', 'false');
      }
    });
  })();

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
    user.organization = table.find('[name=organization]').val()
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
      submitUserDeletion(login, null);
    }
  });

  // history, compare edit
  $('a.compareedit').click(function() {
    var href = $(this).data('href');
    window.open(href+'&type=old', 'historyold');
    window.open(href+'&type=new', 'historynew');
    return false;
  })

  //import, gather data, start import
  $('#import-start').click(function() {
    let data = {
      srcdict: $('#srcdict').val(),
      targetdict: $('#targetdict').val(),
      dir: $('#import-dir').val(),
      files:[],
      not_createrel: $('#not_createrel').is(':checked'),
    };
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
