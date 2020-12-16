$.namespace("sw", {

    inherited: true,



    /* html construction of the editor */
    constructEditor: function() {
        var body = $("<div>").attr("id", "swe-body");

        body.append( $("<div>").attr("id","swe-manip").append(
             $("<div>").attr("id","swe-sign-view").addClass("drop-target")
          ).append(
             $("<a nohref>").attr("id","swe-info").click($().sw.showSimilar)
          ).append(
             $().sw.createButtons()
          ));

        body.append(
          $("<div>").attr("id","swe-editor")
        );

        $(this).html( body );
    }, ///



    /* adjusting height based on the browser */
    adjustHeight: function() {
        var h = $(window).height()
            - parseInt($(this).css("padding-bottom"))
            - parseInt($(this).css("padding-top"))
            - parseInt($(this).css("margin-top"))
            - parseInt($(this).css("margin-bottom")) - 20;

        $(this).css("height", h+"px !important");
        return this;
    }, ///



    /* generating back button when showing inner categories or search results */
    backButton: function(height) {
        return $("<a>").addClass("swe-backButton").height(height).attr("title", $().sw.translate('back'))
            .click(function() {
                $().sw.showPage( 0, 0 );
            });
    } ///
});

