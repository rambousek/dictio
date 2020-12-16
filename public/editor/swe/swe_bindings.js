$.namespace("sw", {
    inherited: true,
    /* helper function to fade and remove an element; callback is called when removed
     */
    fadeRemove: function() {
        $(this).fadeOut( "normal", function() {
            $(this).remove();
            $().sw.callback('glyphogramChanged');
        });
    }, ///



    /* adjusting the size of the symbol table
     */
    adjustEditorSize: function() { 
        page = $(document).find(".swe-symbol-group")[current];
        $("#swe-editor").animate({
              width: $(page).width(),
              height: $(page).height()
        }, 1000 );
    }, ///



    /* when the created glyphogram is moved into the editor, we have to bind all the functions so that it is possible to reedit it
     */
    addSymbolsToReedit: function() {
        $(this).children()
                .show()
                .unbind()
                .removeClass("swe-symbol-not-move")
                .addClass("swe-symbol")
                    .each( function() {
                    $().sw.getSymbolDefinition($(this).attr("name"));
                        $(this).sw.bindSymbolToMoveAroundEditor()
                                  .appendTo( "#swe-sign-view" );
                  });

        $("#swe-sign-view").sw.glyphogramObject( 'center' );
        $().sw.callback('glyphogramChanged');
        $(this).remove();
    }, ///



    /* setting all the drag & drop bindings for the actual editor
     */
    bindSignView: function() {
        $("#swe-sign-view")
            .bind( "dropstart", function( event ){
                // is this the right place to drop?
                if( this == event.dragTarget.parentNode )
                    return false;
                // activate the "drop" target element
                $( this ).addClass("swe-sign-view-selected");
                   $( event.dragProxy ).removeClass("swe-sign-to-delete");
                })
            .bind( "drop", function( event ){
                // placement of the dropped element

                if( $(event.dragProxy).hasClass("swe-symbol") ) {
                    // this is a single symbol
                     var offset = $("#swe-sign-view").offset();
                     $(event.dragProxy).css({
                         left: $(event.dragProxy).offset().left - offset.left,
                         top: $(event.dragProxy).offset().top - offset.top
                    });

                     $( this ).append( event.dragProxy );
                 } else {
                    // this is a sign to be reedited
                    if( event.dragTarget == event.dropTarget ) {
                        $(event.dropTarget).children().show();
                        $(event.dragProxy).remove();
                        return true;
                    }

                    if( $(event.dragProxy).hasClass("swe-sign-with-id") ) {
                        var name = $(event.dragTarget).attr("title");
                        var id = $(event.dragTarget).attr("name");

                        var query = $().sw.translate('reedit_dialog')+"<div class='jqiitem'>"+name+"</div>";

                        // popping a dialog "what to do with the sign"
                        var butts = new Object;
                        butts[$().sw.translate("reedit_thesign")] = 1;
                        butts[$().sw.translate("reedit_copy")] = 2;
                        butts[$().sw.translate("reedit_cancel")] = 0;
                        $.prompt( query, {
                            buttons: butts,
                            show: 'show',
                            focus: 2 ,
                            callback: function( v, m, f) {
                                if( v ) {
                                    // button ok
                                    if( v == 1 ) {
                                           $().sw.info( $().sw.translate('sign_with_id_being_edited') + " " + name, null );
                                        $("#swe-sign-view")
                                            .attr("title", name)
                                            .attr("name", id)
                                            .addClass("swe-sign-with-id");
                                    }
                                    $("#swe-sign-view").children().remove();
                                    $(event.dragProxy).sw.addSymbolsToReedit();
                                    if($(event.dragTarget).hasClass("swe-sign-on-paper"))
                                        $(event.dragTarget).remove();
                                   } else {
                                      // button cancel
                                      $(event.dragProxy).remove();
                                      $(event.dragTarget).show()
                                      return false;
                                }
                        }});
                    } else {
                        $(event.dragProxy).sw.addSymbolsToReedit();
                    }
                 }
                })
            .bind( "dropend", function( event ){
                // deactivate the "drop" target element
                $( this ).removeClass("swe-sign-view-selected");
                if( !event.dropTarget && !$(event.dragProxy).hasClass("swe-symbol") ) {
                    $( event.dragProxy ).addClass("swe-sign-to-delete");
                }
            })
            .attr( "title", $().sw.translate('dragsign') );
    }, ///



    /* common bindings for both sign in editor and search results to be moved
     */
    bindSign: function( dropBefore, dropAfter ) {
        $(this).bind('dragstart',function( event ) {

                // we don't want to drag empty signs
                if($(this).children().size() == 0 )
                    return false;

                // creating a new element which is being dragged
                var drag = $("<div>")
                            .addClass("swe-sign-in-move")
                            .html($(this).html())
                            .height($(this).height());

                // this is sign already in database, we have to be careful about editing it
                if( $(this).hasClass("swe-sign-with-id") ) {
                    drag.addClass("swe-sign-with-id");
                    drag.attr( "name", $(this).attr("name") );
                    drag.attr( "title", $(this).attr("title") );
                }

                if( dropBefore != null )
                    dropBefore( event );

                drag.appendTo( document.body )

                return drag;
            })
            .bind('drag',function( event ){
                $(event.dragProxy).css({
                      top: event.offsetY,
                      left: event.offsetX
                    });
                 })
            .bind('dragend',function( event ) {
                // on dragend we call the required callback
                dropAfter( event );
            });
    }, ///



    /* drag and drop bindings when full editor is run
     */
    bindFullEditor: function() {
        $(this).prepend( $("<div>").attr("id","swe-paper").addClass("drop-target") );

        // bindings to move the created symbol to the list
        $("#swe-sign-view").sw.bindSign( function( event ) {
                $(event.dragTarget).children().hide();
            }, function( event ) {
                $(event.dragTarget).removeClass("swe-sign-with-id");
                if( !event.dropTarget ) {
                    $(event.dragTarget).children().remove();
                    $(event.dragProxy).sw.fadeRemove();
                 } else {
                     if( event.dragTarget != event.dropTarget )
                          $(event.dragTarget).children().remove();
                      $(event.dragTarget).attr("title","").attr("name","");
                    $().sw.callback( 'glyphogramChanged' );
                }
             });

        // bind the "swe-paper" on the left as a dropbox as well to accept created symbols
        $("#swe-paper")
            .sw.adjustHeight()
            .bind( "dropstart", function( event ) {
                // is this the right place to drop?
                if( $(event.dragProxy).hasClass("swe-symbol") )
                    return false;

                // activate the "drop" target element
                   $( this ).addClass("swe-sign-view-selected");
                   $( event.dragProxy ).removeClass("swe-sign-to-delete");
            })
            .bind( "drop", function( event ){
                  $().sw.info( '', null );
                name = $(event.dragTarget).attr("name");
                title = $(event.dragTarget).attr("title");
                if( $(event.dragTarget).attr("name") == null ) {
                    title = "";
                    name = "";
                 }

                 var glyphogram = $("<div>").addClass("swe-sign-on-paper").attr("name",name).attr("title",title);

                $(event.dragProxy).children().each( function() {
                    var pos = $(this).position();
                    $("<span>").addClass("swe-symbol-not-move")
                         .attr("name", $(this).attr("name"))
                         .css({
                            backgroundImage: $(this).css("background-image"),
                            top: pos.top,
                            left: pos.left})
                         .appendTo( glyphogram );
                });

                $(glyphogram).sw.glyphogramObject( 'removeVertical' );

                // this sign is already in database, we have to be careful about editing it
                if( $(event.dragProxy).hasClass("swe-sign-with-id") ) {
                    $(glyphogram).addClass("swe-sign-with-id");
                }

                $(event.dragProxy).remove();

                $(glyphogram).sw.phraseGlyphogramStaticBind();

                $(this).append( glyphogram );

                // after adding the symbol, we scroll to bottom
                $(this).animate({scrollTop: $(this)[0].scrollHeight -  $(this).height() - 100}, 1000);
                $().sw.callback( 'bothChanged' );
            })
            .bind( "dropend", function( event ){
                // deactivate the "drop" target element
                   $( this ).removeClass("swe-sign-view-selected");
                   $( event.dragProxy ).addClass("swe-sign-to-delete");
                $().sw.callback('phraseChanged');
             });
    }, ///



    /* bindings for the symbols on the paper (in the phrase)
     */
    phraseGlyphogramStaticBind: function() {
         $(this).sw.bindSign( function( event ) {
            $(event.dragTarget).hide();
        }, function( event ) {
            $(event.dragTarget).remove();
                 if(!event.dropTarget ) {
                         $(event.dragProxy).sw.fadeRemove();
                    } else {
                     // $(event.dragProxy).remove();
                 }
            });
    },



    /* function handles position of symbols in the editor depending on 'what'
        *center*: centers the symbol in the 200x200 field
        *removeVertical*: centers the symbol and removes trailing vertical space
        *undefined*: computes the sw.glyphogram variable
     */
    glyphogramObject: function( what ) {
        var ymin = 200, ymax = 0, xmin = 200, xmax = 0;

            $(this).children().each( function() {
//          couldn't get this to work correctly: var pos = $(this).position();
            var pos_y = parseInt( $(this).css("top") );
                var pos_x = parseInt( $(this).css("left") );
                ymin = ymin > pos_y ? pos_y : ymin;
            ymax = ymax < pos_y ? pos_y : ymax;
                xmin = xmin > pos_x ? pos_x : xmin;
            xmax = xmax < pos_x ? pos_x : xmax;
        });

        glyphogram = {
            id: $(this).attr("name"),
            name: $(this).attr("title"),
            set: []
         }

        $(this).children().each( function() {
              var pos_y = parseInt( $(this).css("top") );
               var pos_x = parseInt( $(this).css("left") );

            centered_x = (pos_x - xmin + 100 - (xmax-xmin+30)/2);

               if( what == 'center' ) {
                $(this).css({
                    top: (100-(ymax+50)/2+pos_y)+'px',
                    left: centered_x+'px' });
            } else {
                centered_y = (pos_y - ymin + 10);
                if( what == 'removeVertical' )
                      $(this).css({ top: centered_y+'px', left: centered_x+'px' });
                else
                    glyphogram.set.push({ symbol_id: $(this).attr("name"), x: pos_x-xmin, y: pos_y-ymin });
            }
        });

        if( what == 'removeVertical' )
             $(this).css("height",ymax-ymin+50)

        return glyphogram;
    }, ///



    /* bind the symbol to move in the dialog */
    bindSymbolToMoveAroundEditor: function() {
        $(this).attr( "title", $().sw.translate('dragineditor') )
             .bind('dragstart',function(event) {
                 $(event.dragProxy).addClass("swe-symbol-dragged");
             })
             .bind('drag',function(event) {
                 var el = $(event.dragProxy);

                 var px = el.parent().offset().left;
                 var py = el.parent().offset().top;
                 var x = event.offsetX-px;
                 var y = event.offsetY-py;

                 // defining the boundaries of the editor
                 if( x < 0 || x > 170|| y < 0 || y > 170 )
                     $(event.dragProxy).addClass( "swe-sign-to-delete" );
                 else
                     $(event.dragProxy).removeClass( "swe-sign-to-delete" );

                 $(event.dragProxy).css({
                    top: Math.floor( event.offsetY/5 ) * 5 - py,
                    left: Math.floor( event.offsetX/5 ) * 5 - px
                 });

             })
             .bind('dragend',function( event ) {
                 if( $(event.dragProxy).hasClass( "swe-sign-to-delete" ) ) {
                     // symbol was dropped outside the editor -> delete it
                     $(event.dragProxy).sw.fadeRemove();
                 } else {
                     // dragging finished
                     $(event.dragProxy).removeClass("swe-symbol-dragged");
                     $(event.dragProxy).addClass("swe-symbol-selected");
                 }
                $().sw.callback('glyphogramChanged');
             })
            .bind( 'click', function() {
                 // selecting symbol (to rotate it, delete it, etc.)
                 var toSet = $(this).hasClass( "swe-symbol-selected" );

                 $(document).find(".swe-symbol-selected").removeClass("swe-symbol-selected");
                 $(document).find(".swe-symbol-on-paper-selected").removeClass("swe-symbol-on-paper-selected");

                 if( !toSet )
                     $(this).addClass("swe-symbol-selected");
             });
        return this;
    }, ///



    /* **TODO**: unused? */
    setSymbol: function( symbol_id, pos_x, pos_y ) {
        return $(this)
            .attr( "name", symbol_id )
             .css({
                backgroundImage: getSymbol( symbol_id ),
                left: pos_x,
                top: pos_y });
    }, ///



    /* internal callback*/
    callback: function( event ) {
        if( event == "glyphogramChanged" ) {
             sw.glyphogram = $("#swe-sign-view").sw.glyphogramObject();
        }

        if( event == "phraseChanged" ) {
            sw.phrase = [];
             $(document).find("#swe-paper div").each( function( position, glyphogram ) {
                word = $(glyphogram).sw.glyphogramObject();
                sw.phrase.push( word );
            });
        }

        sw.callback({
            glyphogram: sw.glyphogram,
            phrase: sw.phrase,
            event: event
        });
    }, ///



    /* placing glyphogram given in constructor */
    placeGlyphogram: function( glyphogram, type ) {

        if( typeof type == "undefined" )
            type = "default";

        container = $(this);

        $.each( glyphogram.set, function( key, symbol ) {
            if( !is_numeric( symbol.symbol_id ) ||
                  !is_numeric( symbol.x ) ||
                  !is_numeric( symbol.y ) )
                    return;

            s = $("<a>").css({
                        backgroundImage: "url("+$().sw.glyph( symbol.symbol_id )+")",
                        left: symbol.x+"px",
                        top: symbol.y+"px"
                    })
                    .attr( "name", symbol.symbol_id )
                    .appendTo(container);

            if( type == "static" )
                s.addClass( "swe-symbol-not-move" );
            else
                s.addClass("swe-symbol")

            if( type == "movable" )
                s.sw.bindSymbolToMoveAroundEditor();

            $().sw.getSymbolDefinition( symbol.symbol_id );
        });

        if( is_numeric( glyphogram.id ) && glyphogram.id > 0 ) {
            container.addClass("swe-sign-with-id").attr("name", glyphogram.id );
        }

        if( typeof glyphogram.name != "undefined" )
            container.attr( "title", glyphogram.name );

        $(container).sw.glyphogramObject( type == "static" ? "removeVertical" : "center" );

        if( type == "movable" )
            $().sw.callback( 'glyphogramChanged' );
    }, ///



    placePhrase: function( phrase ) {
        context = $(this);
         $.each( phrase, function( key, current ) {
            if( !is_numeric( current.id ) )
                current.id = "";
            if( isNaN( current.name ) )
                current.name = "";
              glyphogram = $("<div>").addClass("swe-sign-on-paper").attr("name",current.id).attr("title",current.name).appendTo( context );
              glyphogram.sw.phraseGlyphogramStaticBind();
              glyphogram.sw.placeGlyphogram( current, "static" );
         });
    }
});

