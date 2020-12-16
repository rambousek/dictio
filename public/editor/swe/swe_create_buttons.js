$.namespace("sw", {

    /* function which creates navigation buttons
     * all the function are defined inside it
     */
    createButtons: function() {

        /* returns object reprezenting selected symbol
         */

        var currSym = function() {
            return sw.symbols[$(document).find(".swe-symbol-selected").attr("name")];
        }

        /* search dialog by name on the bottom
         */
        var searchByNameEl = function() {
            var holder = $("<form>").submit( function() {
                return false;
            });

            holder.append( $("<input>")
                            .attr( "value", $().sw.translate('search') )
                            .attr( "type", "hidden" )            /*skryto*/
                            .attr( "id", "swe-search-value")
                            .focusin( function() {
                                if ($(this).attr("value") == swe.translate('search') )
                                    $(this).attr("value", "");
                            })
                            .focusout( function() {
                                if ($(this).attr("value") == "")
                                    $(this).attr("value", swe.translate('search') );
                            })
                            .keyup( function() {
                                if ($(this).attr("value").length == 0)
                                    swe.showPage( 0, 0 )
                                else
                                    swe.searchForString( $(this).attr("value") );
                            })
            );

            return $("<span>").attr("id", "swe-search-by-name").html(holder);
        }



        /* deleting selected symbol
         */
        function del() { 
            $(document).find(".swe-symbol-selected, .swe-symbol-on-paper-selected").sw.fadeRemove();
        }



        /* removing symbols from the editor
         */
        function truncate() { 
            $("#swe-sign-view a").sw.fadeRemove(); 
        }



        function placeover() {
            $(document).find(".swe-symbol-selected").appendTo($(document).find(".swe-symbol-selected").parent());
            $().sw.callback("glyphogramChanged");
        }



        function setSymbol(template, fill, rotation) {
//            console.log("FST: " + JSON.stringify(template));
            template.id = template.id - 1 - ((template.id-1) % 96) + (fill - 1) * 16 + rotation * 1;
            template.fill = fill;
            template.rot = rotation;
//            console.log("SND: " + JSON.stringify(template));

            sw.symbols[template.id] = template;

            // and then change the actual symbol
            $(document).find(".swe-symbol-selected")
                .attr("name", template.id)
                .css("backgroundImage", "url("+$().sw.glyph(template.id)+")");
            $().sw.checkSimilar();
            $().sw.callback("glyphogramChanged");
        }



        function nextStep(current, possibilities, step, max) {
            current -= 1;
            do {
                current = (current + step + max) % max;
            } while (!((1 << current) & possibilities));
            return current + 1;
        }



        /* mirroring selected symbols
         */
        function mirror() {
            // we can mirror only elemenents with bits on higher than eighth position
            var sym = currSym();
            if ((sym.rotations >> 8) > 0) {
                setSymbol(sym, sym.fill, nextStep(sym.rot, sym.rotations, 8, 16));
            }
        }



        /* changing fills of selected symbols
         */
        function fill() {
            var sym = currSym();
            if (sym.fills > 1)
                setSymbol(sym, nextStep(sym.fill, sym.fills, 1, 6), sym.rot);
        }



        /* rotating selected symbols
         */
        function rotate(diff) {
            var sym = currSym();
            if (sym.rotations > 1) {
                var rotation = (sym.rot - 1) % 8 + 1;
                setSymbol(sym, sym.fill, nextStep(rotation, sym.rotations, diff, 8) + (isMirrored() ? 8 : 0));
            }
        }



        /* to determine whether the symbol is a mirrored version of the base symbol
         */
        function isMirrored() {
            return currSym().rot > 8;
        }



        function rotateclockwise() {
            rotate(isMirrored() ? 1 : -1);
        }



        function rotatecclockwise() {
            rotate(isMirrored() ? -1 : 1);
        }




        /* constructing the buttons on the bottom of the sign editor
         */
        var holder = $("<div>").attr("id","swe-buttons");
        $.each(sw.buttons, function(i, v) {
            holder.append( $("<a nohref>")
                    .css("backgroundImage","url("+sw.baseDir+"buttons/"+v+".png)")
                    .attr("title", $().sw.translate(v))
                    .bind("click", function() { (eval(v))() } ));
        });
        holder.append( searchByNameEl() );
        return holder;
    }///
});

