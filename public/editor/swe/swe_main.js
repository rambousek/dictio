$.namespace("sw", {
    /* signwriting constructor
     */
    editor: function(params) {
        this.html("").unbind();

        sw = $.extend({}, sw, params || {});

        $().sw.getSources();
        $().sw.initTranslation(sw.locale);
        $(this).sw.constructEditor();

        if (sw.type == 'full') {
            $(this).sw.bindFullEditor();
            $("#swe-paper").sw.placePhrase(sw.phrase);
        }

        $().sw.bindSignView();

        $("#swe-sign-view").sw.placeGlyphogram(sw.glyphogram, "movable");
        $().sw.showPage(0, 0);
    }, ///



    /* function to show set of symbols of symbol group *sg*, *bs*
     */
    showPage: function(sg, bs) {
        var xml = [];
        // reading xml with symbol definitions for each page
        $.getJSON(sprintf(sw.sources.symbolSet, {sg: sg, bs: bs }), function(result, status) {
            // keeping loaded symbols
            symbols = result;
            $.each(symbols, function(key, value) {
                if (typeof value != 'undefined') {
                    xml.push(key);
                    sw.symbols[key] = value;
                }
            });

            var length = xml.length;

            // each page
            var added_width = 0;

            if (sg != 0) {
                added_width = 30;
            }

            if (bs != 0) {
                pagesize = { cols: Math.ceil(length/16), rows: 16 };
            } else {
                pagesize = { cols: Math.ceil(length/10), rows: 10 };
            }

            var page = $("<div>").addClass("swe-symbol-group").css({
                        width: 60*pagesize.cols + added_width,
                        height: 57*pagesize.rows
                    });

            var ii = 0;
            var row = 0;
            for (i = 0; i < pagesize.rows; i++) {
                for (j = 0; j < pagesize.cols; j++) {
                    if (j*pagesize.rows+i >= length) {
                        var symbol = $("<span>");
                    } else {

                        var symbol = xml[j*pagesize.rows+i];
                        symbol = $("<a>")
                                    .css("backgroundImage", "url("+$().sw.glyph(symbol)+")")
                                    .attr("name", symbol).attr("title", $().sw.translate('dragsymbol'));

                        // clicking at each symbol opens its children
                        symbol.click(function() {
                            if (sg == 0)
                                $().sw.showPage($(this).attr("name"), 0);
                            else if (bs == 0)
                                $().sw.showPage(sg, $(this).attr("name"));
                        });
                    }

                    // append the symbol to the page
                    page.append(symbol);
                }
            }

            // binding for dragging the symbols from the symbol list to the editor
            page.find("a")
                .bind('dragstart',function(event) {

                    // creating a new element which is being dragged
                    var drag = $("<a>").addClass("swe-symbol").addClass("swe-sign-in-drag")
                        .attr("name", $(this).attr("name"))
                        .css("backgroundImage", $(this).css("backgroundImage")).appendTo(document.body);
                    $(this).addClass("swe-sign-selected");
                    return drag;
                })
                .bind('drag',function(event){
                    // actual movement of the symbol
                    $(event.dragProxy).css({
                          top: Math.round(event.offsetY/10) * 10,
                          left: Math.round(event.offsetX/10) * 10
                        });
                    })
                .bind('dragend',function(event) {
                    // symbol dropped
                    if (!event.dropTarget || $(event.dropTarget).attr("id") == "swe-paper") {
                        // symbol was NOT dropped into the rightplace
                        $(event.dragProxy).sw.fadeRemove();
                    } else {
                        // symbol dropped to the editor, let's place it and allow it to move around the editor
                        $(event.dragProxy).sw.bindSymbolToMoveAroundEditor();
                        $().sw.callback("glyphogramChanged");
                    }

                    $(document).find("a.swe-sign-in-drag").removeClass("swe-sign-in-drag");
                    $(document).find(".swe-sign-selected").removeClass("swe-sign-selected");
                });

            if (sg)
                // back button
                page.prepend($().sw.backButton(56*pagesize.rows - 2));

            if ($("#swe-editor").html() == "")
                $("#swe-editor").html(page);
            else
                $("#swe-editor").fadeOut("fast", function() {
                     $(this).html(page).fadeIn("fast");
                });
        });
    }, ///



    /* glyphogram generation - independant function*/
    generateGlyphogram: function(glyphogram) {
        if (typeof sw.sources.glyphogram == 'undefined')
            $().sw.getSources();

        $(this).html('');
        $(this).attr('class','swe-sign');
//      $(this).addClass("swe-sign");
        $(this).sw.placeGlyphogram(glyphogram, "static");
    } ///
});

