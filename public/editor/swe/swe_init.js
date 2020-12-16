if (typeof console == "undefined") var console = { log: function() {} };



sw = {
    locale: "cs",
    type: "full",
    callback: function() {},
    symbols: {},
    sources: {},
    translateSet: {},
    currentSims: {},
    glyphogram: {set:[],name:'',id:''},
    phrase: [],
    p_x: 0,
    p_y: 0,
//  baseDir: "./", 
//  baseDir: "/pcSignwritingPlugin/swEditor/",
//    baseDir: "http://pojabr.zcu.cz/proxy/slovnik/pcSignwritingPlugin/swEditor/",
//    baseDir: "http://slovnik.zj.teiresias.muni.cz/pcSignwritingPlugin/swEditor/",
baseDir: './swplugin/',
    localesXML: "locales.xml",
    sourcesXML: "sources.xml",
    buttons: ["del", "truncate", "mirror", "fill", "rotatecclockwise", "rotateclockwise", "placeover"]
};



// common functions

function is_numeric(value) {
    return (value != null && value.toString().match(/^[-]?\d*\.?\d*$/));
}



function sprintf(str, params) {
    $.each(params, function(key, val) {
         str = str.replace("%("+key+")", val);
    });
    return str;
}

