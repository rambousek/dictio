/* Editor code shared by the sign and write editors.
   Loaded from editor.slim before the dictionary-type file (sign.js / write.js).
   Only put code here that is IDENTICAL for both editor types. */

function create_comment_button(boxid, type) {
  if (type === undefined) {
    type = boxid;
  }

  var cont = Ext.create('Ext.container.Container', {
    layout: {
      type: 'vbox',
      width: 200
    },
    items: [
      { xtype: 'button',
        name: 'commentbutton',
        icon: '/editor/img/comments.png',
        text: locale[lang].comment,
        handler: function () {
          open_comments(boxid, type);
        }
      },
      { xtype: 'box',
        width: 200,
        name: 'lastcomment',
        cls: 'comment-box',
        hidden: true
      }
    ]
  });

  Ext.Ajax.request({
    url: '/' + dictcode + '/comments/' + g_entryid + '/' + type,
    method: 'get',
    success: function (response) {
      /* fill media info */
      var data = JSON.parse(response.responseText);
      console.log('load comments ' + new Date().getTime());

      if (data.comments.length > 0) {
        const firstComment = data.comments[data.comments.length - 1];
        console.log(firstComment);
        // Aktualizace obsahu
        const commentHTML =
          firstComment.user +
          (firstComment.assign ? ' → <strong>' + firstComment.assign + '</strong>' : '') +
          ': <br /><i>' + firstComment.text + '</i>';
        cont.query('[name=lastcomment]')[0].update(commentHTML);
        // Přidání třídy "solved", pokud je komentář vyřešen nebo zamítnut
        if (firstComment.solved || firstComment.rejected) {
          cont.query('[cls=comment-box]')[0].addCls('solved');
        }
        cont.query('[name=lastcomment]')[0].show();
      }
      // Změna textu tlačítka, pokud existuje více než jeden komentář
      if (data.comments.length > 1) {
        cont.query('[name=commentbutton]')[0].setText(locale[lang].opencomment);
      }
    }
  });
  return cont;
}

function open_comments(box, type) {
  var name = 'koment_' + Ext.id();

  function loadComments() {
    Ext.Ajax.request({
      url: '/' + dictcode + '/comments/' + entryid + '/' + type,
      method: 'get',
      success: function (response) {
        var data = JSON.parse(response.responseText);
        var commentsContainer = kwin.queryById('commentsContainer'); // Kontejner pro komentáře
        commentsContainer.removeAll(); // Odstraníme pouze existující komentáře

        // Projdeme a přidáme každý komentář do kontejneru
        for (let i = data.comments.length - 1; i >= 0; i--) {
          var newcom = Ext.create('Ext.Component', {
            width: 300,
            cls: (data.comments[i].solved || data.comments[i].rejected) ? 'comment-solved' : 'comment',
            html: '<span class="user">' + data.comments[i].user.charAt(0) + '</span><i>' + data.comments[i].user + (data.comments[i].assign ? ' → <strong>' + data.comments[i].assign + '</strong>' : '') + '<br />' + '<span class="com-date">' + data.comments[i].time + '</span></i>' + '<div class="comment-inner">' + data.comments[i].text + '</div>',
            name: 'commenthtml'
          });
          var cid = data.comments[i]['_id']; // ID komentáře
          var nrow = Ext.create('Ext.container.Container', {
            layout: { type: 'hbox' },
            items: [
              newcom,              
              { xtype: 'container',
                layout: { type: 'vbox' },
                items: [
                  { xtype: 'tbfill', height: 10},
                  { xtype: 'container',
                    layout: { type: 'hbox' },
                    items: [
                      { xtype: 'button', text: locale[lang].commentsave,
                        icon: '/editor/img/save2.png',
                        cidParam: cid, 
                        handler: function (btn) {
                          Ext.Ajax.request({
                            url: '/' + dictcode + '/save_comment/' + btn.cidParam,
                            method: 'post',
                            params: {
                              solved: btn.up().up().query('[name=solved]')[0].getValue(),
                              assign: btn.up().up().query('[name=user]')[0].getValue()
                            },
                            success: function (response) { loadComments(); } // Znovu načteme komentáře po uložení
                          });
                        }
                      },
                      { xtype: 'button', icon: '/editor/img/trash.png', cls: 'del',
                        cidParam: cid,
                        handler: function (btn) {
                          if (confirm(locale[lang].commentconfirm)) {
                            Ext.Ajax.request({
                              url: '/' + dictcode + '/del_comment/' + btn.cidParam,
                              method: 'get',
                              success: function (response) {
                                loadComments(); 
                              }
                            });
                          }
                        }
                      }
                    ]
                  },
                  { xtype: 'combo',
                    name: 'user', // tady by mělo být ASSIGN
                    queryMode: 'local',                    
                    store: new Ext.data.ArrayStore(
                      { fields: ['value'], data: entrydata['user_list'] }
                    ),
                    displayField: 'value',
                    valueField: 'value',
                    cls: 'transparent',
                    emptyText: locale[lang].commentassign,
                    width: 100, forceSelection: true,
                    value: data.comments[i].assign
                  },
                  { xtype: 'combo', name: 'solved',
                    forceSelection: true,
                    queryMode: 'local',
                    store: new Ext.data.ArrayStore(
                      { fields: ['value', 'label'],
                        data: [
                          ['', '---'],
                          ['solved', locale[lang].commentsolved],
                          ['rejected', locale[lang].commentreject],
                        ],
                      }
                    ),
                    displayField: 'label', valueField: 'value',
                    width: 100, editable: false,
                    cls: 'transparent',
                    value: data.comments[i].solved
                  },                  
                ]
              }
            ]
          });
          commentsContainer.add(nrow); // Přidáme komentář do kontejneru
        }
      }
    });
  }

  // Vytvoříme okno s formulářem pro nový komentář a kontejnerem pro komentáře
  var kwin = Ext.create('Ext.window.Window', {
    title: locale[lang].comments,
    height: 800,
    width: 420,
    layout: { type: 'vbox' },
    id: name,
    autoScroll: true,
    closable: false, 
    tools: [
        { xtype: 'button', icon: '/editor/delete.png', cls: 'del', 
          handler: function () { this.up('window').close(); }
        },
      ],
    items: [
      { xtype: 'container',
        itemId: 'commentsContainer', // Kontejner pro seznam komentářů
        layout: { type: 'vbox' }
      },
      { xtype: 'container',
        layout: { type: 'hbox' },
        cls: 'comment-nBox',
        items: [
          { xtype: 'textarea', name: 'newtext', width: 300, cls: 'comment-tArea' },
          { xtype: 'container',
            layout: { type: 'vbox' },
            items: [
              { xtype: 'tbfill', height: 10},
              { xtype: 'button', text: locale[lang].savechanges,
                icon: '/editor/img/save2.png',
                handler: function () {
                  Ext.Ajax.request({
                    url: '/' + dictcode + '/add_comment',
                    params: {
                      entry: entryid,
                      box: type,
                      text: kwin.query('[name=newtext]')[0].getValue(),
                      user: kwin.query('[name=user]')[0].getValue()
                    },
                    method: 'post',
                    success: function (response) {
                      loadComments(); // Znovu načteme komentáře po přidání nového komentáře
                      Ext.getCmp(box).query('[name=lastcomment]')[0].update(kwin.query('[name=newtext]')[0].getValue());  // aktualizace komentaru na strance?
                      Ext.getCmp(box).query('[name=lastcomment]')[0].show(); 
                      kwin.query('[name=newtext]')[0].setValue('');
                    }
                  });
                }
              },

              {
                xtype: 'combo', name: 'user', queryMode: 'local', emptyText: locale[lang].commentassign, cls: 'transparent', // tady by mělo být ASSIGN
                store: new Ext.data.ArrayStore(
                  { fields: ['value'], data: entrydata['user_list'] }
                ),
                displayField: 'value', valueField: 'value', width: 100
              },             
            ]
          }
        ]
      }      
    ]
  });

  loadComments(); // Poprvé načteme komentáře při otevření okna
  kwin.show();
  kwin.alignTo(box, "tr-tr");
  return kwin;
}

function add_video_fancybox() {
  $('.videofancybox').each(function () {
    if ($(this).find('source')[0] != undefined) {
      var vid = $(this).find('source[type="video/mp4"]').attr('src');
      $(this).on("click", function (e) {
        console.log(e)
        e.target.pause();
        var container = $('<div data-ratio="0.8" style="width:450px;"><video preload="none" controls="" width="450px" height="337px" poster="' + vid + '/thumb.jpg" autoplay=""><source type="video/mp4" src="' + vid + '"/></source></video></div>');
        $.fancybox.open({
          src: container,
          type: 'html',
          scrolling: 'no',
        });
      });
    }
  });
}

function track_change() {
  var items = Ext.getCmp('tabForm').getForm().getFields().items;
  for (var i = 0; i < items.length; i++) {
    var c = items[i];
    if (c.xtype == 'radiofield' || c.xtype == 'textfield' || c.xtype == 'combobox' || c.xtype == 'checkbox' || c.xtype == 'textarea') {
      if (!c.disabled && !c.hidden) {
        if (c.hasListeners.change == undefined || c.hasListeners.change == 0) {
          c.on('change', function (e) {
            log_changes(e);
            entry_update_show(true);
          });
        }
      }
    }
  }
  var buttons = Ext.getCmp('tabForm').query('[xtype=button]');
  for (var i = 0; i < buttons.length; i++) {
    var c = buttons[i];
    if (c.icon == '/editor/delete.png' || c.icon == '/editor/add.png' || c.name == 'stavbutton') {
      c.on('click', function (e) {
        log_changes(e);
        entry_update_show(true);
      });
    }
  }
}

function log_changes(element) {
  var change = '';
  var elparent = element.up('fieldset');
  console.log(element)
  console.log(elparent)
  if (element.xtype == 'button') {
    if (element.icon == '/editor/delete.png') {
      change = 'smazat ';
      if (element.ownerCt.container.id.includes('rellink')) change += 'vztah ';
      if (elparent.name == 'vyznam') {
        change += 'vyznam ' + elparent.query('component[name="meaning_id"]')[0].getValue();
      } else if (elparent.name == 'usageset') {
        change += 'priklad ' + elparent.query('component[name="usage_id"]')[0].getValue();
      } else {
        change += elparent.title;
      }
    }
    if (element.icon == '/editor/add.png') {
      change = 'pridat ' + elparent.title;
      if (element.name == 'relsadd') {
        change = 'pridat vztah ';
        change += 'vyznam ' + elparent.up('fieldset').query('component[name="meaning_id"]')[0].getValue();
      }
      if (elparent.id == 'vyznamy_box') {
        change = 'pridat vyznam ';
      }
      if (element.container.id.includes('uziti') && elparent.name == 'vyznam') {
        change = 'pridat priklad ';
        change += 'vyznam ' + elparent.query('component[name="meaning_id"]')[0].getValue();
      }
      if (element.container.id.includes('uziti') && elparent.name == 'usageset') {
        change = 'pridat preklad prikladu ' + elparent.query('component[name="usage_id"]')[0].getValue();
      }
    }
    if (element.name == 'stavbutton') {
      change = element.text;
      if (element.ownerCt.container.id.includes('rellink')) change += ' vztah';
      if (elparent.name == 'vyznam') {
        change += ' vyznam ' + elparent.query('component[name="meaning_id"]')[0].getValue();
      } else if (elparent.name == 'usageset') {
        change += ' priklad ' + elparent.query('component[name="usage_id"]')[0].getValue();
      } else {
        if (elparent.title != undefined) {
          change += ' ' + elparent.title;
        } else {
          change += ' ' + elparent.name;
        }
      }
    }
  } else {
    var elname = elparent.name;
    if (elname == 'vyznam') {
      change = 'zmena vyznam ' + elparent.query('component[name="meaning_id"]')[0].getValue();
    } else if (elname == 'usageset') {
      change = 'zmena priklad ' + elparent.query('component[name="usage_id"]')[0].getValue();
    } else {
      if (elparent.title != undefined) {
        change = 'zmena ' + elparent.title;
      } else {
        change = 'zmena ' + elname;
      }
    }
  }
  console.log(change)
  changes.push(change);
}

function change_stav(stavcont, novystav) {
  if (novystav == 'published') {
    stavcont.query('[name=stav]')[0].setValue('published');
    stavcont.query('[name=stavdisp]')[0].setValue(locale[lang].published);
    stavcont.query('[name=stavbutton]')[0].setText(locale[lang].hide);
    stavcont.query('[name=stavdisp]')[0].removeCls('stav-display-hidden'); // Nastavení třídy
    stavcont.query('[name=stavdisp]')[0].addCls('stav-display-published'); // Nastavení třídy
  } else {
    stavcont.query('[name=stav]')[0].setValue('hidden');
    stavcont.query('[name=stavdisp]')[0].setValue(locale[lang].hidden);
    stavcont.query('[name=stavbutton]')[0].setText(locale[lang].publish);
  }
}

function create_stav() {
  var stav = Ext.create('Ext.container.Container', {
    layout: { type: 'hbox' },
    name: 'stavcont',
    items: [
      { xtype: 'textfield', disabled: true, name: 'stav', value: 'hidden', hidden: true }, 
      { xtype: 'displayfield', value: locale[lang].hidden, name: 'stavdisp', cls: 'stav-display-hidden', width: 60 }, 
      { xtype: 'button', name: 'stavbutton', text: locale[lang].publish, width: 100,
        handler: function () {
          Ext.suspendLayouts();
          var par = this.up('[name=stavcont]');
          if (par.query('[name=stav]')[0].getValue() == 'published') {
            par.query('[name=stav]')[0].setValue('hidden');
            par.query('[name=stavdisp]')[0].setValue(locale[lang].hidden);
            par.query('[name=stavdisp]')[0].removeCls('stav-display-published'); // Nastavení třídy
            par.query('[name=stavdisp]')[0].addCls('stav-display-hidden'); // Nastavení třídy
            par.query('[name=stavbutton]')[0].setText(locale[lang].publish);
          } else {
            par.query('[name=stav]')[0].setValue('published');
            par.query('[name=stavdisp]')[0].setValue(locale[lang].published);
            par.query('[name=stavdisp]')[0].removeCls('stav-display-hidden'); // Nastavení třídy
            par.query('[name=stavdisp]')[0].addCls('stav-display-published'); // Nastavení třídy
            par.query('[name=stavbutton]')[0].setText(locale[lang].hide);
          }
          Ext.resumeLayouts(true);
        }
      }
    ]
  });
  return stav;
}

function create_copy_button(idstart) {
  var button = Ext.create('Ext.button.Button', {
    text: 'copyright',
    id: idstart + '_copy_button',
    handler: function () {
      Ext.getCmp(idstart + '_copybox').show();
    }
  });
  return button;
}

function create_vyznam_links(parentid) {  
  var name = 'rellink' + Ext.id();
  var transset = Ext.create('Ext.container.Container', {
    border: false,
    id: name,
    cls: 'rellinkset',
    name: 'rellinkset',
    layout: { type: 'vbox', align: 'left', },
    items: [
      { xtype: 'container',
        layout: { type: 'hbox' },
        items: [
          { xtype: 'combobox', name: 'type', queryMode: 'local', displayField: 'text', valueField: 'value', store: typeStore, forceSelection: true, autoSelect: true, editable: false, allowBlank: true, width: 110, cls: 'transparent',
            listConfig: 
              { getInnerTpl: function () 
                { return '<div class="{value}">{text}</div>'; }
              }
          }, 
          { xtype: 'panel', name: 'vztahtitle', cls: 'vztah-title', html: '', width: 130, height: 22, color: 'red' }, 
          { xtype: 'combobox', name: 'rellink', store: relationlist, displayField: 'title', valueField: 'id', editable: true, cls: 'transparent', emptyText: locale[lang].search_entry, queryMode: 'local', width: 200, opened: false,
            listeners: 
              { 'blur': function (combo) 
                { if ((!(Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_'))) && combo.getValue().startsWith(entryid + '-')) 
                  { Ext.Msg.alert('', locale[lang]['warn_same_entry']); }
                  var rellink = combo.getValue();
                  if (rellink.match(/^[0-9]*-[0-9]*/) == null) 
                    { var prevbox = Ext.getCmp(combo.id).up().query('component[name="vztahtitle"]')[0];
                      prevbox.update(rellink);
                      document.getElementById(prevbox.id + "-innerCt").classList.add('redtext');
                    } 
                  else 
                    { Ext.getCmp(name).query('component[name="row2"]')[0].hide(); }
                },
                'select': function (combo, record, index) 
                  { console.log('select')
                    console.log(parentid)
                    if (combo.getValue() != '') 
                      { console.log(combo.getValue());
                        combo.setRawValue(combo.getValue());
                        var type = Ext.getCmp(name).query('component[name="type"]')[0].getValue();
                        var target = dictcode;
                        if (type.startsWith('translation_')) 
                          { var tar = type.split('_'); 
                            target = tar[1];
                          }
                        //ajax load preview
                        Ext.Ajax.request(
                          { url: '/' + target + '/relationinfo',
                            params: { meaning_id: combo.getValue() },
                            method: 'get',
                            success: function (response) 
                              { var rinfo = response.responseText;
                                var prevbox = Ext.getCmp(combo.id).up().query('component[name="vztahtitle"]')[0];
                                if (rinfo.charAt(0) == 'T') 
                                  { var rtitle = rinfo.substring(2);
                                    prevbox.update(rtitle);
                                  }
                                if (rinfo.charAt(0) == 'V') 
                                  { var videoloc = rinfo.substring(2);
                                    prevbox.update('<div class="videofancybox" data-ratio="0.8" class="usage" style="width:120px; cursor: zoom-in;"><video width="80px" poster="https://www.dictio.info/thumb/video' + target + '/' + videoloc + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + target + '/' + videoloc + '"></source></video></div>')
                                    prevbox.setHeight(60);
                                  }
                                document.getElementById(prevbox.id + "-innerCt").classList.add('text-' + target)
                                document.getElementById(prevbox.id + "-innerCt").classList.remove('redtext')
                              } 
                          }
                        );
                        //ajax load linked relations
                        window.setTimeout(function () 
                          { console.log('refresh timeout');
                            Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function (item) { item.show() });
                            Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.hide() });
                          }, 60 * 1000);
                        Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function (item) { item.hide() });
                        Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.show() });
                        var set_rel = Ext.getCmp('tabForm').query('[name=usersetrel]')[0].getValue()
                        load_link_relations(target, combo, name, parentid, set_rel);
                      }
                  },
                'focus': function (field, e) { console.log('focus') },
                'expand': function (field, e) 
                  { console.log('expand')
                    //if (/^[0-9]+-[0-9]+$/.test(field.getValue()) == false && this.opened == false) {
                    if (Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_')) 
                      { var reltar = Ext.getCmp(name).query('component[name="type"]')[0].getValue().split('_')[1];
                        reload_rel(field.getValue(), field, reltar);
                      } 
                    else 
                      { reload_rel(field.getValue(), field, dictcode); }
                  },
                specialkey: function (field, e) 
                  { if (e.getKey() == e.ENTER) 
                    { // zpozdeni, protoze chvili trva, nez existuje layout pro seznam
                      setTimeout(function () 
                        { if (Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_')) 
                            { var reltar = Ext.getCmp(name).query('component[name="type"]')[0].getValue().split('_')[1];
                              reload_rel(field.getValue(), field, reltar);
                            } 
                          else { reload_rel(field.getValue(), field, dictcode); }
                        }, 100
                      );
                    }
                  }
              },
              tpl: new Ext.XTemplate( '<tpl for="."><div class="x-boundlist-item"><b>{title}: {number}:</b> <i>{def}</i><tpl if="front!=&quot;&quot;"><div cursor: hand;"><video width="80px" poster="https://www.dictio.info/thumb/video{target}/{front}" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video{target}/{front}"></video>{front}</div></tpl> <tpl if="loc!=&quot;&quot;"><div cursor: hand;"><video width="120px" poster="https://www.dictio.info/thumb/video{target}/{loc}" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video{target}/{loc}"></source></video>{loc}</div></tpl></div></tpl>' ),
            }, 
            create_stav(),
            { xtype: 'button', icon: '/editor/delete.png', cls: 'del', 
              handler: function () { Ext.getCmp(name).destroy(); } 
            }
        ]
      },  
      { xtype: 'container',
        name: 'row2',
        layout: { type: 'hbox' },
        items: [
          { xtype: 'textfield', name: 'notransuser', hidden: true }, 
          { xtype: 'checkbox', boxLabel: locale[lang].notrans, width: 200, name: 'notrans', 
            listeners: 
              { change: function () 
                { var ntuser = this.ownerCt.query('[name=notransuser]')[0];
                  if (this.checked) 
                    { if (ntuser.value == '' || ntuser.value == undefined) 
                      { ntuser.value = entrydata.user_info.login + ' ' + Ext.Date.format(new Date(), 'Y-m-d H:i:s'); }
                    } else { ntuser.value = ''; }
                }
              }
          }
        ]
      }
    ]
  });

  return transset;
}

