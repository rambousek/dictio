$.namespace( "sw", {
    inherited: true,

    /* returns url for given *symbol_id*
     */
    glyph: function( id ) {
        return sprintf( sw.sources.glyphogram, {sw: id} );
    }, ///

    /* **TODO:** unused at the moment
     */
    glyphogram: function( id ) {
        return "url()";
    }, ///

    /* getting addresses of web services
     */
    getSources: function() {
       console.log(sw);
        $($.ajax({ type: "GET", url: sw.baseDir + sw.sourcesXML, async: false, dataType: "XML"}).responseXML)
            .find("source").each( function() {
                sw.sources[$(this).attr("id")] = $(this).text();
        });
    }, ///

    /* the function load *lang.xml* to read the strings to be put in the template
     */
    initTranslation: function( locale ) {
        $($.ajax({ type: "GET", url: sw.baseDir + sw.localesXML, async: false, dataType: "XML"}).responseXML)
            .find("translation#"+locale)
            .find("phrase").each( function() {
                sw.translateSet[$(this).attr("id")] = $(this).text();
            });
    }, ///

    /* translating a *key* with respect to current *locale* */
    translate: function( key ) {
        if( typeof sw.translateSet[key] == 'undefined' )
            return key;
        else
            return sw.translateSet[key];
    }, ///

    /* **TODO**: will be external? */
    getSimilar: function(glyphogram) {
        return {};
/*        var result = $.ajax({
            type: "POST",
            url: sw.sources.searcher,
            data: {symbs: glyphogram},
            async: false })
                .responseText;
        return eval( result );*/
    }, ///

    /* **TODO**: will be external? */
    ajaxSearchForString: function( str ) {
        if( str.length < 2 )
            return;

        var result = $.ajax({
            type: "POST",
            url: swe.sources.searcher,
            data: {str: str},
            async: false })
                .responseText;

        return eval( result );
    }, ///

    /* **TODO**: will be external? checking for the similar symbols in database
     */
    checkSimilar: function() {
        var symbs = Array();
        $("#swe-sign-view").children().each( function() {
            symbs.push( this.name );
        });
        var resultSet = $().sw.getSimilar( symbs );
        $().sw.info( $().sw.translate['similarsymbols']+": "+resultSet.length, $().sw.showSimilar );
        currentSims = resultSet;
    }, ///

    /* general function to display search results
       (both for written and similar sign search)
     */
    showSearchResults: function( result, fade ) {
        var holder = $("<div>").addClass( "swe-signs-search-results" );

        // adding each symbol of the sign
        $.each( result, function( i, e ) {

            var symb = $("<div>").addClass("swe-sign-with-id").attr("title", e.name ).attr("name", e.id );
            $.each( e.parts, function (ii, ee) {

                $("<span>").addClass("swe-symbol-not-move")
                    .attr("name", ee.id)
                    .css({
                        left: ee.pos_x*1,
                        top: ee.pos_y*1,
                        backgroundImage: $().sw.glyph( ee.id )})
                    .appendTo( symb );
            });

            // centering the sign and allowing it to move
            symb.centerSymbolsInSign( true ).bindSign( null, function( event ) {
                    if(!event.dropTarget ) {
                        $(event.dragProxy).fadeRemove();
                    }
                });

            var el = $("<p>")
                .append( symb )
                .append( $("<p>").html( "<h4>"+e.name+"</h4>"+e.description ) );

            // adding the created sign to the results
            holder.append( el );
        });

        if( fade ) {
            $("#swe-editor").fadeOut( "fast", function() {
                $(this).html( backButton( 500 ) ).append( holder ).fadeIn( "fast" );
                $(document).find(".swe-signs-search-results").adjustHeight();
            });
        } else {
           $("#swe-editor").html( backButton( 500 ) ).append( holder ).show();
           $(document).find(".swe-signs-search-results").adjustHeight();
        }
    }, ///

    /* getting rotations and fills for symbol
     */
    getSymbolDefinition: function( symbol_id ) {
        if( typeof sw.symbols[symbol_id] == 'undefined' ) {
            sw.symbols[symbol_id] = {};
            jQuery.ajax({
                url: sprintf( sw.sources.symbolDefinition, {id: symbol_id }),
                dataType: "json",
                success: function( data, status ) {
                    sw.symbols[symbol_id] = data;
            }});
         }
    }, ///

    /* **TODO**: unused at the moment; showing found similar glyphograms
     */
    showSimilar: function() {
        swe.showSearchResults( currentSims, true );
    }, ///

    /* **TODO**: unused at the moment; searching for string
     */
    searchForString: function( str ) {
        results = swe.ajaxSearchForString( str );
        if( results )
            swe.showSearchResults( results, $(document).find(".swe-signs-search-results").length == 0 );
    }, ///

    /* shows information under the sign editor
     */
    info: function( str, callback ) {
        $("#swe-info").html( str );
        if( callback != null )
            $("#swe-info").click( callback );
        else
            $("#swe-info").unbind();
    } ///
});

