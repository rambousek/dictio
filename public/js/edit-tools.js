/* Edit/admin-only tools: reports, user admin, import, history compare, logout.
   Loaded from layout.slim only when the edit or admin host is active -
   keep public-site code in dictio.js instead. */

$( document ).ready(function() {
  var videoExportPollTimer = null;

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

  $('#show-new-wordlist').click(function() {
    $('#new-wordlist-form').show().find('[name=name]').trigger('focus');
    $(this).hide();
  });

  $('#edit-wordlist-name').click(function() {
    var form = $('#wordlist-name-form');
    var isVisible = form.is(':visible');
    form.toggle(!isVisible);
    $(this).attr('aria-expanded', String(!isVisible));
    if (!isVisible) {
      form.find('[name=name]').trigger('focus');
    }
  });

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
