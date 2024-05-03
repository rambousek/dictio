var entrydata;
Ext.require([
    'Ext.form.*',
]);


var counter_colloc = 0;
var counter_sw = 0;
var counter_video = 0;
var max_meaning = 0;
var is_new_entry = false;
var entryid;
var g_entryid;
var ar_priklady = new Array();
var koncwindow = null;
var entry_updated = false;
var empty = '';
var changes = new Array();
var bgAuth = '#DCDCDC';
var bgSilver = 'silver';

var params = Ext.Object.fromQueryString(window.location.search.substring(1));
if (params.empty != null && params.empty != '') {
  empty = params.empty;
}
if (params.id != null && params.id != '') {
  /* load filelist */
  let mediaQueryObj = window.matchMedia('(prefers-color-scheme: dark)');
  let isDarkMode = mediaQueryObj.matches; // 
  if (isDarkMode) {
    bgAuth = 'slategray';
    bgSilver = 'slategray';
  };
  entryid = params.id;
  g_entryid = params.id;
}

var filelist = Ext.create('Ext.data.Store', {
  fields: ['id', 'location', 'author', 'source', 'admin', /*'copyright', */'status', 'original', 'orient'],
  data: []
});

var relationlist = Ext.create('Ext.data.Store', {
  fields: ['id', 'title', 'number', 'def', 'loc', 'target','front'],
  data: []
});
var linklist = Ext.create('Ext.data.Store', {
  fields: ['id', 'title', 'label'],
  data: []
});

var posStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'subst', 'text':locale[lang].lex_subst},
    {'value': 'adj', 'text':locale[lang].lex_adj},
    {'value': 'pron', 'text':locale[lang].lex_pron},
    {'value': 'num', 'text':locale[lang].lex_num},
    {'value': 'verb', 'text':locale[lang].lex_verb},
    {'value': 'adv', 'text':locale[lang].lex_adv},
    {'value': 'prep', 'text':locale[lang].lex_prep},
    {'value': 'kon', 'text':locale[lang].lex_konj},
    {'value': 'par', 'text':locale[lang].lex_part},    
    {'value': 'int', 'text':locale[lang].lex_cit},
    //{'value': 'frazem', 'text':'frazém'},
    // {'value': 'porekadlo', 'text':'pořekadlo'},
    {'value': 'predpona', 'text':locale[lang].lemma_predpona},
    // {'value': 'prirovnani', 'text':'přirovnání'},
    {'value': 'sprezka', 'text':locale[lang].lex_sprezka},
    // {'value': 'prislovi', 'text':'přísloví'},    
    {'value': 'ustalene', 'text':locale[lang].lemma_colloc},
    {'value': 'ust', 'text':locale[lang].lemma_ust},
    {'value': 'zkratka', 'text':locale[lang].lemma_zkratka},
  ]
});
var emptyStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
  ]
});

var pos_subst_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'hromadne', 'text':locale[lang].subst_hrom},
    {'value': 'pomnozne', 'text':locale[lang].subst_pom},
    {'value': 'vlastni', 'text':locale[lang].subst_vlast},
  ]
});
var pos_subst_rodStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'm', 'text':locale[lang].gen_m},
    {'value': 'z', 'text':locale[lang].gen_f},
    {'value': 's', 'text':locale[lang].gen_n},
  ]
});
var pos_pron_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'osobni', 'text':'osobní'},
    {'value': 'privl', 'text':'přivlastňovací'},
    {'value': 'tazaci', 'text':'tázací'},
    {'value': 'ukazovaci', 'text':'ukazovací'},
    {'value': 'vztazne', 'text':'vztažné'},
    {'value': 'zvratne', 'text':'zvratné'},
    {'value': 'zaporne', 'text':'záporné'},
    {'value': 'neurcite', 'text':'neurčité'},
  ]
});
var pos_num_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'zakladni', 'text':'základní'},
    {'value': 'druhova', 'text':'druhová'},
    {'value': 'radova', 'text':'řadová'},
    {'value': 'nasobna', 'text':'násobná'},
    {'value': 'nasobnapris', 'text':'násobná příslovečná'},
    {'value': 'nasobnaprisneu', 'text':'neurčitá násobná příslovečná'},
    {'value': 'tazaci', 'text':'tázací'},
    {'value': 'zajmenna', 'text':'zájmenná'},
  ]
});
var pos_verb_vidStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'dok', 'text':locale[lang].verb_perf},
    {'value': 'nedok', 'text':locale[lang].verb_imperf},
    {'value': 'doknedok', 'text':locale[lang].verb_perfim},
  ]
});
var pos_verb_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'zpusobove', 'text':'způsobové'},
  ]
});
var pos_adv_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'zajmenne', 'text':'zájmenné'},
  ]
});
var pos_adv_typ2Store = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'neurcite', 'text':'neurčité'},
    {'value': 'tazaci', 'text':'tázací'},
    {'value': 'ukazovaci', 'text':'ukazovací'},
    {'value': 'prisudku', 'text':'v přísudku'},
    {'value': 'vymez', 'text':'vymezovací'},
    {'value': 'vztazne', 'text':'vztažné'},
    {'value': 'zaporne', 'text':'záporné'},
  ]
});
var pos_kon_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'podrad', 'text':'podřadicí'},
    {'value': 'sourad', 'text':'souřadicí'},
  ]
});
var pos_par_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'zduraz', 'text':'zdůrazňovací'},
    {'value': 'obsahova', 'text':'obsahová'},
    {'value': 'modalni', 'text':'modální'},
    {'value': 'citoslovecna', 'text':'citoslovečná'},
  ]
});
var pos_ustalene_typStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'frazem', 'text':'frazém'},
    {'value': 'porekadlo', 'text':'pořekadlo'},
    {'value': 'prirovnani', 'text':'přirovnání'},
    {'value': 'prislovi', 'text':'přísloví'},
  ]
});

var stylhodnStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text': '-'},
    {'value': 'argot', 'text': 'argot'},
    {'value': 'hovorove', 'text': 'hovorově'},
    {'value': 'narec', 'text': 'nářeční výraz'},
    {'value': 'neologismus', 'text': 'neologismus'},
    {'value': 'obecne', 'text': 'obecně česky'},
    {'value': 'morav', 'text': 'oblastní moravský výraz'},
    {'value': 'oblast', 'text': 'oblastní výraz'},
    {'value': 'slang', 'text': 'slangový výraz'},
    {'value': 'spisovne', 'text': 'spisovně'},
    {'value': 'amer', 'text': 'american'},
    {'value': 'brit', 'text': 'british'},
  ]
});
var stylprizStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'abstrakt', 'text': 'abstraktní výraz'},
    {'value': 'basnicky', 'text': 'básnický výraz'},
    {'value': 'biblicky', 'text': 'biblický výraz'},
    {'value': 'cirkev', 'text': 'církevní výraz'},
    {'value': 'detsky', 'text': 'dětský výraz'},
    {'value': 'domacke', 'text': 'domácké slovo'},
    {'value': 'duverny', 'text': 'důvěrný výraz'},
    {'value': 'eufem', 'text': 'eufemismus'},
    {'value': 'expres', 'text': 'expresivní výraz'},
    {'value': 'famil', 'text': 'familiární výraz'},
    {'value': 'hanlivy', 'text': 'hanlivý výraz'},
    {'value': 'ironicky', 'text': 'ironicky'},
    {'value': 'kladny', 'text': 'kladný výraz'},
    {'value': 'knizni', 'text': 'knižní výraz'},
    {'value': 'konkretni', 'text': 'konkrétní výraz'},
    {'value': 'lidovy', 'text': 'lidový výraz'},
    {'value': 'lichotivy', 'text': 'lichotivý výraz'},
    {'value': 'mazlivy', 'text': 'mazlivý výraz'},
    {'value': 'odborny', 'text': 'odborný výraz'},
    {'value': 'pohadkovy', 'text': 'pohádkový výraz'},
    {'value': 'publ', 'text': 'publicistický výraz'},
    {'value': 'prenes', 'text': 'přeneseně'},
    {'value': 'zdvor', 'text': 'zdvořilostní výraz'},
    {'value': 'zhrubely', 'text': 'zhrubělý výraz'},
    {'value': 'zert', 'text': 'žertovný výraz'},
    {'value': 'zlomkovy', 'text': 'zlomkový výraz'},
    {'value': 'zdrob', 'text': 'zdrobnělina'},
    {'value': 'zastar', 'text': 'zastaralý výraz'},
  ]
});

var puvodStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text': '-'},
    {'value': 'a', 'text': 'angličtina'},
    {'value': 'afr', 'text': 'africké jazyky'},
    {'value': 'alb', 'text': 'albánština'},
    {'value': 'am', 'text': 'americká angličtina'},
    {'value': 'ar', 'text': 'arabština'},
    {'value': 'aram', 'text': 'aramejština'},
    {'value': 'b', 'text': 'bulharština'},
    {'value': 'bantu', 'text': 'bantuské jazyky'},
    {'value': 'bask', 'text': 'baskičtina'},
    {'value': 'br', 'text': 'běloruština'},
    {'value': 'cik', 'text': 'cikánština'},
    {'value': 'čes', 'text': 'čeština'},
    {'value': 'čín', 'text': 'čínština'},
    {'value': 'dán', 'text': 'dánština'},
    {'value': 'eg', 'text': 'egyptština'},
    {'value': 'est', 'text': 'estonština'},
    {'value': 'f', 'text': 'francouzština'},
    {'value': 'fin', 'text': 'finština'},
    {'value': 'g', 'text': 'germánské jazyky'},
    {'value': 'hebr', 'text': 'hebrejština'},
    {'value': 'hind', 'text': 'hindština'},
    {'value': 'i', 'text': 'italština'},
    {'value': 'ind', 'text': 'indické jazyky'},
    {'value': 'indián', 'text': 'indiánské jazyky'},
    {'value': 'indonés', 'text': 'indonéština'},
    {'value': 'ir', 'text': 'irština'},
    {'value': 'island', 'text': 'islandština'},
    {'value': 'j', 'text': 'japonština'},
    {'value': 'jakut', 'text': 'jakutština'},
    {'value': 'jslov', 'text': 'jihoslovanské jazyky'},
    {'value': 'kelt', 'text': 'keltské jazyky'},
    {'value': 'korej', 'text': 'korejština'},
    {'value': 'l', 'text': 'latina'},
    {'value': 'lfran', 'text': 'latina přes francouzštinu'},
    {'value': 'lapon', 'text': 'laponština'},
    {'value': 'lit', 'text': 'litevština'},
    {'value': 'lot', 'text': 'lotyština'},
    {'value': 'luž', 'text': 'lužická srbština'},
    {'value': 'maď', 'text': 'maďarština'},
    {'value': 'maked', 'text': 'makedonština'},
    {'value': 'mal', 'text': 'malajština'},
    {'value': 'mong', 'text': 'mongolština'},
    {'value': 'n', 'text': 'němčina'},
    {'value': 'niz', 'text': 'nizozemština'},
    {'value': 'NJ', 'text': 'jméno národa'},
    {'value': 'nor', 'text': 'norština'},
    {'value': 'OJ', 'text': 'osobní jméno'},
    {'value': 'or', 'text': 'orientální jazyky'},
    {'value': 'p', 'text': 'polština'},
    {'value': 'per', 'text': 'perština'},
    {'value': 'polynés', 'text': 'polynéské jazyky'},
    {'value': 'port', 'text': 'portugalština'},
    {'value': 'provens', 'text': 'provensálština'},
    {'value': 'r', 'text': 'ruština'},
    {'value': 'rom', 'text': 'románské jazyky'},
    {'value': 'rum', 'text': 'rumunština'},
    {'value': 'ř', 'text': 'řečtina'},
    {'value': 'semit', 'text': 'semitština'},
    {'value': 'sch', 'text': 'srbochorvatština'},
    {'value': 'skan', 'text': 'skandinávské jazyky'},
    {'value': 'sl', 'text': 'slovenština'},
    {'value': 'sln', 'text': 'slovinština'},
    {'value': 'srb', 'text': 'srbština'},
    {'value': 'střl', 'text': 'středověká latina'},
    {'value': 'svahil', 'text': 'svahilština'},
    {'value': 'š', 'text': 'španělština'},
    {'value': 'šv', 'text': 'švédština'},
    {'value': 't', 'text': 'turečtina'},
    {'value': 'tat', 'text': 'tatarština'},
    {'value': 'tib', 'text': 'tibetština'},
    {'value': 'ttat', 'text': 'turkotatarské jazyky'},
    {'value': 'tung', 'text': 'tunguzština'},
    {'value': 'u', 'text': 'ukrajinština'},
    {'value': 'VJ', 'text': 'vlastní jméno'},
    {'value': 'vslov', 'text': 'východoslovanské jazyky'},
    {'value': 'ZJ', 'text': 'zeměpisné jméno'},
    {'value': 'zslov', 'text': 'západoslovanské jazyky'},
    {'value': 'žid', 'text': 'židovský žargon'},  
  ]
});

var oblastStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': null, 'text':'-'},
    {'value': 'anat', 'text': 'anatomie'},
    {'value': 'antr', 'text': 'antropologie'},
    {'value': 'archeol', 'text': 'archeologie'},
    {'value': 'archit', 'text': 'architektura'},
    {'value': 'biol', 'text': 'biologie'},
    {'value': 'bot', 'text': 'botanika'},
    {'value': 'cirkev', 'text': 'církev'},
    {'value': 'dipl', 'text': 'diplomacie'},
    {'value': 'div', 'text': 'divadelnictví'},
    {'value': 'dopr', 'text': 'doprava'},
    {'value': 'ekol', 'text': 'ekologie'},
    {'value': 'ekon', 'text': 'ekonomie'},
    {'value': 'eltech', 'text': 'elektrotechnika'},
    {'value': 'etn', 'text': 'etnografie'},
    {'value': 'feud', 'text': 'feudalismus'},
    {'value': 'filat', 'text': 'filatelie'},
    {'value': 'film', 'text': 'filmařství'},
    {'value': 'filoz', 'text': 'filozofie'},
    {'value': 'fot', 'text': 'fotografování'},
    {'value': 'fyz', 'text': 'fyzika'},
    {'value': 'fyziol', 'text': 'fyziologie'},
    {'value': 'geol', 'text': 'geologie'},
    {'value': 'geom', 'text': 'geometrie'},
    {'value': 'gnoz', 'text': 'gnozeologie'},
    {'value': 'hist', 'text': 'historie'},
    {'value': 'horn', 'text': 'hornictví'},
    {'value': 'horol', 'text': 'horolezectví'},
    {'value': 'hosp', 'text': 'hospodářství'},
    {'value': 'hud', 'text': 'hudební věda'},
    {'value': 'hut', 'text': 'hutnictví'},
    {'value': 'hvězd', 'text': 'astronomie'},
    {'value': 'chem', 'text': 'chemie'},
    {'value': 'ideal', 'text': 'idealismus'},
    {'value': 'informatika', 'text': 'informatika'},
    {'value': 'jad', 'text': 'jaderná fyzika'},
    {'value': 'jaz', 'text': 'jazykověda'},
    {'value': 'kapit', 'text': 'kapitalismus'},
    {'value': 'karet', 'text': 'karetní hra'},
    {'value': 'katol církvi', 'text': 'katolictví'},
    {'value': 'krim', 'text': 'kriminalistika'},
    {'value': 'křesť', 'text': 'křesťanství'},
    {'value': 'kuch', 'text': 'kuchařství'},
    {'value': 'kult', 'text': 'kultura'},
    {'value': 'kyb', 'text': 'kybernetika'},
    {'value': 'lék', 'text': 'lékařství'},
    {'value': 'lékár', 'text': 'lékárnictví'},
    {'value': 'let', 'text': 'letectví'},
    {'value': 'liter', 'text': 'literární věda'},
    {'value': 'log', 'text': 'logika'},
    {'value': 'marx', 'text': 'marxismus'},
    {'value': 'mat', 'text': 'matematika'},
    {'value': 'meteor', 'text': 'meteorologie'},
    {'value': 'miner', 'text': 'mineralogie'},
    {'value': 'motor', 'text': 'motorismus'},
    {'value': 'mysl', 'text': 'myslivecký výraz'},
    {'value': 'mytol', 'text': 'mytologie'},
    {'value': 'náb', 'text': 'náboženství'},
    {'value': 'nár', 'text': 'národopis'},
    {'value': 'obch', 'text': 'obchod'},
    {'value': 'pedag', 'text': 'pedagogika'},
    {'value': 'peněž', 'text': 'peněžnictví'},
    {'value': 'podnikani', 'text': 'podnikání'},
    {'value': 'polit', 'text': 'politika'},
    {'value': 'polygr', 'text': 'polygrafie'},
    {'value': 'pošt', 'text': 'poštovnictví'},
    {'value': 'potrav', 'text': 'potravinářství'},
    {'value': 'práv', 'text': 'právo'},
    {'value': 'prům', 'text': 'průmysl'},
    {'value': 'přír', 'text': 'příroda'},
    {'value': 'psych', 'text': 'psychologie'},
    {'value': 'rybn', 'text': 'rybníkářství'},
    {'value': 'řem', 'text': 'řemeslo'},
    {'value': 'sklář', 'text': 'sklářství'},
    {'value': 'soc', 'text': 'socialismus'},
    {'value': 'sociol', 'text': 'sociologie'},
    {'value': 'stat', 'text': 'statistika'},
    {'value': 'stav', 'text': 'stavitelství'},
    {'value': 'škol', 'text': 'školství'},
    {'value': 'tech', 'text': 'technika'},
    {'value': 'těl', 'text': 'sport'},
    {'value': 'text', 'text': 'textilnictví'},
    {'value': 'úč', 'text': 'účetnictví'},
    {'value': 'úř', 'text': 'úřední výraz'},
    {'value': 'veř spr', 'text': 'veřejná správa'},
    {'value': 'vet', 'text': 'veterinářství'},
    {'value': 'voj', 'text': 'vojenství'},
    {'value': 'výptech', 'text': 'výpočetní technika'},
    {'value': 'výr', 'text': 'výroba'},
    {'value': 'výtv', 'text': 'výtvarnictví'},
    {'value': 'zahr', 'text': 'zahradnictví'},
    {'value': 'zbož', 'text': 'zbožíznalství'},
    {'value': 'zeměd', 'text': 'zemědělství'},
    {'value': 'zeměp', 'text': 'zeměpis'},
    {'value': 'zool', 'text': 'zoologie'},
    {'value':'adm', 'text':'administrativa'},
    {'value':'artistika', 'text':'artistika'},
    {'value':'astro', 'text':'astronomie'},
    {'value':'biblhist', 'text':'bibl. hist.'},
    {'value':'bibl', 'text':'biblistika'},
    {'value':'biochemie', 'text':'biochemie'},
    {'value':'cirar', 'text':'círk. archit.'},
    {'value':'cirhi', 'text':'církevní historie'},
    {'value':'cirhu', 'text':'círk. hud.'},
    {'value':'cirkr', 'text':'círk. křesť.'},
    {'value':'cirpol', 'text':'círk. polit.'},
    {'value':'cirpr', 'text':'círk. práv.'},
    {'value':'cukr', 'text':'cukrovarnictví'},
    {'value':'ekpub', 'text':'ekon. publ.'},
    {'value':'eltech', 'text':'elektr.'},
    {'value':'estet', 'text':'estetika'},
    {'value':'farmak', 'text':'farmakologie'},
    {'value':'folklor', 'text':'folkloristika'},
    {'value':'fonetika', 'text':'fonetika'},
    {'value':'fyzchem', 'text':'fyzikální chemie'},
    {'value':'genetika', 'text':'genetika'},
    {'value':'geochem', 'text':'geochem.'},
    {'value':'geodez', 'text':'geodézie'},
    {'value':'geofyz', 'text':'geofyzika'},
    {'value':'geogr', 'text':'geografie'},
    {'value':'geolzem', 'text':'geol. zeměd.'},
    {'value':'hiadm', 'text':'historie administrativy'},
    {'value':'hiar', 'text':'historie architektury'},
    {'value':'hiast', 'text':'historie astronomie'},
    {'value':'hidip', 'text':'historie diplomacie'},
    {'value':'hidiv', 'text':'historie divadelnictví'},
    {'value':'hieko', 'text':'historie ekonomie'},
    {'value':'hietno', 'text':'historie etnografie'},
    {'value':'hifil', 'text':'historie filozofie'},
    {'value':'hifot', 'text':'historie fotografování'},
    {'value':'higeo', 'text':'historie geografie'},
    {'value':'hilit', 'text':'historie literatury'},
    {'value':'himat', 'text':'historie matematika'},
    {'value':'hinab', 'text':'historie náboženství'},
    {'value':'hipen', 'text':'historie peněžnictví'},
    {'value':'hipol', 'text':'historie politiky'},
    {'value':'hipr', 'text':'historie práva'},
    {'value':'hisk', 'text':'historie školství'},
    {'value':'hispo', 'text':'historie sport'},
    {'value':'hista', 'text':'historie stavitelství'},
    {'value':'hitech', 'text':'historie techniky'},
    {'value':'hivoj', 'text':'historie vojenství'},
    {'value':'sach', 'text':'hra v šachy'},
    {'value':'hudpubl', 'text':'hudební publicistika'},
    {'value':'jadtech', 'text':'jad. tech.'},
    {'value':'keram', 'text':'keramika'},
    {'value':'kniho', 'text':'knihovnictví'},
    {'value':'kosmet', 'text':'kosmet.'},
    {'value':'kosmon', 'text':'kosmonautika'},
    {'value':'kozed', 'text':'kožedělný průmysl'},
    {'value':'krejc', 'text':'krejčovství'},
    {'value':'kynol', 'text':'kynologie'},
    {'value':'lesnic', 'text':'lesnictví'},
    {'value':'lethist', 'text':'let. hist.'},
    {'value':'lingv', 'text':'lingvistika'},
    {'value':'liter', 'text':'liter. hist.'},
    {'value':'lodar', 'text':'loďařství'},
    {'value':'matlog', 'text':'mat. log.'},
    {'value':'mezobch', 'text':'mezinár. obch.'},
    {'value':'mezpr', 'text':'mezinárodní právo'},
    {'value':'nabpol', 'text':'náb. polit.'},
    {'value':'nabps', 'text':'náb. ps.'},
    {'value':'namor', 'text':'námořnictví'},
    {'value':'numiz', 'text':'numizmatika'},
    {'value':'obchpr', 'text':'obch. práv.'},
    {'value':'obuv', 'text':'obuvnictví'},
    {'value':'odb', 'text':'odb.'},
    {'value':'optika', 'text':'optika'},
    {'value':'orient', 'text':'orient.'},
    {'value':'paleo', 'text':'paleontologie'},
    {'value':'papir', 'text':'papírenství'},
    {'value':'pedol', 'text':'pedol.'},
    {'value':'piv', 'text':'piv.'},
    {'value':'politadm', 'text':'polit. a adm.'},
    {'value':'politeko', 'text':'polit. ekon.'},
    {'value':'potrobch', 'text':'potr. obch.'},
    {'value':'hipr', 'text':'práv. hist.'},
    {'value':'publ', 'text':'publicistika'},
    {'value':'rybar', 'text':'rybářství'},
    {'value':'sdel', 'text':'sdělovací technika'},
    {'value':'sport', 'text':'sport'},
    {'value':'sporpub', 'text':'sportovní publicistika'},
    {'value':'stroj', 'text':'strojírenství'},
    {'value':'tanec', 'text':'tanec'},
    {'value':'teol', 'text':'teol.'},
    {'value':'tesn', 'text':'těsn.'},
    {'value':'textobch', 'text':'text. obch.'},
    {'value':'umel', 'text':'umělecký'},
    {'value':'umrem', 'text':'uměl. řem.'},
    {'value':'vcel', 'text':'včel.'},
    {'value':'vinar', 'text':'vinařství'},
    {'value':'vodohos', 'text':'vodohospodářství'},
    {'value':'vojhist', 'text':'voj. hist.'},
    {'value':'vojnam', 'text':'voj. nám.'},
    {'value':'vor', 'text':'vorařský'},
    {'value':'zeldop', 'text':'železniční doprava'},
    {'value':'zpravpubl', 'text':'zprav. publ.'},
    {'value':'zurn', 'text':'žurn.'},
  ]
});



var pracskupinaStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [ 
  {'value': 'all', 'text': locale[lang].pracskup_all},  
  {'value': 'mdd', 'text': 'MobiDeafDict'},
  {'value': 'test', 'text': locale[lang].pracskup_test},
    {'value': '', 'text': ''},
  ]
});


var katStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value': '', 'text':'nezařazeno'},
    {'value': '28', 'text':'biologie'},
    {'value': '6', 'text':'informatika'},
    {'value': '27', 'text':'matematika'},
    {'value': '14', 'text':'podnikání'},
  ]
});


var uplnostStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
   {'value': '0', 'text':locale[lang].pub_auto},
    {'value': '1', 'text':locale[lang].pub_hide},
    {'value': '2', 'text':locale[lang].pub_nonempty},
    {'value': '100', 'text':locale[lang].pub_approved},
  ]
});


data = [
    {'value': 'translation_cs', 'text':locale[lang].rel_trans_cs},
    {'value': 'translation_czj', 'text':locale[lang].rel_trans_czj},
    {'value': 'translation_en', 'text':locale[lang].rel_trans_en},
    {'value': 'translation_is', 'text':locale[lang].rel_trans_is},
    {'value': 'translation_asl', 'text':locale[lang].rel_trans_asl},
    {'value': 'translation_sj', 'text':locale[lang].rel_trans_sj},
    {'value': 'translation_spj', 'text':locale[lang].rel_trans_spj},
    {'value': 'translation_de', 'text':locale[lang].rel_trans_de},
    {'value': 'translation_ogs', 'text':locale[lang].rel_trans_ogs},
    {'value': 'translation_uk', 'text':locale[lang].rel_trans_uk},
    {'value': 'translation_uzm', 'text':locale[lang].rel_trans_uzm},
    {'value': 'synonym', 'text':locale[lang].rel_syn},
    {'value': 'synonym_strategie', 'text':locale[lang].rel_strat},
    {'value': 'antonym', 'text':locale[lang].rel_ant},
    {'value': 'hyperonym', 'text':locale[lang].rel_hype},
    {'value': 'hyponym', 'text':locale[lang].rel_hypo},
  ] ;
data = data.filter(val=>val.value!='translation_'+dictcode);
var typeStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'], data:data
});
  data = [
    {'value': 'translation_cs', 'text':locale[lang].rel_trans_cs},
    {'value': 'translation_czj', 'text':locale[lang].rel_trans_czj},
    {'value': 'translation_en', 'text':locale[lang].rel_trans_en},
    {'value': 'translation_is', 'text':locale[lang].rel_trans_is},
    {'value': 'translation_asl', 'text':locale[lang].rel_trans_asl},
    {'value': 'translation_sj', 'text':locale[lang].rel_trans_sj},
    {'value': 'translation_spj', 'text':locale[lang].rel_trans_spj},
    {'value': 'translation_de', 'text':locale[lang].rel_trans_de},
    {'value': 'translation_ogs', 'text':locale[lang].rel_trans_ogs},
    {'value': 'translation_uk', 'text':locale[lang].rel_trans_uk},
    {'value': 'translation_uzm', 'text':locale[lang].rel_trans_uzm},
  ];
data = data.filter(val=>val.value!='translation_'+dictcode);
var extypeStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],data:data
});
var pubStore = Ext.create('Ext.data.Store',{
  fields: ['value', 'text'],
  data: [
    {'value':'published','text':'schválit k publikování'},
    {'value':'hidden','text':'skrýt'}
  ]
});

  var dekl_desc = {
    'nSc1': 'j. č., 1. pád',
    'nSc2': 'j. č., 2. pád',
    'nSc3': 'j. č., 3. pád',
    'nSc4': 'j. č., 4. pád',
    'nSc5': 'j. č., 5. pád',
    'nSc6': 'j. č., 6. pád',
    'nSc7': 'j. č., 7. pád',
    'nPc1': 'mn. č., 1. pád',
    'nPc2': 'mn. č., 2. pád',
    'nPc3': 'mn. č., 3. pád',
    'nPc4': 'mn. č., 4. pád',
    'nPc5': 'mn. č., 5. pád',
    'nPc6': 'mn. č., 6. pád',
    'nPc7': 'mn. č., 7. pád',
    'd2': '2. stupeň',
    'd3': '3. stupeň',
    'c1': '1. pád j. č.',
    'c2': '2. pád j. č.',
    'c3': '3. pád j. č.',
    'c4': '4. pád j. č.',
    'c5': '5. pád j. č.',
    'c6': '6. pád j. č.',
    'c7': '7. pád j. č.',
    'cP1': 'mn. č. 1. pád',
    'cP2': 'mn. č. 2. pád',
    'cP3': 'mn. č. 3. pád',
    'cP4': 'mn. č. 4. pád',
    'cP5': 'mn. č. 5. pád',
    'cP6': 'mn. č. 6. pád',
    'cP7': 'mn. č. 7. pád',
    'mIp1nS': '1. os., j. č.',
    'mIp1nP': '1. os, mn. č.',
    'mIp2nS': '2. os., j. č.',
    'mIp2nP': '2. os, mn. č.',
    'mIp3nS': '3. os., j. č.',
    'mIp3nP': '3. os, mn. č.',
    'gNnSc1': 'verb. subst.',
    'mAgMnS': 'příč. činné',
    'mNgMnS': 'příč. trpné',
    'mRp2nP': 'rozk. zp., mn. č.',
    'mRp2nS': 'rozk. zp., j.  č.',
    'mSgFnS': 'přech. přít. ž+s',
    'mSgMnP': 'přech. přít. m., mn. č.',
    'mSgMnS': 'přech. přít. m., j. č.',
    'mDgFnS': 'přech. min. ž+s',
    'mDgMnP': 'přech. min. m., mn. č.',
    'mDgMnS': 'přech. min. m., j. č.',
  }

function update_stav() {
  var stav = Ext.getCmp('boxlemma').query('component[name=autostav]')[0];
  var viditelnost = Ext.getCmp('boxlemma').query('component[name=completeness]')[0].getValue();

  //stav.setValue(viditelnost);
  var zjisteny_stav = 0; //0-prazdne, 1-neuplne, 2-uplne
  var video_vyplneno = false;
  var trans_vyplneno = false;
  var vyklad_vyplneno = false;
  var preklad_vyplneno = false;
  var video_front = false;
  var video_side = false;



  //vyklad
  var defset = Ext.getCmp('tabForm').query('component[name="vyznam"]');
  for (var j = 0; j < defset.length; j++) {
    if (defset[j].query('[name=vyznammeta]')[0].query('component[name="stav"]')[0].getValue() == 'published') {
      var exset = defset[j].query('component[name="usageset"]');
      for (var i = 0; i < exset.length; i++) {
        if (exset[i].query('component[name="stav"]')[0].getValue() == 'published') {
          vyklad_vyplneno = true;
        }
      }
    }
  }

  if (vyklad_vyplneno) {
    zjisteny_stav = 2;
  /*} else if (video_vyplneno || preklad_vyplneno || trans_vyplneno || vyklad_vyplneno) {
    zjisteny_stav = 1;*/
  }

  var stav_popis = [locale[lang].stav_popis_nevyplnene, locale[lang].stav_popis_neuplne,locale[lang].stav_popis_uplne];

  switch(viditelnost) {
    case '0':
      stav.setValue(stav_popis[zjisteny_stav] + ' / ' + (zjisteny_stav==2?locale[lang].lemma_published:locale[lang].lemma_hidden));
      break;
    case '1':
      stav.setValue(stav_popis[zjisteny_stav] + ' / '+locale[lang].lemma_hidden);
      break;
    case '100','2':
      stav.setValue(stav_popis[zjisteny_stav] + ' / '+locale[lang].lemma_published);
      break;
  }
}

function check_perm(heslo_skupina, user_skupina, user_perm) {
  console.log('heslo='+heslo_skupina);
  console.log('user ='+user_skupina);
  console.log('perm ='+user_perm);
  // je admin
  if (user_perm.indexOf('admin') > -1) {
    Ext.getCmp('tabForm').query('[name=userperm]')[0].setValue('admin');
    return true;
  }
  Ext.getCmp('boxlemma').setDisabled(true);
  Ext.each(Ext.getCmp('tabForm').query('[name=stavbutton]'), function(item) {
    if (item.getEl() != undefined) {
      item.getEl().hide();
    }
  });
  if (user_skupina.indexOf(heslo_skupina) > -1 || user_skupina.indexOf('all') > -1) {
    //stejna skupina, kontrola prav
    Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topcont]'), function(tc){ Ext.each(tc.items.items, function(item){item.setDisabled(true)})}); //disable na vsechno ve vyznamech

    if (user_perm.indexOf('editor_cjformal') == -1) {
      Ext.getCmp('gramdesc').setDisabled(true);
      Ext.getCmp('styldesc').setDisabled(true);
      //Ext.getCmp('vyznamy_box').setDisabled(true);
    }
    if (user_perm.indexOf('editor_cjformal') > -1) {
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topcont]'), function(tc){ Ext.each(tc.items.items, function(item){item.setDisabled(false)})});
    }
  
  //preklad
  if (user_perm.indexOf('editor_preklad') > -1 || user_perm.indexOf('revizor_preklad') > -1) {
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=relbox]'), function(item){item.up().setDisabled(false);item.setDisabled(false)});
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=translation_unknown]'), function(item){item.setDisabled(false)});
      Ext.getCmp('gramdesc').collapse();
      Ext.getCmp('styldesc').collapse();
    }   
    if (user_perm.indexOf('revizor_preklad') > -1) {
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=relbox] [name=stavbutton]'), function(item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
    }

    //revizor
    if (user_perm.indexOf('revizor_lemmacj' || user_perm.indexOf('editor_cjlemma') > -1) > -1) {
      Ext.getCmp('boxlemma').setDisabled(false);    
    }
    if (user_perm.indexOf('revizor_cjlingvist') > -1 || user_perm.indexOf('editor_cjlemma') > -1) {
      Ext.getCmp('gramdesc').setDisabled(false);
      Ext.getCmp('styldesc').setDisabled(false);
      Ext.getCmp('boxcolloc').setDisabled(false);
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topcont]'), function(tc){ Ext.each(tc.items.items, function(item){item.setDisabled(false)})});
    }
    if (user_perm.indexOf('revizor_cjlingvist') > -1) {
      Ext.each(Ext.getCmp('boxcolloc').query('[name=stavbutton]'), function(item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=stavbutton]'), function(item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('styldesc').query('[name=stavbutton]'), function(item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('gramdesc').query('[name=stavbutton]'), function(item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
    }

  } else if (user_perm.indexOf('editor_cjformal') > -1) {
    //ruzna skupina, muze pridat vyznam
    Ext.each(Ext.getCmp('tabForm').query('[name=copybox]'), function(item) {item.setDisabled(true)}); //disable copy
    Ext.getCmp('gramdesc').setDisabled(true);
    Ext.getCmp('styldesc').setDisabled(true);
    Ext.getCmp('boxcolloc').collapse();
    Ext.getCmp('boxcolloc').setDisabled(true);
    Ext.getCmp('formaldesc').setDisabled(true);
    Ext.each(Ext.getCmp('tabForm').query('component[name="vyznam"]'), function(item) {
      console.log('mean == '+item.query('[name=pracskupina]')[0].getValue());
      var meanskup = item.query('[name=pracskupina]')[0].getValue();
      if (meanskup == '' || user_skupina.indexOf(meanskup) == -1) {
        item.setDisabled(true)
      }
    });
  } else {
    //ma jine skupiny nez heslo
    //disable, schovat skryte
    Ext.getCmp('tabForm').query('[name=userperm]')[0].setValue('jen čtení');
    Ext.getCmp('tabForm').query('[name=savebutton]')[0].setDisabled(true);
    Ext.getCmp('tabForm').setDisabled(true);
    return true;
  }
}

function change_gram(elid, pos) {
  Ext.getCmp(elid).query('component[name=skupina]')[0].clearValue();
  Ext.getCmp(elid).query('component[name=skupina2]')[0].clearValue();
  switch(pos) {
    case 'subst':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_subst_typStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_subst_rodStore);
      break;
    case 'adj':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(emptyStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
      break;
    case 'pron':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_pron_typStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_subst_rodStore);
      break;
    case 'num':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_num_typStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
      break;
    case 'verb':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_verb_vidStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_verb_typStore);
      break;
    case 'adv':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_adv_typStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_adv_typ2Store);
      break;
    case 'kon':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_kon_typStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
      break;
    case 'par':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(emptyStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_par_typStore);
      break;
    case 'ustalene':
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_ustalene_typStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
      break;
    default:
      Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(emptyStore);
      Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
      break;
  }
}

function create_comment_button(boxid, type) {
  if (type == undefined) {
    var type = boxid;
  }
  var cont = Ext.create('Ext.container.Container', {
    layout: {
      type: 'vbox',
      width: 200
    },
    items: [{
      xtype: 'button',
      name: 'commentbutton',
      text: locale[lang].comment,
      handler: function() {
        open_comments(boxid, type);
      }
    },{
      xtype: 'box',
      width: 200,
      name: 'lastcomment',
      height: 100,
      hidden: true,
      autoScroll: true
    }]
  });
  Ext.Ajax.request({
    url: '/'+dictcode+'/comments/'+g_entryid+'/'+type,
    method: 'get',
    success: function(response) {
      /* fill media info */
      var data = JSON.parse(response.responseText);
      console.log('load comments' + new Date().getTime());
      if (data.comments.length > 0) {
        console.log(data.comments[0])
        cont.query('[name=lastcomment]')[0].update(data.comments[0].text + ', <i>' + data.comments[0].user + ', ' + data.comments[0].time + '</i>');
        cont.query('[name=lastcomment]')[0].show();
      }
      if (data.comments.length > 1) {
        cont.query('[name=commentbutton]')[0].setText(locale[lang].opencomment);
      }
    }
  });
  return cont;
}

function open_comments(box, type) {
  var name = 'koment_'+Ext.id();  
  var kwin =   Ext.create('Ext.window.Window', {
    title: locale[lang].coments,
    height: 300,
    width: 500,
    layout: {
      type: 'vbox'
    },
    id: name,
    autoScroll: true,
    items: { 
      xtype: 'container',
      items: [{
        xtype: 'container',
        layout: {
          type: 'hbox'
        },
        width: 470,
        height: 65,
        items: [{
          xtype: 'textarea', 
          name: 'newtext',
          width:400
        },{
          xtype:'button',
          text: locale[lang].savechanges,
          handler: function() {
            Ext.Ajax.request({
              url: '/'+dictcode+'/add_comment',
              params: {
                entry: entryid,
                box: type,
                text: kwin.query('[name=newtext]')[0].getValue()
              },
              method: 'post',
              success: function(response) {
                Ext.getCmp(box).query('[name=lastcomment]')[0].update(kwin.query('[name=newtext]')[0].getValue());
                Ext.getCmp(box).query('[name=lastcomment]')[0].show(); 
                kwin.close();
              }
            });
          }
        }]
      }
      ],
    }
  });
  Ext.Ajax.request({
    url: '/'+dictcode+'/comments/'+entryid+'/'+type,
    method: 'get',
    success: function(response) {
      var data = JSON.parse(response.responseText);
      console.log('load comments' + new Date().getTime() + name)
      var html = '';
      for (i = 0; i < data.comments.length; i++) {
        var newcom = Ext.create('Ext.Component', {
          width: 400,
          height: 65,
          border: 1,
          style: {
            borderColor: 'blue',
            borderStyle: 'solid'
          },
          html: data.comments[i].text + '<br/><i>' + data.comments[i].user + ', ' + data.comments[i].time + '</i>',
          name: 'commenthtml'
        });
        var cid = data.comments[i]['_id']['$oid'];
        var nrow = Ext.create('Ext.container.Container',{
          layout: {
            type: 'hbox'
          },
          items: [newcom,{
            xtype:'button',
            text: locale[lang].delete,
            cidParam: cid,
            handler: function(btn) {
              Ext.Ajax.request({
                url: '/'+dictcode+'/del_comment/'+btn.cidParam,
                method: 'get',
                success: function(response) {
                  var lasttext = '';
                  if (btn.up().up().query("[name=commenthtml]")[1] != undefined) {
                    lasttext = btn.up().up().query("[name=commenthtml]")[1].getEl().dom.innerHTML;
                  }
                  Ext.getCmp(box).query('[name=lastcomment]')[0].update(lasttext);
                  btn.up().up().remove(btn.up().id);
                }
              });
            }
          }]
        });
        kwin.add(nrow);
      }  
      kwin.show();
      kwin.alignTo(box, "tr-tr")
    }
  });
  return kwin;
}


function add_video_fancybox() {
  $('.videofancybox').each(function() {
    if ($(this).find('source')[0] != undefined) {
      var vid = $(this).find('source').attr('src');
      console.log(vid)
      $(this).on("click",function(e) {
      console.log(e)
        e.target.pause();
        var container = $('<div data-ratio="0.8" style="width:335px;"><video preload="none" controls="" width="285px" height="228px" poster="'+vid+'/thumb.jpg" autoplay=""><source type="video/webm" src="'+vid+'.webm"/><source type="video/mp4" src="'+vid+'"/></video></div>');
        $.fancybox.open({
          src: container,
          type: 'html',
          scrolling: 'no',
        });
      });
    }
  });
}

function new_entry() {
  var loadMask = new Ext.LoadMask(Ext.getBody(), {msg:" "});
  console.log('new start ' + new Date().getTime())
  Ext.suspendLayouts();
  loadMask.show();
  Ext.Ajax.request({
    url: '/'+dictcode+'/newentry',
    method: 'get',
    success: function(response) {
      var data = JSON.parse(response.responseText);
      entryid = data['newid'].toString();
      entrydata = {'meanings': [{'id': data['newid']+'-1','created_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s')}], 'lemma': {'created_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s')}};
      Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase()+'-'+entryid);
      document.title = dictcode.toUpperCase()+' '+entryid;
      Ext.getCmp('tabForm').query('component[name="userskupina"]')[0].setValue(data['user_info']['skupina'].join(','));
      Ext.getCmp('tabForm').query('component[name="userperm"]')[0].setValue(data['user_info']['perm']);
      Ext.getCmp('tabForm').query('component[name="usersetrel"]')[0].setValue(data['set_rel']);
      Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].setValue(data['user_info']['zdroj']);
      Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].setValue(data['user_info']['autor']);
      Ext.getCmp('tabForm').query('component[name="completeness"]')[0].setValue('0');
      if (data['user_info']['skupina'] != undefined) {
        var skupiny = data['user_info']['skupina'];
        Ext.getCmp('tabForm').query('component[name="pracskupina"]')[0].setValue(skupiny[0]);
      }
      Ext.getCmp('vyznamy_box').remove(Ext.getCmp('vyznamy_box').query('component[name="vyznam"]')[0]);
      Ext.getCmp('vyznamy_box').insert(Ext.getCmp('vyznamy_box').items.length-1, create_vyznam(data['newid'], true, data['newid']+'-1'));
      max_meaning = 1;
      var copys = Ext.getCmp('tabForm').query('[name=copybox]');
      for (var i = 0; i < copys.length; i++) {
        copys[i].query('[name=copy_zdroj]')[0].setValue(data['user_info']['zdroj']);
        copys[i].query('[name=copy_autor]')[0].setValue(data['user_info']['autor']);
      }

      console.log('new end ' + new Date().getTime())
      Ext.resumeLayouts(true);
      loadMask.hide();
      console.log('after mask ' + new Date().getTime())
    }
  });
}

function load_doc(id, history, historytype) {
  var loadMask = new Ext.LoadMask(Ext.getBody(), {msg:" "});
  console.log('load start ' + new Date().getTime())
  Ext.suspendLayouts();
  loadMask.show();
  if (history != undefined && historytype != undefined) {
    var url = '/'+dictcode+'/json/'+id+'?history='+history+'&historytype='+historytype;
  } else {
    var url = '/'+dictcode+'/json/'+id;
  }
  Ext.Ajax.request({
    url: url,
    method: 'get',
    success: function(response) {
      console.log('parse start ' + new Date().getTime())
      var data = JSON.parse(response.responseText);
      entrydata = data;
      console.log('ext form start ' + new Date().getTime())
      Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase()+'-'+id);
      document.title = dictcode.toUpperCase()+' '+id;

      if (data['lemma'] != undefined) {
        /* heslo */
        Ext.getCmp('tabForm').query('component[name="userskupina"]')[0].setValue(data['user_info']['skupina'].join(','));
        Ext.getCmp('tabForm').query('component[name="userperm"]')[0].setValue(data['user_info']['perm']);
        Ext.getCmp('tabForm').query('component[name="usersetrel"]')[0].setValue(data['set_rel']);
        //Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].setValue(data['user_info']['copy']);
        Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].setValue(data['user_info']['zdroj']);
        Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].setValue(data['user_info']['autor']);
        Ext.getCmp('tabForm').query('component[name="completeness"]')[0].setValue(data['lemma']['completeness']);
        Ext.getCmp('tabForm').query('component[name="pracskupina"]')[0].setValue(data['lemma']['pracskupina']);
        Ext.getCmp('tabForm').query('component[name="admin_comment"]')[0].setValue(data['lemma']['admin_comment']);
        Ext.getCmp('tabForm').query('component[name="lemma"]')[0].setValue(data['lemma']['title']);
        Ext.getCmp('tabForm').query('component[name="lemma_var"]')[0].setValue(data['lemma']['title_var']);
        Ext.getCmp('tabForm').query('component[name="pron"]')[0].setValue(data['lemma']['pron']);
        Ext.getCmp('tabForm').query('component[name="puvod_slova"]')[0].setValue(data['lemma']['puvod']);
        Ext.getCmp('tabForm').query('component[name="admin_comment"]')[0].setValue(data['lemma']['admin_comment']);

        /* puvodni heslo v ssc */
        if (data['html'] != null) {
          Ext.getCmp('tabForm').query('[name=ssc_html]')[0].update(data['html']);
        }

        /* gramatika */
        if (data['lemma']['grammar_note'] && data['lemma']['grammar_note'].length > 0) {
          var gram = data['lemma']['grammar_note'][0];
          if (gram['_text']) Ext.getCmp('tabForm').query('component[name="gramatikatext_text"]')[0].setValue(gram['_text']);
          if (gram['@author']) Ext.getCmp('gramdesc').query('component[name="copy_autor"]')[0].setValue(gram['@author']);
          if (gram['@admin']) Ext.getCmp('gramdesc').query('component[name="copy_admin"]')[0].setValue(gram['@admin']);
          if (gram['@source']) Ext.getCmp('gramdesc').query('component[name="copy_zdroj"]')[0].setValue(gram['@source']);
          if (gram['@copyright']) Ext.getCmp('gramdesc').query('component[name="copy_copy"]')[0].setValue(gram['@copyright']);
          if (gram['@flexe_neskl']) Ext.getCmp('gramdesc').query('component[name="flexe_neskl"]')[0].setValue(gram['@flexe_neskl']);
          change_stav(Ext.getCmp('gramdesc').query('component[name="stavcont"]')[0], gram['@status']);
          /* gram. kategorie */
          Ext.getCmp('gramcont').query('[name=gramitem]')[0].destroy();
          data['lemma']['grammar_note'].forEach(function(gram) {
            var gramit = create_gram(id);
            Ext.getCmp('gramcont').insert(Ext.getCmp('gramcont').items.length-1,gramit);
            /* zmena skupiny */
            Ext.getCmp(gramit.id).query('component[name="slovni_druh"]')[0].setValue(gram['@slovni_druh']);
            change_gram(gramit.id, gram['@slovni_druh']);
            if (gram['@skupina'] != null) {
              Ext.getCmp(gramit.id).query('component[name="skupina"]')[0].setValue(gram['@skupina'].split(';'));
            }
            if (gram['@skupina2'] != null) {
              Ext.getCmp(gramit.id).query('component[name="skupina2"]')[0].setValue(gram['@skupina2'].split(';'));
            }
          });
        }
        /* deklinace */
        if (data['lemma']['gram'] && data['lemma']['gram']['form'] && data['lemma']['gram']['form'].length > 0) {
          data['lemma']['gram']['form'].forEach(function(gram) {
            var variant = create_deklin(id);
            var tag = gram['@tag'];
            Ext.getCmp('deklcont').insert(Ext.getCmp('deklcont').items.length-2,variant);
            variant.query('component[name="dekl_tvar"]')[0].setValue(gram['_text']);
            variant.query('component[name="dekl_tag"]')[0].setValue(tag);
            if (dekl_desc[tag] != undefined) {
              variant.query('component[name="dekl_desc"]')[0].setValue(dekl_desc[tag]);
            }
          });
        }
        /* stylistika */
        if (data['lemma']['style_note'] && data['lemma']['style_note'].length > 0) {
          var gram = data['lemma']['style_note'][0];
          Ext.getCmp('tabForm').query('component[name="styltext_text"]')[0].setValue(gram['_text']);
          if (gram['@generace'] != null) {
            Ext.getCmp('styldesc').query('component[name="generace"]')[0].setValue(gram['@generace'].split(';'));
          }
          if (gram['@kategorie']) Ext.getCmp('styldesc').query('component[name="kategorie"]')[0].setValue(gram['@kategorie']);
          if (gram['@stylpriznak']) Ext.getCmp('styldesc').query('component[name="stylpriznak"]')[0].setValue(gram['@stylpriznak']);
          if (gram['@author']) Ext.getCmp('styldesc').query('component[name="copy_autor"]')[0].setValue(gram['@author']);
          if (gram['@admin']) Ext.getCmp('styldesc').query('component[name="copy_admin"]')[0].setValue(gram['@admin']);
          if (gram['@source']) Ext.getCmp('styldesc').query('component[name="copy_zdroj"]')[0].setValue(gram['@source']);
          if (gram['@copyright']) Ext.getCmp('styldesc').query('component[name="copy_copy"]')[0].setValue(gram['@copyright']);
          change_stav(Ext.getCmp('styldesc').query('component[name="stavcont"]')[0], gram['@status']);
        }
        /* varianty */
        if (data['lemma']['grammar_note'] && data['lemma']['grammar_note'][0] && data['lemma']['grammar_note'][0]['variant']) {
          data['lemma']['grammar_note'][0]['variant'].forEach(function(gramvar) {
            var variant = create_variant(id);
            Ext.getCmp('gvarbox').insert(Ext.getCmp('gvarbox').items.length-1, variant);
            variant.query('component[name="varlink"]')[0].setValue(gramvar['_text']);
          });
        }
        if (data['lemma']['style_note'] && data['lemma']['style_note'][0] && data['lemma']['style_note'][0]['variant']) {
          data['lemma']['style_note'][0]['variant'].forEach(function(gramvar) {
            var variant = create_variant(id);
            Ext.getCmp('varbox').insert(Ext.getCmp('varbox').items.length-1, variant);
            variant.query('component[name="varlink"]')[0].setValue(gramvar['_text']);
          });
        }

        /*kolokace*/
        if (data['lemma']['lemma_type']) {
          if (['collocation', 'prislovi'].includes(data['lemma']['lemma_type'])) {
            Ext.getCmp('tabForm').query('component[inputValue="collocation"]')[0].setValue(true);
            Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].show();            
          } else if (data['lemma']['lemma_type'] == 'predpona') {
            Ext.getCmp('tabForm').query('component[inputValue="predpona"]')[0].setValue(true);
          } else {
            Ext.getCmp('tabForm').query('component[inputValue="single"]')[0].setValue(true);
          }
        }
        if (data['collocations'] && data['collocations']['status']) {
          change_stav(Ext.getCmp('boxcolloc').query('component[name="stavcont"]')[0], data['collocations']['status']);
        }
        if (data['collocations'] && data['collocations']['colloc']) {
          data['collocations']['colloc'].forEach(function(colloc) {
            var col = create_colloc(id);
            Ext.getCmp('colbox').insert(Ext.getCmp('colbox').items.length-1, col);
            col.query('component[name="colid"]')[0].setValue(colloc);
          });
        }

        /* vyznamy */
        var add_class_rels = {};
        if (data['meanings'] && data['meanings'].length > 0) {
          Ext.getCmp('vyznamy_box').query('component[name="vyznam"]')[0].destroy();
          data['meanings'].sort(function(a,b) {return parseInt(a['number']) - parseInt(b['number'])}).forEach(function(meaning) {
            var vyznam = create_vyznam(id, false, meaning['id']);
            Ext.getCmp('vyznamy_box').insert(Ext.getCmp('vyznamy_box').items.length-1,vyznam);
            if (meaning['author']) Ext.getCmp(vyznam.id+'_copybox').query('component[name="copy_autor"]')[0].setValue(meaning['author']);
            if (meaning['admin']) Ext.getCmp(vyznam.id+'_copybox').query('component[name="copy_admin"]')[0].setValue(meaning['admin']);
            if (meaning['source']) Ext.getCmp(vyznam.id+'_copybox').query('component[name="copy_zdroj"]')[0].setValue(meaning['source']);
            if (meaning['number']) vyznam.query('component[name="meaning_nr"]')[0].setValue(meaning['number']);
            if (meaning['oblast']) vyznam.query('component[name="vyzn_oblast"]')[0].setValue(meaning['oblast']);
            if (meaning['pracskupina']) vyznam.query('component[name="pracskupina"]')[0].setValue(meaning['pracskupina']);
            if (meaning['text'] && meaning['text']['_text']) {
              vyznam.query('component[name="'+vyznam.id+'_text"]')[0].setValue($.trim(meaning['text']['_text']));
            }
            change_stav(vyznam.query('component[name="stavcont"]')[0], meaning['status']);
            if (meaning['is_translation_unknown'] && meaning['is_translation_unknown'] == '1') vyznam.query('component[name="translation_unknown"]')[0].setValue(true);
            /* relations */
            if (meaning['relation']) {
              var vztahy = new Array();
              meaning['relation'].forEach(function(trans) {
                var parentid = vyznam.query('component[name="relbox"]')[0].id;
                var transset = create_vyznam_links(parentid);
                var type = trans['type'];
                var target = dictcode;
                if (type == 'translation') {
                  if (trans['target'] == null || trans['target'] == '') {
                    target = 'czj';
                  } else {
                    target = trans['target'];
                  }
                  type = trans['type'] + '_' + target;
                }
                transset.query('component[name="type"]')[0].setValue(type);
                transset.query('component[name="type"]')[0].addCls('relation_'+type);
                if (trans['meaning_id'] != "") {
                  transset.query('component[name="rellink"]')[0].setValue(trans['meaning_id']);
                } else if (trans['entry'] && trans['entry']['lemma']['title']) {
                  transset.query('component[name="rellink"]')[0].setValue(trans['entry']['lemma']['title']);
                }
                if (trans['status']) change_stav(transset.query('component[name="stavcont"]')[0], trans['status']);
                //zobrazeni textu nebo obrazku
                if (target == 'cs' || target == 'en' || target == 'sj' || target == 'de' || target == 'uk' ) {
                  if (trans['entry'] && trans['entry']['lemma']['title']) {
                    transset.query('component[name="vztahtitle"]')[0].update(trans['entry']['lemma']['title']);
                  }
                } else {
                  if (trans['entry'] && trans['entry']['lemma']['video_front']) {
                    var videoloc = trans['entry']['lemma']['video_front'];
                    transset.query('component[name="vztahtitle"]')[0].update('<div class="videofancybox" data-ratio="0.8" class="usage" style="width:120px; cursor: zoom-in;"><video class='+target+' width="80px" poster="https://www.dictio.info/thumb/video'+target+'/'+videoloc+'" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video'+target+'/'+videoloc+'"></source></video></div>')
                    transset.query('component[name="vztahtitle"]')[0].setHeight(60);
                  }
                }
                var inner = transset.query('component[name="vztahtitle"]')[0].id + "-innerCt";
                if (trans['title_only'] == 'true' || trans['meaning_id'].match(/^[0-9]*-[_us0-9]*$/) == null) {
                  add_class_rels[inner] = 'redtext';
                } else {
                  add_class_rels[inner] = 'text-'+target;
                  transset.query('component[name=row2]')[0].hide();
                }
                if (trans['notrans'] && trans['notrans'] == true && trans['meaning_id'].match(/^[0-9]*-[_us0-9]*$/) == null) {
                  transset.query('component[name=notrans]')[0].setValue(true);
                  transset.query('component[name=notransuser]')[0].setValue(trans['notransuser']);
                }
                vztahy.push({type:type, meaningid:trans['meaning_id'], link:transset, transinfo:trans});
              });
              //sort 
              var vztahysort = {synonym: 1, translation_cs: 2, translation_czj: 3, translation_en: 4, translation_is: 5, translation_asl: 6, translation_sj: 7, translation_spj: 8, translation_de: 9, translation_ogs: 10}
              vztahy.sort(function(a, b) {
                var diff = vztahysort[a.type] - vztahysort[b.type];
                if (diff != 0) {
                  return diff;
                }
                if (a.meaningid < b.meaningid) {
                  return -1;
                }
                if (a.meaningid > b.meaningid) {
                  return 1;
                }
                return 0;
              });
              //add sorted relation
              var parentid = vyznam.query('component[name="relbox"]')[0].id;
              vztahy.forEach(function(relation) {
                var cc = create_comment_button(relation.link.id, 'meaning'+meaning['id']+'rel'+relation.transinfo['target']+relation.transinfo['meaning_id'])
                relation.link.query('component[name=row2]')[0].add(cc);
                Ext.getCmp(parentid).insert(Ext.getCmp(parentid).items.length-3, relation.link);
              });
            }
            /* usages */
            ar_priklady[meaning['id']] = 0;
            if (meaning['usages']) {
              var j = 0;
              meaning['usages'].forEach(function(usage) {
                var usageid, usagec;
                var priklad = create_priklad(vyznam.id+'_uziti', id, false, meaning['id']);
                if (usage['id'] && usage['id'] != '') {
                  usageid = usage['id'];
                  usagec = parseInt(usageid.replace(/[0-9\-]*_us/,''));
                  priklad.query('[name="usage_id"]')[0].setValue(usageid);
                } else {
                  usagec = j;
                }
                if (ar_priklady[meaning['id']] < usagec) {
                  ar_priklady[meaning['id']] = usagec;
                }
                Ext.getCmp(vyznam.id+'_uziti').insert(Ext.getCmp(vyznam.id+'_uziti').items.length-1, priklad);
                if (usage['author']) Ext.getCmp(priklad.id+'copyright_copybox').query('component[name="copy_autor"]')[0].setValue(usage['author']);
                if (usage['admin']) Ext.getCmp(priklad.id+'copyright_copybox').query('component[name="copy_admin"]')[0].setValue(usage['admin']);
                if (usage['source']) Ext.getCmp(priklad.id+'copyright_copybox').query('component[name="copy_zdroj"]')[0].setValue(usage['source']);
                if (usage['type'] == 'colloc') {
                  priklad.query('[inputValue=colloc]')[0].setValue(true);
                } else {
                  priklad.query('[inputValue=sentence]')[0].setValue(true);
                }
                /* relations */
                if (usage['relation']) {
                  usage['relation'].forEach(function(trans) {
                    var parentid = priklad.query('component[name="exrelbox"]')[0].id;
                    var transset = create_priklad_links(parentid);
                    Ext.getCmp(parentid).insert(Ext.getCmp(parentid).items.length-1,transset);
                    var type = trans['type'];
                    var target = dictcode;
                    if (type == 'translation') {
                      if (trans['target'] == null || trans['target'] == '') {
                        target = 'czj';
                      } else {
                        target = trans['target'];
                      }
                      type = trans['type'] + '_' + target;
                    }
                    transset.query('component[name="type"]')[0].setValue(type);
                    transset.query('component[name="rellink"]')[0].setValue(trans['meaning_id']);
                  });
                }

                change_stav(priklad.query('component[name="stavcont"]')[0], usage['status']);
                textval = '';
                if (usage['text'] && usage['text']['_text']) textval = usage['text']['_text'];
                priklad.query('component[name="'+priklad.id+'_text"]')[0].setValue($.trim(textval));
                ar_priklady[meaning['id']]++;
                j++;
              });
            }
          });
        }

        console.log('load end ' + new Date().getTime())
        update_stav();
        Ext.resumeLayouts(true);
        Ext.ComponentQuery.query('[name=ssc_html]')[0].up().setHeight(Ext.ComponentQuery.query('[name=ssc_html]')[0].getHeight());
        check_perm(Ext.getCmp('tabForm').query('[name=pracskupina]')[0].getValue(), Ext.getCmp('tabForm').query('[name=userskupina]')[0].getValue(), Ext.getCmp('tabForm').query('[name=userperm]')[0].getValue());
        loadMask.hide();
        console.log('after mask ' + new Date().getTime());
        add_video_fancybox();
        for (let [key, value] of Object.entries(add_class_rels)) {
          document.getElementById(key).classList.add(value);
        }
        console.log('layout end ' + new Date().getTime());
        track_change();
        entry_updated = false;
      } else {
        Ext.resumeLayouts(true);
        loadMask.hide();
        Ext.Msg.alert('Error', locale[lang]['no_entry']+': '+dictcode.toUpperCase()+' '+id, function() {
          window.location = '/';
        });
      }
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
          c.on('change', function(e) {
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
      c.on('click', function(e) {
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
      change = 'pridat '+elparent.title;
      if (element.name == 'relsadd') {
        change = 'pridat vztah ';
        change += 'vyznam ' + elparent.query('component[name="meaning_id"]')[0].getValue();
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

function entry_update_show(updated) {
  if (updated) {
    document.title = dictcode.toUpperCase()+' ' + entryid + ' *';
    Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase()+'-' + entryid);
    Ext.getCmp('tabForm').query('component[name=modifiedlabel]')[0].setText(' * '+locale[lang].modified);

  } else {
    document.title = dictcode.toUpperCase()+' ' + entryid;
    Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase()+'-' + entryid);
    Ext.getCmp('tabForm').query('component[name=modifiedlabel]')[0].setText('');
  }
}

function save_doc(id) {
  var tracking = changes.filter(function (value, index, self) { return self.indexOf(value) === index;}).join(", ");
  changes = new Array();
  var data = {
    'dict': dictcode,
    'id': id.toString(),
    'track_changes': tracking,
    'lemma':{
      'updated_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s'),
      'created_at': entrydata['lemma']['created_at'],
      'completeness': Ext.getCmp('tabForm').query('component[name="completeness"]')[0].getValue(),
      'pracskupina': Ext.getCmp('tabForm').query('component[name="pracskupina"]')[0].getValue(),
      'admin_comment': Ext.getCmp('tabForm').query('component[name="admin_comment"]')[0].getValue(),
      'status': Ext.getCmp('tabForm').query('component[name="stav"]')[0].getValue(),
      'title': Ext.getCmp('tabForm').query('component[name="lemma"]')[0].getValue(),
      'title_var': Ext.getCmp('tabForm').query('component[name="lemma_var"]')[0].getValue(),
      'pron': Ext.getCmp('tabForm').query('component[name="pron"]')[0].getValue(),
      'puvod': Ext.getCmp('tabForm').query('component[name="puvod_slova"]')[0].getValue(),
      'grammar_note': [{
        '_text': Ext.getCmp('tabForm').query('component[name="gramatikatext_text"]')[0].getValue(), 
        '@flexe_neskl': Ext.getCmp('gramdesc').query('component[name="flexe_neskl"]')[0].getValue(),
        '@author': Ext.getCmp('gramdesc').query('component[name="copy_autor"]')[0].getValue(),
        '@source': Ext.getCmp('gramdesc').query('component[name="copy_zdroj"]')[0].getValue(),
        '@admin': Ext.getCmp('gramdesc').query('component[name="copy_admin"]')[0].getValue(),
        '@status': Ext.getCmp('gramdesc').query('component[name="stav"]')[0].getValue(),
        'variant': []
      }],
      'style_note': [{
        '_text': Ext.getCmp('tabForm').query('component[name="styltext_text"]')[0].getValue(), 
        '@kategorie': Ext.getCmp('styldesc').query('component[name="kategorie"]')[0].getValue().join(';'),
        '@stylpriznak': Ext.getCmp('styldesc').query('component[name="stylpriznak"]')[0].getValue().join(';'),
        '@author': Ext.getCmp('styldesc').query('component[name="copy_autor"]')[0].getValue(),
        '@source': Ext.getCmp('styldesc').query('component[name="copy_zdroj"]')[0].getValue(),
        '@admin': Ext.getCmp('styldesc').query('component[name="copy_admin"]')[0].getValue(),
        '@status': Ext.getCmp('styldesc').query('component[name="stav"]')[0].getValue(),
        'variant': []
      }],
    }
  };
  if (entrydata['html'] != undefined && entrydata['html'] != '') {
    data['html'] = entrydata['html'];
  }
  /* gramatika */
  var grams = Ext.getCmp('gramcont').query('[name=gramitem]');
  for (var i = 0; i < grams.length; i++) {
    if (i == 0) {
      data.lemma.grammar_note[0]['@slovni_druh'] = grams[i].query('component[name="slovni_druh"]')[0].getValue();
      data.lemma.grammar_note[0]['@skupina'] = grams[i].query('component[name="skupina"]')[0].getValue().join(';');
      data.lemma.grammar_note[0]['@skupina2'] = grams[i].query('component[name="skupina2"]')[0].getValue().join(';');
    } else {
      data.lemma.grammar_note.push({
        '@slovni_druh': grams[i].query('component[name="slovni_druh"]')[0].getValue(),
        '@skupina': grams[i].query('component[name="skupina"]')[0].getValue().join(';'),
        '@skupina2': grams[i].query('component[name="skupina2"]')[0].getValue().join(';'),
      });
    }
  }
  /*slovni spojeni*/
  if (Ext.getCmp('tabForm').query('component[name="lemma_type"]')[0].getGroupValue() != null) {
    data.lemma.lemma_type = Ext.getCmp('tabForm').query('component[name="lemma_type"]')[0].getGroupValue();
  }
  if (data.lemma.lemma_type != 'single') {
    data.collocations = {'status': Ext.getCmp('boxcolloc').query('component[name="stav"]')[0].getValue()};
    data.collocations.colloc = [];
    var cols = Ext.getCmp('colbox').query('component[name="colitem"]');
    for (var i = 0; i < cols.length; i++) {
      data.collocations.colloc.push(cols[i].query('component[name="colid"]')[0].getValue());
    }
  }
  
  /*deklinace*/
  var dekls = Ext.getCmp('deklcont').query('[name=deklinitem]');
  for (var i = 0; i < dekls.length; i++) {
    var tag = dekls[i].query('component[name="dekl_tag"]')[0].getValue();
    var tvar = dekls[i].query('component[name="dekl_tvar"]')[0].getValue();
    if (tvar != '') {
      if (data.lemma.gram == undefined) {
        data.lemma.gram = {'form': new Array()};
      }
      data.lemma.gram.form.push({'_text': tvar, '@tag': tag});
    }
  }

  /* varianty */
  var variants = Ext.getCmp('styldesc').query('[name=varlink]');
  var variants_ar = new Array();
  for (var i = 0; i < variants.length; i++) {
    var varvid = variants[i].getValue();
    if (varvid != '' && variants_ar.indexOf(varvid) == -1) {
      variants_ar.push(varvid);
      data.lemma.style_note[0].variant.push({'_text':varvid});
    }
  }
  var variants = Ext.getCmp('gramdesc').query('[name=varlink]');
  var variants_ar = new Array();
  for (var i = 0; i < variants.length; i++) {
    var varvid = variants[i].getValue();
    if (varvid != '' && variants_ar.indexOf(varvid) == -1) {
      variants_ar.push(varvid);
      data.lemma.grammar_note[0].variant.push({'_text':varvid});
    }
  }

  /* meanings */
  var maxnr = 0;
  var meanings = Ext.getCmp('tabForm').query('component[name="vyznam"]');
  if (meanings.length > 0) {
    data.meanings = [];
  }
  var mean_numbers = new Array();
  var max_mean = 0;
  for (var i = 0; i < meanings.length; i++) {
    var newmean = {
      'id': meanings[i].query('component[name="meaning_id"]')[0].getValue(),
      'status': meanings[i].query('[name=vyznammeta]')[0].query('component[name="stav"]')[0].getValue(),
      'updated_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s'),
      'relation': [],
      'author': Ext.getCmp(meanings[i].id+'_copybox').query('component[name="copy_autor"]')[0].getValue(),
      'source': Ext.getCmp(meanings[i].id+'_copybox').query('component[name="copy_zdroj"]')[0].getValue(),
      'admin': Ext.getCmp(meanings[i].id+'_copybox').query('component[name="copy_admin"]')[0].getValue(),
      'oblast': meanings[i].query('component[name="vyzn_oblast"]')[0].getValue().join(';'),
      'pracskupina': meanings[i].query('component[name="pracskupina"]')[0].getValue(),
    };
    maxnr += 1;
    if (isNaN(parseInt(meanings[i].query('component[name="meaning_nr"]')[0].getValue()))) {
      newmean['number'] = maxnr;
    } else {
      newmean['number'] = parseInt(meanings[i].query('component[name="meaning_nr"]')[0].getValue());
    }
    mean_numbers.push(newmean['number']);
    if (max_mean < newmean['number']) {
      max_mean = newmean['number'];
    }

    if (meanings[i].query('component[name="meaning_id"]')[0].getValue() != '' && entrydata['meanings'] && entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0] != undefined) {
      newmean.created_at = entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0]['created_at'];
    } else {
      newmean.created_at = Ext.Date.format(new Date(), 'Y-m-d H:i:s');
    }
    if (meanings[i].query('component[name="translation_unknown"]')[0].getValue()) {
      newmean.is_translation_unknown = '1';
    }
    /* preklady,odkazy */
    var trset = meanings[i].query('component[name="rellinkset"]');
    var trset_ar = new Array();
    for (var j = 0; j < trset.length; j++) {
      if (trset[j].query('component[name="rellink"]')[0].getValue() != null && trset[j].query('component[name="rellink"]')[0].getValue() != "" && trset[j].query('component[name="type"]')[0].getValue() != "") {
        var rellink = trset[j].query('component[name="rellink"]')[0].getValue();
        if (rellink.match(/^[0-9]*$/) != null) {
          rellink += '-1';
        }
        var reltype = trset[j].query('component[name="type"]')[0].getValue();
        var reltar = dictcode;
        if (reltype != null && reltype.startsWith('translation_') && reltype != 'translation_colloc') {
          reltar = reltype.split('_')[1];
          reltype = 'translation';
        }
        if ((trset_ar.indexOf(reltype+rellink+reltar) == -1) && (!(rellink.startsWith(id+'-')) || reltype == 'translation' || reltype == 'translation_colloc')) {
          trset_ar.push(reltype+rellink+reltar);
          newrel = {
            'meaning_id': rellink,
            'type': reltype,
            'target': reltar,
            'status': trset[j].query('component[name="stav"]')[0].getValue()
          };
          if (trset[j].query('component[name=notrans]')[0].checked && rellink.match(/^[0-9]*-[_us0-9]*$/) == null) {
            newrel.notrans = true;
            newrel.notransuser = trset[j].query('component[name=notransuser]')[0].value;
          }
          newmean.relation.push(newrel);
        }
      }
    }
    newmean.text = {'_text': meanings[i].query('component[name="'+meanings[i].id+'_text"]')[0].getValue()};
    
    /*priklady*/
    var uses = meanings[i].query('component[name="usageset"]');
    if (uses.length > 0) {
      newmean.usages = [];
    }
    for (var j = 0; j < uses.length; j++) {
      var newuse = {
        'id': uses[j].query('component[name="usage_id"]')[0].getValue(),
        'updated_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s'),
        'status': uses[j].query('component[name="stav"]')[0].getValue(),
        'text': {},
        'author': uses[j].query('component[name="copy_autor"]')[0].getValue(),
        'source': uses[j].query('component[name="copy_zdroj"]')[0].getValue(),
        'admin': uses[j].query('component[name="copy_admin"]')[0].getValue(),
      };
      var trset = uses[j].query('component[name="exrellinkset"]');
      var trset_ar = new Array();
      if (trset.length > 0) {
        newuse.relation = [];
      }
      for (var k = 0; k < trset.length; k++) {
        if (trset[k].query('component[name="rellink"]')[0].getValue() != null && trset[k].query('component[name="rellink"]')[0].getValue() != "" && trset[k].query('component[name="type"]')[0].getValue() != "") {
          var rellink = trset[k].query('component[name="rellink"]')[0].getValue();
          if (rellink.match(/^[0-9]*$/) != null) {
            rellink += '-1';
          }
          var reltype = trset[k].query('component[name="type"]')[0].getValue();
          var reltar = dictcode;
          if (reltype != null && reltype.startsWith('translation_') && reltype != 'translation_colloc') {
            reltar = reltype.split('_')[1];
            reltype = 'translation';
          }
          if ((trset_ar.indexOf(reltype+rellink+reltar) == -1) && (!(rellink.startsWith(id+'-')) || reltype == 'translation' || reltype == 'translation_colloc')) {
            trset_ar.push(reltype+rellink+reltar);
            newuse.relation.push({
              'meaning_id': rellink,
              'type': reltype,
              'target': reltar,
            });
          }
        }
      }
      if (uses[j].query('[inputValue=colloc]')[0].getValue()) {
        newuse['type'] = 'colloc';
      } else {
        newuse['type'] = 'sentence';
      }
      if (uses[j].query('component[name="usage_id"]')[0].getValue() != '' && entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0] != undefined && entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0]['usages'] != undefined && entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0]['usages'].filter(usg=>usg['id'] == uses[j].query('component[name="usage_id"]')[0].getValue())[0] != undefined) {
        newuse.created_at = entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0]['usages'].filter(usg=>usg['id'] == uses[j].query('component[name="usage_id"]')[0].getValue())[0]['created_at'];
      } else {
        newuse.created_at = Ext.Date.format(new Date(), 'Y-m-d H:i:s');
      }
      newuse.text = {'_text': uses[j].query('component[name="'+uses[j].id+'_text"]')[0].getValue()};

      newmean.usages.push(newuse);
    }

    data.meanings.push(newmean);
  }
  var numbers_ok = true;
  for (var i = 1; i <= max_mean; i++) {
    if (!(mean_numbers.includes(i))) {
      numbers_ok = false;
    }
  }
  if (numbers_ok == false) {
    alert('Pořadí významů neobsahuje všechny významy nebo obsahuje špatné pořadí.');
  }
  console.log(data)

  return data;
}


function reload_rel(search, field, target) {
  relationlist.loadData([], false);
  Ext.Ajax.request({
    url: '/'+target+'/relfind',
    params: {
      search: search,
    },
    method: 'get',
    success: function(response) {
      /* fill media info */
      relationlist.loadData([], false);
      var data = JSON.parse(response.responseText);
      Ext.suspendLayouts();
      var html = '';
      for (i = 0; i < data.length; i++) {
        if (data[i] != undefined && data[i].id && !(data[i].id.startsWith(entryid+'-'))) {
          try {
            relationlist.add({id: data[i].id, title: data[i].title, number: data[i].number, def: data[i].def, loc: data[i].loc, target: data[i].target, front: data[i].front});
          } catch(er) {
            console.log(data[i]);
            console.log(er);
          }
        }
      }
      Ext.resumeLayouts(true);
      field.expand();
    }
  });
}
function reload_link(search, field) {
  linklist.loadData([], false);
  Ext.Ajax.request({
    url: '/'+dictcode+'/linkfind',
    params: {
      search: search,
    },
    method: 'get',
    success: function(response) {
      /* fill media info */
      var data = JSON.parse(response.responseText);
      Ext.suspendLayouts();
      var html = '';
      for (i = 0; i < data.length; i++) {
        if (!(data[i].id == entryid)) {
          linklist.add({id: data[i].id, title: data[i].title, label: data[i].label});
        }
      }
      Ext.resumeLayouts(true);
      field.expand();
    }
  });
}

function change_stav(stavcont, novystav) {
  if (novystav == 'published') {
    stavcont.query('[name=stav]')[0].setValue('published');
    stavcont.query('[name=stavdisp]')[0].setValue(locale[lang].published);
    stavcont.query('[name=stavbutton]')[0].setText(locale[lang].hide);
  } else {
    stavcont.query('[name=stav]')[0].setValue('hidden');
    stavcont.query('[name=stavdisp]')[0].setValue(locale[lang].hidden);
    stavcont.query('[name=stavbutton]')[0].setText(locale[lang].publish);
  }
}

function create_stav() {
  var stav = Ext.create('Ext.container.Container', {
    layout: {
      type: 'hbox'
    },
    name: 'stavcont',
    items: [{
      xtype: 'textfield',
      disabled: true,
      name: 'stav',
      value: 'hidden',
      hidden: true
    },{
      xtype: 'displayfield',
      value: locale[lang].hidden,
      name: 'stavdisp',
      cls: 'stav-display',
      width: 80
    },{
      xtype: 'button',
      name: 'stavbutton',
      text: locale[lang].publish,
      width: 90,
      handler: function() {
        Ext.suspendLayouts();
        var par = this.up('[name=stavcont]');
        if (par.query('[name=stav]')[0].getValue() == 'published') {
          par.query('[name=stav]')[0].setValue('hidden');
          par.query('[name=stavdisp]')[0].setValue(locale[lang].hidden);
          par.query('[name=stavbutton]')[0].setText(locale[lang].publish);
        } else {
          par.query('[name=stav]')[0].setValue('published');
          par.query('[name=stavdisp]')[0].setValue(locale[lang].published);
          par.query('[name=stavbutton]')[0].setText(locale[lang].hide);
        }
        Ext.resumeLayouts(true);
      }
    }]
  });
  stav.query('[name=stav]')[0].setValue('hidden');
  return stav;
}

function create_src_list(textid) {
  var select = Ext.create('Ext.form.field.ComboBox', {
    id: 'srclist'+Ext.id(),
    cls: 'src_select',
    matchFieldWidth: false,
    value: '...',
    width: 40,
    queryMode: 'local',
    store: ['MU', 'Středisko Teiresiás', 'UPOL', 'Teiresiás S2', 'Teiresiás 1','Teiresiás 3','Teiresiás 3a', 'Teiresiás OBZ'],
    listeners:{
      'select': function(combo, record, index) {
        if (combo.getValue() != '') {
          Ext.getCmp(textid).setValue(combo.getValue(),false);
        }
      }
    },
  });
  return select;
}

function create_copy_button(idstart) {
  var button = Ext.create('Ext.button.Button', {
    text: 'copyright',
    id: idstart+'_copy_button',
    handler: function() {
      Ext.getCmp(idstart+'_copybox').show();
    }
  });
  return button;
}

function create_copyright(idstart, hidden) {
  if (hidden == undefined) {
    hidden = true;
  }
  var copy = Ext.create('Ext.container.Container', {
    id: idstart+'_copybox',
    style: {backgroundColor: bgAuth},
    name: 'copybox',
    hidden: hidden,
    layout: {
      type: 'hbox'
    },
    items: [{
      xtype: 'container',
      layout: {
        type: 'hbox'
      },
      items: [{
        fieldLabel: locale[lang].author,
        xtype: 'textfield',
        id: idstart+'_autor',
        name: 'copy_autor'
      },create_src_list(idstart+'_autor')]
    },/*{
      xtype: 'container',
      layout: {
        type: 'hbox'
      },
      items: [{
        fieldLabel: 'copyright',
        xtype: 'textfield',
        id: idstart+'_copy',
        name: 'copy_copy'
      },create_src_list(idstart+'_copy')]
    },*/{
      xtype: 'container',
      layout: {
        type: 'hbox'
      },
      items: [{
        fieldLabel: locale[lang].source,
        xtype: 'textfield',
        width: 500,
        id: idstart+'_zdroj',
        name: 'copy_zdroj'
      },create_src_list(idstart+'_zdroj')]
    },{
      fieldLabel: locale[lang].admincomment,
      xtype: 'textfield',
      width: 300,
      id: idstart+'_poznamka',
      name: 'copy_admin'
    }]
  });
  return copy;
}

function create_copyrightM(idstart, hidden) {
  if (hidden == undefined) {
    hidden = true;
  }
  var copy = Ext.create('Ext.container.Container', {
    id: idstart+'_copybox',
    name: 'copybox',
    style: {backgroundColor: bgAuth},
    hidden: hidden,
    layout: {
      type: 'hbox'
    },
    items: [{
        fieldLabel: locale[lang].author,
        labelWidth:50,
        width:180,
        xtype: 'textfield',
        id: idstart+'_autor',
        name: 'copy_autor'
      },create_src_list(idstart+'_autor'),
              /*{
        fieldLabel: 'copyright',
        labelWidth:50,
        width:120,
        xtype: 'textfield',
        id: idstart+'_copy',
        name: 'copy_copy'
      },create_src_list(idstart+'_copy'),
             */{
        fieldLabel: locale[lang].source,
        labelWidth:50,
        width:250,
        xtype: 'textfield',
        id: idstart+'_zdroj',
        name: 'copy_zdroj'
      },create_src_list(idstart+'_zdroj'),{
      fieldLabel: locale[lang].admincomment3,
      labelWidth:50,
      width:250,
      xtype: 'textfield',
      id: idstart+'_poznamka',
      name: 'copy_admin'
    }]
  });
  return copy;
}


function create_gram(entryid) {
  var name = 'gram_'+Ext.id();
  var text = Ext.create('Ext.container.Container', {
    layout: {
      type: 'hbox'
    },
    frame: true,
    cls: 'gramframe',
    id: name,
    name: 'gramitem',
    items: [{
        xtype: 'combobox',
        fieldLabel: locale[lang].lexicalcategory,
        name: 'slovni_druh',
        queryMode: 'local',
        displayField: 'text',
        valueField: 'value',
        store: posStore,
        forceSelection: true,
        autoSelect: true,
        editable: false,
        width: 300,
        listeners: {
          select: function(combo, record, index) {
            change_gram(name, combo.getValue());
          }
        }
      },{
        xtype: 'combobox',
        fieldLabel: locale[lang].subtype,
        name: 'skupina',
        queryMode: 'local',
        forceSelection: true,
        autoSelect: true,
        editable: false,
        displayField: 'text',
        valueField: 'value',
        multiSelect: true,              
      },{
        xtype: 'combobox',
        name: 'skupina2',
        queryMode: 'local',
        forceSelection: true,
        autoSelect: true,
        editable: false,
        displayField: 'text',
        valueField: 'value',
        multiSelect: true,              
      },{
        xtype: 'button',
        icon: '/editor/delete.png',
        handler: function() {
          Ext.getCmp(name).destroy();
        }
    }]
  });
  return text;
}

function create_deklin(entryid, tag) {
  var desc = '';
  if (tag == undefined) {
    tag = '';
  } else {
    if (dekl_desc[tag] != undefined) {
      desc = dekl_desc[tag];
    }
  }
  var name = 'var_'+Ext.id();
  var text = Ext.create('Ext.container.Container', {
        layout: {
          type: 'hbox'
        },
        id: name,
        name: 'deklinitem',
        items: [{
          xtype: 'textfield',
          width: 120,
          name: 'dekl_desc',
          disabled: true,
          value: desc,
          cls: 'deklin-label'
        },{
          xtype: 'textfield',
          width: 50,
          name: 'dekl_tag',          
          value: tag,
          cls: 'deklin-tag'
        },{
          xtype: 'textfield',
          width: 160,
          name: 'dekl_tvar',
        },{
          xtype: 'button',
          icon: '/editor/delete.png',
          handler: function() {
            Ext.getCmp(name).destroy();
          }
        }]
  });
  return text;
}

function update_deklin(type) {
  Ext.suspendLayouts();
  var dekls = Ext.getCmp('deklcont').query('[name=deklinitem]');
  for (var i = 0; i < dekls.length; i++) {
    dekls[i].destroy();
  }
  var tag_ar = new Array();
  switch(type) {
    case 'podst':
      tag_ar = new Array(
        'nSc1', 'nSc2', 'nSc3', 'nSc4', 'nSc5', 'nSc6', 'nSc7',
        'nPc1', 'nPc2', 'nPc3', 'nPc4', 'nPc5', 'nPc6', 'nPc7'
      );
      break;
    case 'prid':
      tag_ar = new Array(
        'd2', 'd3'
      );
      break;
    case 'slov':
      tag_ar = new Array(
        'mIp1nS', 'mIp2nS', 'mIp3nS', 'mIp1nP', 'mIp2nP', 'mIp3nP', 'mRp2nS', 'mRp2nP', 'mAgMnS', 'mNgMnS', 'gNnSc1', 'mSgMnS', 'mSgFnS', 'mSgMnP', 'mDgMnS', 'mDgFnS', 'mDgMnP'
      );
      break;
    case 'cisl':
      tag_ar = new Array(
        'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'cP1', 'cP2', 'cP3', 'cP4', 'cP5', 'cP6', 'cP7'  
      );
      break;
    case 'pris':
      tag_ar = new Array(
        'd2', 'd3'
      );
      break;
  }
  for (var i = 0; i < tag_ar.length; i++) {
    var sw = create_deklin(entryid, tag_ar[i]);
    Ext.getCmp('deklcont').insert(Ext.getCmp('deklcont').items.length-2,sw);
  }
  Ext.resumeLayouts(true);
}

function create_variant(entryid) {
  var name = 'var_'+Ext.id();
  var text = Ext.create('Ext.container.Container', {
        layout: {
          type: 'hbox'
        },
        id: name,
        name: 'variantitem',
        items: [{
          xtype: 'combobox',
          name: 'varlink',
          store: linklist,
          displayField: 'title',
          valueField: 'id',
          editable: true,
          queryMode: 'local',
          width: 220,
          listeners:{
            'select': function(combo, record, index) {
              if (combo.getValue() != '') {
                console.log(combo.getValue())
                combo.setRawValue(combo.getValue())
              }
            },
            specialkey: function(field, e) {
              if (e.getKey() == e.ENTER) {
                reload_link(field.getValue(), field);
              }
            }
          },
        },{
          xtype: 'button',
          icon: '/editor/delete.png',
          handler: function() {
            Ext.getCmp(name).destroy();
          }
        }]
  });
  return text;
}

function create_text_video(idstart, entryid, label, show_copy) {
  if (show_copy == undefined || show_copy == true) {
    var copybutton = create_copy_button(idstart);
  } else {
    var copybutton = null;
  }
  var text = Ext.create('Ext.container.Container', {
        layout: {
          type: 'hbox'
        },
        items: [{
          xtype: 'textarea',
          fieldLabel: label,
          id: idstart+'_text',
          name: idstart+'_text',
          width: 500,
        },{
          xtype: 'combobox',
          name: idstart+'_video',
          store: filelist,
          displayField: 'location',
          valueField: 'id',
          editable: true,
          queryMode: 'local',
          width: 160,
          grow: true,
          enableKeyEvents: true,
          listeners:{
            'render': function(field, opts) {
              field.updatetask = new Ext.util.DelayedTask(function(){
                console.log('*updatelist*')
                /* search video, update filelist store */
                if (entryid == undefined) {
                  var eid = g_entryid;
                } else {
                  var eid = entryid;
                }
                console.log('eid'+eid);
                console.log(field);
                console.log(field.getRawValue() + ' - ' +field.getValue());
                if (field.getValue().length > 2) {
                  reload_files(eid, field.getValue())
                }
              });
            },
            'select': function(combo, record, index) {
              if (combo.getValue() != '') {
                Ext.getCmp('tabForm').query('component[name="'+idstart+'_text"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="'+idstart+'_text"]')[0].getValue()+' <file media_id="'+combo.getValue()+'"/>');
              }
            },
            'keypress': function(field, e, opts) {
              console.log('keypress, set delay')
              /* delay if another key pressed */
              field.updatetask.delay(600);
            }
          },
          listConfig: {
            getInnerTpl: function() {
              return '<div><img width="80" src="/media/video/thumb/{location}/thumb.jpg">{location}</div>';
            }
          }
        },{
          xtype: 'label',
          name: idstart+'_preview',
          //html: '<img src="/media/'+entryid+'/1361882822-sign_1402_sign_side.flv_thumb.jpg" width="80"/>'
        }]
  });
  return text;
}

function refresh_relations(parentid, set_rel) {
  var trset = Ext.getCmp(parentid).query('component[name="rellinkset"]');
  for (var j = 0; j < trset.length; j++) {
    //Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function(item) {item.hide()});
    Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function(item) {item.show()});
    if (trset[j].query('component[name="rellink"]')[0].getValue() != null && trset[j].query('component[name="rellink"]')[0].getValue() != "" && trset[j].query('component[name="type"]')[0].getValue() != "") {
      var rellink = trset[j].query('component[name="rellink"]')[0].getValue();
      var reltype = trset[j].query('component[name="type"]')[0].getValue();
      var reltar = dictcode;
      if (reltype.startsWith('translation_')) {
        reltar = reltype.split('_')[1];
        reltype = 'translation';
      }
      load_link_relations(reltar, trset[j].query('component[name="rellink"]')[0], trset[j].id, parentid, set_rel);
    }
  }
  changes.push("obnovit preklady");
  track_change();

}

function get_selected_dict() {
  cook_ar = Ext.util.Cookies.get('dictio_pref').split(';');
  selected = new Array();
  cook_ar.forEach(function(el) {
    if (el.startsWith('dict-') && el.endsWith('=true')) {
      var selcode = el.substring(5, el.indexOf('='))
      selected.push(selcode);
    }
  });
  return selected;
}

function load_link_relations(target, combo, name, parentid, set_rel) {
  if (entrydata.user_info.login == 'najbrtova') {
    return true;
  }
  //Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function(item) {item.hide()});
  Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function(item) {item.show()});
  Ext.Ajax.request({
    url: '/'+target+'/getrelations',
    timeout: 30000,
    params: {
      meaning_id: combo.getValue(),
      type: set_rel
    },
    method: 'get',
    failure: function() {
      //waitBoxRels.hide();
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function(item) {item.show()});
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function(item) {item.hide()});
    },
    success: function(response) {
      //waitBoxRels.hide();
      var trset = Ext.getCmp(name).up().query('component[name="rellinkset"]');
      var trset_ar = new Array();
      var selected_dicts = get_selected_dict();
      for (var j = 0; j < trset.length; j++) {
        if (trset[j].query('component[name="rellink"]')[0].getValue() != null && trset[j].query('component[name="rellink"]')[0].getValue() != "" && trset[j].query('component[name="type"]')[0].getValue() != "") {
          var rellink = trset[j].query('component[name="rellink"]')[0].getValue();
          var reltype = trset[j].query('component[name="type"]')[0].getValue();
          var reltar = dictcode;
          if (reltype.startsWith('translation_')) {
            reltar = reltype.split('_')[1];
            reltype = 'translation';
          }
          trset_ar.push(reltype+rellink+reltar);
        }
      }
      var linkrels = JSON.parse(response.responseText);
      Ext.each(linkrels, function(relitem) {
        //eg. synonym in other dictionary is translation for this dictionary
        //translation to this dictionary is synonym
        if (relitem.type != 'translation' && relitem.target != dictcode) {
          relitem.type = 'translation';
        }
        if (relitem.type == 'translation' && relitem.target == dictcode) {
          relitem.type = 'synonym';
        }
        var newtype = relitem.type;
        if (relitem.type == 'translation') {
          newtype = 'translation_' + relitem.target;
        }
        //skip the same entry, skip if same link already present
        if ((!(relitem.target == dictcode && relitem.meaning_id.startsWith(entryid+'-'))) && (trset_ar.indexOf(relitem.type+relitem.title+relitem.target) == -1) && (trset_ar.indexOf(relitem.type+relitem.meaning_id+relitem.target) == -1) && selected_dicts.includes(relitem.target)) {
          //add
          var newrel = create_vyznam_links(parentid);
          Ext.getCmp(parentid).insert(Ext.getCmp(parentid).items.length-3, newrel);
          newrel.query('component[name="type"]')[0].setValue(newtype);
          if (relitem.title != '') {
            newrel.query('component[name="rellink"]')[0].setValue(relitem.title);
          } else {
            newrel.query('component[name="rellink"]')[0].setValue(relitem.meaning_id.split('-')[0]);
          }
          newrel.query('component[name="vztahtitle"]')[0].update(relitem.meaning_id);
          var inner = newrel.query('component[name="vztahtitle"]')[0].id + '-innerCt';
          if (document.getElementById(inner) != null) {
            document.getElementById(inner).classList.add('redtext');
          }
        }
      });
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function(item) {item.show()});
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function(item) {item.hide()});
    }
  });
}

function create_vyznam_links(parentid) {
  var name = 'rellink'+Ext.id();

  var transset = Ext.create('Ext.container.Container', {
    border: false,
    id: name,
    cls: 'rellinkset',
    name: 'rellinkset',
    layout: {
      type: 'vbox',
      align: 'right'
    },
    items: [{
      xtype: 'container',
      layout: {
        type: 'hbox'
      },
      items: [{
        xtype: 'combobox',
        name: 'type',
        queryMode: 'local',
        displayField: 'text',
        valueField: 'value',
        store: typeStore,
        forceSelection: true,
        autoSelect: true,
        editable: false,
        allowBlank: true,
        width: 120,
      },{
        xtype: 'panel',
        name: 'vztahtitle',
        cls: 'vztah-title',
        html: '',
        width: 130,
        autoHeight: true
      },{
        xtype: 'combobox',
        name: 'rellink',
        store: relationlist,
        displayField: 'title',
        valueField: 'id',
        editable: true,
        queryMode: 'local',
        width: 210,
        opened: false,
        listeners:{
          'blur': function(combo) {
            if (Ext.getCmp(name).query('component[name="type"]')[0].getValue() != null && combo.getValue() != null) {
              if ((!(Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_'))) && combo.getValue().startsWith(entryid+'-')) {
                Ext.Msg.alert('',locale[lang]['warn_same_entry']);
              }
              var rellink = combo.getValue();
              if (rellink.match(/^[0-9]*-[0-9]*/) == null) {
                var prevbox = Ext.getCmp(combo.id).up().query('component[name="vztahtitle"]')[0];
                prevbox.update(rellink);
                document.getElementById(prevbox.id+"-innerCt").classList.add('redtext');
              } else {
                Ext.getCmp(name).query('component[name="row2"]')[0].hide();
              }
            }
          },
          'select': function(combo, record, index) {
            if (combo.getValue() != '') {
              console.log(combo.getValue())
              combo.setRawValue(combo.getValue())
              var type = Ext.getCmp(name).query('component[name="type"]')[0].getValue();
              var target = dictcode;
              if (type.startsWith('translation_')) {
                var tar = type.split('_');
                target = tar[1];
              }
              //ajax load preview
              Ext.Ajax.request({
                url: '/'+target+'/relationinfo',
                params: {
                  meaning_id: combo.getValue()
                },
                method: 'get',
                success: function(response) {
                  var rinfo = response.responseText;
                  var prevbox = Ext.getCmp(combo.id).up().query('component[name="vztahtitle"]')[0];
                  if (rinfo.charAt(0) == 'T') {
                    var rtitle = rinfo.substring(2);
                    prevbox.update(rtitle);
                  }
                  if (rinfo.charAt(0) == 'V') {
                    var videoloc = rinfo.substring(2);
                    prevbox.update('<div class="videofancybox" data-ratio="0.8" class="usage" style="width:120px; cursor: zoom-in;"><video width="80px" poster="https://www.dictio.info/thumb/video'+target+'/'+videoloc+'" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video'+target+'/'+videoloc+'"></source></video></div>')
                    prevbox.setHeight(60);
                  }
                  document.getElementById(prevbox.id+"-innerCt").classList.add('text-'+target)
                  document.getElementById(prevbox.id+"-innerCt").classList.remove('redtext')
                }
              });
              //ajax load linked relations
              Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function(item) {item.hide()});
              Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function(item) {item.show()});
              var set_rel = Ext.getCmp('tabForm').query('[name=usersetrel]')[0].getValue();
              load_link_relations(target, combo, name, parentid, set_rel);
            }
          },
          'expand': function(field, e) {
            if (Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_')) {
              var reltar = Ext.getCmp(name).query('component[name="type"]')[0].getValue().split('_')[1];
              reload_rel(field.getValue(), field, reltar);
            } else {
              reload_rel(field.getValue(), field, dictcode);
            }
          },
          specialkey: function(field, e) {
            if (e.getKey() == e.ENTER) {
              if (Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_')) {
                var reltar = Ext.getCmp(name).query('component[name="type"]')[0].getValue().split('_')[1];
                reload_rel(field.getValue(), field, reltar);
              } else {
                reload_rel(field.getValue(), field, dictcode);
              }
            }
          }
        },
        /*listConfig: {
        getInnerTpl: function() {
          return '<div><b>{title}: {number}:</b> <i>{def}</i></div>';
        }
      }*/
        tpl: new Ext.XTemplate(
          '<tpl for="."><div class="x-boundlist-item"><b>{title}: {number}:</b> <i>{def}</i><tpl if="front!=&quot;&quot;"><div cursor: hand;"><video width="80px" poster="https://www.dictio.info/thumb/video{target}/{front}" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video{target}/{front}"></video>{front}</div></tpl> <tpl if="loc!=&quot;&quot;"><div cursor: hand;"><video width="120px" poster="https://www.dictio.info/thumb/video{target}/{loc}" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video{target}/{loc}"></source></video>{loc}</div></tpl></div></tpl>'
        ),
      },create_stav(),
        {
          xtype: 'button',
          icon: '/editor/delete.png',
          handler: function() {
            Ext.getCmp(name).destroy();
          }
        }
      ]
    },{
      xtype: 'container',
      name: 'row2',
      layout: {
        type: 'hbox',
        pack: 'end',
        align: 'right',
      },
      items: [
        {
          xtype: 'textfield',
          name: 'notransuser',
          hidden: true
        },{
          xtype: 'checkbox',
          boxLabel: locale[lang].notrans,
          name: 'notrans',
          listeners: {
            change: function() {
              var ntuser = this.ownerCt.query('[name=notransuser]')[0];
              if (this.checked) {
                if (ntuser.value == '' || ntuser.value == undefined) {
                  ntuser.value = entrydata.user_info.login+' '+Ext.Date.format(new Date(), 'Y-m-d H:i:s');
                }
              } else {
                ntuser.value = '';
              }
            }
          }
        }]
    }]
  });

  return transset;
}

function create_priklad_links(parentid) {
  var name = 'exrellink'+Ext.id();

  var transset = Ext.create('Ext.container.Container', {
    border: false,
    id: name,
    cls: 'rellinkset',
    name: 'exrellinkset',
    layout: {
      type: 'hbox'
    },
    items: [{
      xtype: 'combobox',
      name: 'type',
      queryMode: 'local',
      displayField: 'text',
      valueField: 'value',
      store: extypeStore,
      forceSelection: true,
      autoSelect: true,
      editable: false,
      allowBlank: true
    /*},{
      xtype: 'textfield',
      name: 'rellink',
      width: 80,*/
    },{
      xtype: 'combobox',
      name: 'rellink',
      store: relationlist,
      displayField: 'title',
      valueField: 'id',
      editable: true,
      queryMode: 'local',
      width: 220,
      listeners:{
        'blur': function(combo) {
          if ((!(Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_'))) && combo.getValue().startsWith(entryid+'-')) {
            Ext.Msg.alert('',locale[lang]['warn_same_entry']);
          }
        },
        'select': function(combo, record, index) {
          if (combo.getValue() != '') {
            console.log(combo.getValue())
            combo.setRawValue(combo.getValue())
          }
        },
        specialkey: function(field, e) {
          if (e.getKey() == e.ENTER) {
            if (Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_')) {
              var reltar = Ext.getCmp(name).query('component[name="type"]')[0].getValue().split('_')[1];
              reload_rel(field.getValue(), field, reltar);
            } else {
              reload_rel(field.getValue(), field, dictcode);
            }
          }
        }
      },
      /*listConfig: {
        getInnerTpl: function() {
          return '<div><b>{title}: {number}:</b> <i>{def}</i></div>';
        }
      }*/
      tpl: Ext.create('Ext.XTemplate','<tpl for="."><div class="x-boundlist-item"><b>{title}: {number}:</b> <i>{def}</i><tpl if="loc!=\'\'"><br/><img src="https://www.dictio.info/thumb/video{target}/{loc}" width="120" height="96"/></tpl></div></tpl>'),
    },{
      xtype: 'button',
      icon: '/editor/delete.png',
      handler: function() {
        Ext.getCmp(name).destroy();
      }
    }]
  });

  return transset;
}

function checkxmltext(text, type) {
  var xmltext = '<text>'+text.getValue()+'</text>'; 
  console.log(xmltext);
  var dp = new DOMParser();
  var xml = dp.parseFromString(xmltext, "text/xml");
  if (xml.documentElement.nodeName == "parsererror" || xml.documentElement.getElementsByTagName("parsererror").length > 0) {
    Ext.Msg.alert('Chyba', type+': chyba ve značkách, zkontrolujte prosím');
  } else {
    return true;
  }

}

function create_priklad(parentid, entryid, add_copy, meaning_id) {
  if (ar_priklady[meaning_id] == undefined) {
    ar_priklady[meaning_id] = 0;
  }
  var usage_id = meaning_id +'_us' + ar_priklady[meaning_id];
  var name = 'prikladuziti_'+Ext.id();
  var priklad = Ext.create('Ext.form.FieldSet', {
    fieldDefaults: {
      labelAlign: 'right'
    },
    frame: true,
    id: name,
    name: 'usageset',
    layout: {
      type: 'hbox'
    },
    items: [{
      xtype: 'container',
      layout: {
        type: 'vbox'
      },
      items: [{
        xtype: 'container',
        layout: {
          type: 'hbox'
        },
        items: [{
          xtype: 'textfield',
          disabled: true,
          name: 'usage_id',
          labelWidth: 20, 
          fieldLabel: 'ID',
          value: usage_id
        },{
          xtype: 'button',
          text: locale[lang].corpus,
          handler: function() {
            var lemma = Ext.getCmp('tabForm').query('[name=lemma]')[0].getValue();
            var button = this;
            Ext.Ajax.request({
              url: '/korpus',
              method: 'get',
              params: {
                lemma: encodeURI(lemma)
              },
              success: function(response) {
                var data = JSON.parse(response.responseText);
                var lemma = Ext.getCmp('tabForm').query('[name=lemma]')[0].getValue();
                var url = 'https://app.sketchengine.eu/#concordance?corpname=preloaded%2Fcstenten17_mj2&tab=basic&keyword='+encodeURI(lemma)+'&viewmode=sen&gdex_enabled=1&gdexcnt=50&structs=s%2Cg&refs=%3Ddoc.url&showresults=1&gdexconf=__default__';
                var korwin = Ext.create('Ext.window.Window', {
                  title: 'Korpus',
                  autoScroll: true,
                  width: 600,
                  height: 400,
                  items: [{
                    xtype: 'button',
                    text: locale[lang].corpusdetail,
                    handler: function() {
                      koncwindow = window.open(url);
                      korwin.close();
                    }
                  }]
                }).show();
                for (var i = 0; i < data.Lines.length; i++) {
                  var line = data.Lines[i];
                  var str = '';
                  var str_form = '';
                  for (var j = 0; j < line.Left.length; j++) {
                    str += line.Left[j].str;
                    str_form += line.Left[j].str;
                  }
                  for (var j = 0; j < line.Kwic.length; j++) {
                    str_form += '<b>'+line.Kwic[0].str+'</b>';
                    str += line.Kwic[0].str;
                  }
                  for (var j = 0; j < line.Right.length; j++) {
                    str += line.Right[j].str;
                    str_form += line.Right[j].str;
                  }
                  var docref = '';
                  if (line.Tbl_refs[0] != undefined) {
                    docref = line.Tbl_refs[0];
                  }

                  var newcom = Ext.create('Ext.Component', {
                    width: 500,
                    height: 50,
                    border: 1,
                    style: {
                      borderColor: 'blue',
                      borderStyle: 'solid'
                    },
                    html: str_form,
                    name: 'commenthtml'
                  });
                  var nrow = Ext.create('Ext.container.Container',{
                    layout: {
                      type: 'hbox'
                    },
                    items: [newcom,{
                      xtype:'button',
                      text: locale[lang].corpususe,
                      datavalue: i,
                      datastr: str,
                      datasrc: docref,
                      handler: function() {
                        Ext.getCmp(name).query('[name='+name+'_text]')[0].setValue(this.datastr);
                        Ext.getCmp(name).query('[name=copy_admin]')[0].setValue(url);
                        Ext.getCmp(name).query('[name=copy_zdroj]')[0].setValue(this.datasrc);
                        korwin.close();
                      }
                    }]
                  });
                  korwin.add(nrow)
                }
              }
            });
          }
        },{
          xtype: 'button',
          text: locale[lang].corpusweb,
          handler: function() {
            var lemma = Ext.getCmp('tabForm').query('[name=lemma]')[0].getValue();
            var url = 'https://app.sketchengine.eu/#concordance?corpname=preloaded%2Fcstenten17_mj2&tab=basic&keyword='+encodeURI(lemma)+'&viewmode=sen&gdex_enabled=1&gdexcnt=50&structs=s%2Cg&refs=%3Ddoc.url&showresults=1&gdexconf=__default__';
            koncwindow = window.open(url);
          }
        },{
              xtype: 'container',              
              name: 'prazdny',
              width: 115,
              fieldLabel: '',              
              },
                create_comment_button(name, usage_id), create_stav(),{
      xtype: 'button',
      icon: '/editor/delete.png',
      handler: function() {
        Ext.getCmp(name).destroy();
      }
    }]
      },{
        xtype: 'container',
        layout: {
          type: 'hbox'
        },
        items: [{
          xtype: 'textarea',
          id: name+'_text',
          name: name+'_text',
          width: 500,
          listeners: {
            'blur': function(text, ev, eopts) {
              checkxmltext(text, 'příklad užití');
            }
          }
        },{
          xtype: 'container',
          layout: {
            type: 'vbox'
          },
          items: [{
            xtype: 'combobox',
            name: 'rellink',
            store: relationlist,
            displayField: 'title',
            valueField: 'id',
            editable: true,
            emptyText: locale[lang].searchrel,
            queryMode: 'local',
            width: 160,
            listeners:{
              'select': function(combo, record, index) {
                if (combo.getValue() != '') {
                  console.log(combo.getValue())
                  var textbox = Ext.getCmp(name+'_text');
                  textbox.setValue(textbox.getValue() + '[' + combo.getValue() + ']')
                }
              },
              specialkey: function(field, e) {
                if (e.getKey() == e.ENTER) {
                  reload_rel(field.getValue(), field, dictcode);
                }
              }
            },
            listConfig: {
              getInnerTpl: function() {
                return '<div><b>{title}: {number}:</b> <i>{def}</i></div>';
              }
            }
          },create_text_buttons(name+'_text')]
        }]
      },{
        xtype: 'container',
        layout: {
          type: 'hbox'
        },
        items: [{
          xtype: 'radiofield',
          name: name+'usage_type',
          boxLabel: locale[lang].usage_veta,
          inputValue: 'sentence',
        },{
          xtype: 'radiofield',
          name: name+'usage_type',
          boxLabel: locale[lang].usage_spojeni,
          inputValue: 'colloc',
          handler: function(ctl, val) {
            if (val) {
              ctl.up().query('[name=exrelbox]')[0].show();
              //var transset = create_priklad_links(name+'_rellinks');
              //Ext.getCmp(name+'_rellinks').insert(Ext.getCmp(name+'_rellinks').items.length-1,transset);
            }
          }              
        },{
          xtype: 'fieldcontainer',
          hidden: true,
          id: name+'_rellinks',
          name: 'exrelbox',
          items:[{
            xtype: 'button',
            icon: '/editor/add.png',
            handler: function() {
              var transset = create_priklad_links(name+'_rellinks');
              Ext.getCmp(name+'_rellinks').insert(Ext.getCmp(name+'_rellinks').items.length-1,transset);
              track_change();
            }
          }]
        },/*{
          fieldLabel: locale[lang].usage_link,
          hidden: true,
          xtype: 'combobox',
          name: 'colloc_link',
          store: relationlist,
          displayField: 'title',
          valueField: 'id',
          editable: true,
          queryMode: 'local',
          width: 220,
          listeners:{
            'select': function(combo, record, index) {
              if (combo.getValue() != '') {
                console.log(combo.getValue())
                combo.setRawValue(combo.getValue())
              }
            },
            specialkey: function(field, e) {
              if (e.getKey() == e.ENTER) {
                reload_rel(field.getValue(), field, 'czj');
              }
            }
          },
          tpl: new Ext.XTemplate(
            '<tpl for="."><div class="x-boundlist-item"><b>{title}: {number}:</b> <i>{def}</i> <tpl if="loc!=&quot;&quot;">{loc} <img width="80" src="/media/video{target}/thumb/{loc}/thumb.jpg"></tpl></div></tpl>'
          ),
        }*/
        ]
      }, create_copyrightM(name+'copyright', false)]
    }]
  });
  if (add_copy) {
    ar_priklady[meaning_id]++;
   /* priklad.query('[name=copy_copy]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue()); */
    priklad.query('[name=copy_zdroj]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
    priklad.query('[name=copy_autor]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
  }

  return priklad;
}


function create_colloc(entryid) {
  counter_colloc += 1;
  var name = 'colloc_'+Ext.id();
  var sw = Ext.create('Ext.container.Container', {
    layout: {
      type: 'hbox'
    },
    id: name,
    name: 'colitem',
    items: [{
      xtype: 'displayfield',
      value: counter_colloc+': '
    },{
      xtype: 'combobox',
      name: 'colid',
      store: linklist,
      displayField: 'title',
      valueField: 'id',
      editable: true,
      queryMode: 'local',
      width: 160,
      listeners:{
        'select': function(combo, record, index) {
          console.log('select')
          if (combo.getValue() != '') {
            console.log(combo.getValue())
            combo.setRawValue(combo.getValue())
          }
        },
        specialkey: function(field, e) {
          console.log('key')
          console.log(e)
          if (e.getKey() == e.ENTER) {
            reload_link_cs(field.getValue(), field);
          }
        }
      },
      listConfig: {
        getInnerTpl: function() {
          return '<div><b>{id}:</b> <i>{title}</i></div>';
        }
      }

    },{
        xtype: 'button',
        icon: '/editor/delete.png',
        handler: function() {
          Ext.getCmp(name).destroy();
        }
      }]

  });
  return sw;
}

function insert_tag(element, tagname) {
  var domel = element.inputEl.dom;
  if (domel.selectionEnd > 0) {
    var str = element.getValue();
    var newstr = str.substring(0, domel.selectionStart) + '<' + tagname + '>' + str.substring(domel.selectionStart, domel.selectionEnd) + '</' + tagname + '>' + str.substring(domel.selectionEnd);
    element.setValue(newstr);
  }
}

function create_text_buttons(name) {
  var box = Ext.create('Ext.container.Container', {
    layout: {
      type: 'hbox'
    },
    items: [{
      xtype: 'button',
      icon: '/editor/icon_italic.png',
      scale: 'small',
      handler: function() {
        var domel = Ext.getCmp(name).inputEl.dom;
        insert_tag(Ext.getCmp(name), 'i');
      }          
    },{
      xtype: 'button',
      icon: '/editor/icon_bold.png',
      scale: 'small',
      handler: function() {
        var domel = Ext.getCmp(name).inputEl.dom;
        insert_tag(Ext.getCmp(name), 'b');
      }          
    },{
      xtype: 'button',
      icon: '/editor/icon_sub.png',
      scale: 'small',
      handler: function() {
        var domel = Ext.getCmp(name).inputEl.dom;
        insert_tag(Ext.getCmp(name), 'sub');
      }          
    },{
      xtype: 'button',
      icon: '/editor/icon_super.png',
      scale: 'small',
      handler: function() {
        var domel = Ext.getCmp(name).inputEl.dom;
        insert_tag(Ext.getCmp(name), 'sup');
      }          
    }]
  });
  return box;
}

function create_vyznam(entryid, add_copy, meaning_id) {
  var meanskupina = '';
  if (meaning_id == undefined) {
    max_meaning += 1;
    var meaning_id = entryid+'-'+max_meaning;
    ar_priklady[meaning_id] = 0;
    if (add_copy) {
      var pracskupina = Ext.getCmp('tabForm').query('[name=pracskupina]')[0].getValue();
      var userskupina = Ext.getCmp('tabForm').query('[name=userskupina]')[0].getValue();
      if (userskupina.indexOf(pracskupina) == -1) {
        meanskupina = userskupina.split(',')[0];
      }
    }
  } else {
    var mid = parseInt(meaning_id.split('-').pop());
    if (mid > max_meaning) {
      max_meaning = mid;
    }
  }

  var name = 'vyznam_'+Ext.id();
  var sense = Ext.create('Ext.form.FieldSet', {
    layout: {
      type: 'hbox'
    },
    id: name,
    name: 'vyznam',
    style: {borderColor:'#1c2641', borderBottomStyle:'dashed', borderBottomWidth:'2px'},
    frame: true,
    items: [{
      xtype: 'container',
      layout: {
        type: 'hbox'
      },
      items: [{
        xtype: 'container',
        layout: {
          type: 'vbox'
        },
        flex: 1,
        name: 'vyznam_topcont',
        items: [{
          xtype: 'container',
          layout: {
            type: 'hbox'
          },
          items: [{
            xtype: 'textfield',
            disabled: true,
            name: 'meaning_id',
            labelWidth: 50,
            fieldLabel: 'ID',
            value: meaning_id
          },{            
            xtype: 'textfield',
            name: 'meaning_nr',
            allowBlank: false,
            fieldLabel: locale[lang].order
          },{
              xtype: 'container',              
              name: 'prazdny',
              width: 50,
              fieldLabel: '',              
          },{
        xtype: 'container',
        name: 'vyznammeta',
        layout: {
          type: 'vbox'
        },
        items: [
          create_stav(),
          create_comment_button(name, 'vyznam'+meaning_id)
        ]
      },{
            xtype: 'button',
            icon: '/editor/delete.png',
            handler: function() {
              Ext.getCmp(name).destroy();
            }
            }]
        },{
          xtype: 'container',
          layout: {
            type: 'hbox'
          },
          items: [{
            xtype: 'combobox',
            fieldLabel: locale[lang].obor2,
            name: 'vyzn_oblast',
            queryMode: 'local',
            displayField: 'text',
            valueField: 'value',
            store: oblastStore,
            forceSelection: true,
            autoSelect: true,
            editable: false,
            allowBlank: true,
            multiSelect: true,
          },{
            fieldLabel: locale[lang].workgroup,
            name: 'pracskupina',
            xtype: 'combobox',
            editable: false,
            queryMode: 'local',
            displayField: 'text',
            valueField: 'value',
            store: pracskupinaStore,
            allowBlank: true,
            value: meanskupina
          }]
          },{
          xtype: 'container',
          layout: {
            type: 'hbox'
          },
          items: [{
            xtype: 'textarea',
            fieldLabel: locale[lang].definice,
            id: name+'_text',
            name: name+'_text',
            width: 500,
            listeners: {
              'blur': function(text, ev, eopts) {
                checkxmltext(text, 'definice');
              }
            }
          },{
            xtype: 'container',
            layout: {
              type: 'vbox'
            },
            items: [{
              xtype: 'combobox',
              name: 'rellink',
              store: relationlist,
              displayField: 'title',
              valueField: 'id',
              editable: true,
              emptyText: locale[lang].searchrel,
              queryMode: 'local',
              width: 100,
              listeners:{
                'select': function(combo, record, index) {
                  if (combo.getValue() != '') {
                    console.log(combo.getValue())
                    var textbox = Ext.getCmp(name+'_text');
                    textbox.setValue(textbox.getValue() + '[' + combo.getValue() + ']')
                  }
                },
                specialkey: function(field, e) {
                  if (e.getKey() == e.ENTER) {
                    reload_rel(field.getValue(), field, dictcode);
                  }
                }
              },
              listConfig: {
                getInnerTpl: function() {
                  return '<div><b>{title}: {number}:</b> <i>{def}</i></div>';
                }
              }
            },create_text_buttons(name+'_text')]
          }]
        },{
          xtype: 'fieldcontainer',
          fieldLabel: locale[lang].relations,
          id: name+'_rellinks',
          name: 'relbox',
          items:[{
            xtype: 'button',
            icon: '/editor/add.png',
            text: locale[lang].new_translation,
            name: 'relsadd',
            handler: function() {
              var transset = create_vyznam_links(name+'_rellinks');
              Ext.getCmp(name+'_rellinks').insert(Ext.getCmp(name+'_rellinks').items.length-3,transset);
              track_change();
            }
          },{
            xtype: 'button',
            icon: '/editor/refresh.png',
            name: 'relsrefresh',
            handler: function() {
              var set_rel = Ext.getCmp('tabForm').query('[name=usersetrel]')[0].getValue()
              refresh_relations(name+'_rellinks', set_rel);
            }
          },{
            name: 'relswait',
            width: 20,
            height: 20,
            xtype: 'image',
            hidden: true,
            src: '/editor/wait.gif',
          },{
          xtype: 'checkbox',
          boxLabel: locale[lang].translationunknown,
          name: 'translation_unknown'
        }]
        },create_copyrightM(name, false)]
      },{
        xtype: 'tbfill',
        flex: 1
      }]
    },{
      xtype: 'fieldcontainer',
      id: name+'_uziti',
      cls: 'priklady',
      name: 'usagebox',
      fieldLabel: locale[lang].usages,
      labelWidth: 50,
      layout: {
        type: 'vbox'
      },
      items: [{
          xtype: 'button',
          icon: '/editor/add.png',
          handler: function() {
            var priklad = create_priklad(name+'_uziti', entryid, true, meaning_id);
            Ext.getCmp(name+'_uziti').insert(Ext.getCmp(name+'_uziti').items.length-1,priklad);
            track_change();
          }
      }]
    }]
  });
  if (add_copy) {
    //Ext.getCmp(name+'_copybox').query('[name=copy_copy]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
    Ext.getCmp(name+'_copybox').query('[name=copy_zdroj]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
    Ext.getCmp(name+'_copybox').query('[name=copy_autor]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
    sense.query('[name=meaning_nr]')[0].setValue(max_meaning);
  }

  return sense;
}

Ext.onReady(function(){
    //var entryid = 1;
    var sense1 = create_vyznam(entryid);

    var datatab = Ext.create('Ext.form.Panel', {
      title: 'lemma',
      layout: 'anchor',
      fieldDefaults: {
        labelAlign: 'right'
      },
      items: [{
        xtype: 'fieldset',
        title: locale[lang].basicinfo,
        id: 'boxlemma',
        style: {backgroundColor: bgSilver},
        collapsible: true,
        layout:  {
          type: 'vbox'
        },
        items: [{
          xtype: 'container',
          layout: {
            type: 'hbox'
          },
          items: [{
            name: 'media_folder_id',
            hidden: true,
            xtype: 'textfield'
          },{
            fieldLabel: locale[lang].zverejnovani2,
            width: 350,
            name: 'completeness',
            xtype: 'combobox',
            queryMode: 'local',
            displayField: 'text',
            valueField: 'value',
            store: uplnostStore,
            forceSelection: true,
            autoSelect: true,
            editable: false,
            listeners: {
              'change': function(com, val, oldval) {
                var user_perm = Ext.getCmp('tabForm').query('[name=userperm]')[0].getValue();
                if (user_perm.indexOf('admin') == -1 && (val == '2' || val == '100') && oldval != undefined) {
                  com.setValue(oldval);
                }
                update_stav();
              }
            }
          },{
            fieldLabel: locale[lang].workgroup,
            name: 'pracskupina',
            labelWidth: 150,
            xtype: 'combobox',
            editable: false,
            queryMode: 'local',
            displayField: 'text',
            valueField: 'value',
            store: pracskupinaStore,
            forceSelection: true,
            autoSelect: true,
            allowBlank: true
          },{
            name: 'autostav',
            fieldLabel: locale[lang].status,
            xtype: 'displayfield'
          },{
            xtype: 'button',
            text: locale[lang].checkstatus,
            handler: function() {
              update_stav();
            }
          },{
            xtype: 'tbfill'
          },create_comment_button('boxlemma')]
        },{
          xtype: 'container',
          layout: {
            type: 'hbox'
          },
          items: [{
            xtype: 'textfield',
            fieldLabel: locale[lang].admincomment2,
            width: 350,
            name: 'admin_comment'
          },{
            xtype: 'displayfield',
            name: 'usersetrel',
            labelWidth: 0,
            width: 1,
            hidden: true
          },{
            xtype: 'displayfield',
            name: 'userskupina',
            fieldLabel: locale[lang].usergroup,
            labelWidth: 150,
          },{
            xtype: 'displayfield',
            name: 'userperm',
            fieldLabel: locale[lang].userperm
          },{
            xtype: 'displayfield',
            name: 'defaultautor',
            labelWidth: 200,
            fieldLabel: locale[lang].defaultauthor
          },/*{
            xtype: 'displayfield',
            name: 'defaultcopy',
            fieldLabel: 'copyright',
            
          },*/{
            xtype: 'displayfield',
            name: 'defaultzdroj',
            fieldLabel: locale[lang].source
          }]
        }]
      },{
        xtype: 'fieldset',
        style: {/*backgroundColor:'#D7E1E4;'*/},
        title: locale[lang].formaldesc,
        id: 'formaldesc',
        cls: 'formaltop',
        items: [{
          xtype: 'fieldset',
          title: locale[lang].entrytype,
          id: 'boxcolloc',
          collapsible: true,
          items: [{
            xtype: 'fieldcontainer',
            layout: {
              type: 'hbox'
            },
            items: [{
              xtype: 'radiofield',
              name: 'lemma_type',
              boxLabel: locale[lang].lemma_single,
              inputValue: 'single',
              handler: function(ctl, val) {
              if (val) {
                        Ext.each(Ext.getCmp('tabForm').query('[name=slovni_druh]'), function(item) {item.setDisabled(false)});
                        Ext.getCmp('gramcont').setDisabled(false);  
                       }
                                          }              
            },{
              xtype: 'radiofield',
              name: 'lemma_type',
              boxLabel: locale[lang].lemma_predpona,
              inputValue: 'predpona',
              handler: function(ctl, val) {
              if (val) {
                var res = Ext.getCmp('tabForm').query('[name="slovni_druh]');
                if (res[0] != undefined) {
                  res[0].setValue('predpona');
                } Ext.getCmp('gramcont').setDisabled(true);  
              }}
            },{
              xtype: 'radiofield',
              name: 'lemma_type',
              boxLabel: locale[lang].lemma_ustalene,
              inputValue: 'collocation',
              handler: function(ctl, val) {
              if (val) {
                Ext.getCmp('gramcont').setDisabled(false);  
                Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].show();                
                Ext.each(Ext.getCmp('tabForm').query('[name=slovni_druh]'), function(item) {
                  item.setValue('ustalene'); item.setDisabled(true);
                  item.up().query('component[name=skupina]')[0].bindStore(pos_ustalene_typStore);
                  item.up().query('component[name=skupina2]')[0].bindStore(emptyStore);
                });
              }}
            },{
              xtype: 'splitter',
              width: 200
            },{xtype:'tbfill'},create_comment_button('boxcolloc'),create_stav()
            ]
          },{
            xtype: 'container',
            name: 'collocationinfo',
            hidden: true,
            layout:  {
              type: 'hbox'
            },
            items: [{
              xtype: 'fieldset',
              id: 'colbox',
              title: locale[lang].lemma_composed,
              items: [{
                xtype: 'button',
                icon: '/editor/add.png',
                handler: function() {
                  var sw = create_colloc(entryid);
                  Ext.getCmp('colbox').insert(Ext.getCmp('colbox').items.length-1, sw);
                  track_change();
                }
              }]
            }]
          }]
        },{
            xtype: 'container',
            layout: {
              type: 'hbox'
            },
            items:[{
              xtype: 'textfield',              
              fieldLabel: locale[lang].lemma, 
              width: 350,               
              name: 'lemma'
            },{
              xtype: 'textfield',              
              fieldLabel: locale[lang].pravopis_variant,
              labelWidth: 150,               
              name: 'lemma_var'
            },
            {
              xtype: 'textfield',
              fieldLabel: locale[lang].vyslovnost,
              name: 'pron'
            }]
          },{
            xtype: 'container',
            layout: {
              type: 'vbox'
            },
            items:[{
              xtype: 'box',
              name: 'ssc_html',
              cls: 'ssc_html',              
              //maxWidth: '1606',
              //maxHeight: (Ext.getBody().getViewSize().height)
              maxWidth: (Ext.getBody().getViewSize().width-400)
            },{
              xtype: 'box',
              name: 'gram_html',
            }]
          },{
          xtype: 'fieldset',
          title: locale[lang].gramdesc,
          collapsible: true,
          id: 'gramdesc',
          layout: {
            type: 'vbox'
          },
          items: [{
            xtype: 'container',
            layout: {
              type: 'hbox'
            },
            items: [{
              name: 'gramcont',              
              id: 'gramcont',
              items: [create_gram(entryid),{
                xtype: 'button',
                icon: '/editor/add.png',
                handler: function() {
                  var transset = create_gram(entryid);
                  Ext.getCmp('gramcont').insert(Ext.getCmp('gramcont').items.length-1,transset);
                  track_change();
                }
              }]
            },{
              xtype: 'container',              
              name: 'prazdny',
              width: 400,
              fieldLabel: '',              
              }, create_comment_button('gramdesc'), create_stav()]
          },{
            xtype: 'container',
            layout: {
              type: 'hbox'
            },
            items: [{
              xtype: 'container',
              layout: {
                type: 'vbox'
              },
              items:[{
              xtype: 'combobox',
              fieldLabel: locale[lang].puvod,
              name: 'puvod_slova',
              queryMode: 'local',
              displayField: 'text',
              valueField: 'value',
              store: puvodStore,
              forceSelection: false,
              autoSelect: true,
              editable: true,
            },{
              xtype: 'fieldcontainer',
              fieldLabel: locale[lang].varianty,
              id: 'gvarbox',
              layout:  {
                type: 'vbox'
              },
              items: [{
                xtype: 'button',
                icon: '/editor/add.png',
                handler: function() {
                  var sw = create_variant(entryid);
                  Ext.getCmp('gvarbox').insert(Ext.getCmp('gvarbox').items.length-1,sw);
                  track_change();
                }
              }]
            },{
                xtype: 'container',
                layout: {
                  type: 'hbox'
                },
                items: [ {
                xtype: 'textarea',
                fieldLabel: 'text',
                id: 'gramatikatext_text',
                name: 'gramatikatext_text',
                width: 500,
                listeners: {
                  'blur': function(text, ev, eopts) {
                    checkxmltext(text, 'gramatický popis');
                  }
                }
              },{
                xtype: 'container',
                layout: {
                  type: 'vbox'
                },
                items: [{
                  xtype: 'combobox',
                  name: 'rellink',
                  store: relationlist,
                  displayField: 'title',
                  emptyText: locale[lang].searchrel,
                  valueField: 'id',
                  editable: true,
                  queryMode: 'local',
                  width: 160,
                  listeners:{
                    'select': function(combo, record, index) {
                      if (combo.getValue() != '') {
                        console.log(combo.getValue())
                        var textbox = Ext.getCmp('gramatikatext_text');
                        textbox.setValue(textbox.getValue() + '[' + combo.getValue() + ']')
                      }
                    },
                    specialkey: function(field, e) {
                      if (e.getKey() == e.ENTER) {
                        reload_rel(field.getValue(), field, dictcode);
                      }
                    }
                  },
                  listConfig: {
                    getInnerTpl: function() {
                      return '<div><b>{title}: {number}:</b> <i>{def}</i></div>';
                    }
                  }
                },create_text_buttons('gramatikatext_text')]
              }]},{
              fieldLabel: locale[lang].flexe,
              xtype: 'checkbox',
              boxLabel: locale[lang].nesklonne,
              name: 'flexe_neskl'
            }]
          },{
            xtype: 'container',
            layout: {
              type: 'vbox'
            },
            items: [{
              fieldLabel: locale[lang].deklinace,
              id: 'deklcont',
              xtype: 'fieldcontainer',
              layout: {
              type: 'vbox'
              },
              items: [{
                xtype: 'container',
                layout: {
                  type: 'hbox'
                },
                items: [{
                  xtype: 'button',
                  icon: '/editor/add.png',
                  text: locale[lang].row,
                  handler: function() {
                    var sw = create_deklin(entryid);
                    Ext.getCmp('deklcont').insert(Ext.getCmp('deklcont').items.length-2,sw);
                    track_change();
                  }
                },{
              xtype: 'container',              
              name: 'prazdny',
              width: 50,
              fieldLabel: '',              
              },{
                  xtype: 'button',
                text: locale[lang].taketable,
                  handler: function() {
                    var get_id = Ext.getCmp('deklcont').query('[name=get_deklin]')[0].getValue();
                    Ext.Ajax.request({
                      url: '/'+dictcode+'/getgram/'+get_id,
                      method: 'get',
                      success: function(response) {
                        var data = JSON.parse(response.responseText);
                        Ext.suspendLayouts();
                        var dekls = Ext.getCmp('deklcont').query('[name=deklinitem]');
                        for (var i = 0; i < dekls.length; i++) {
                          dekls[i].destroy();
                        }
                        for (var i = 0; i < data.form.length; i++) {
                          var sw = create_deklin(entryid);
                          sw.query('[name=dekl_tag]')[0].setValue(data.form[i]['@tag']);
                          sw.query('[name=dekl_tvar]')[0].setValue(data.form[i]['_text']);
                          Ext.getCmp('deklcont').insert(Ext.getCmp('deklcont').items.length-2,sw);
                        }
                        Ext.resumeLayouts(true);
                      }
                    });
                  }
                },{
                  xtype: 'textfield',
                  name: 'get_deklin',
                  width: 80,
                }]
              },{
                xtype: 'container',
                layout: {
                  type: 'hbox'
                },
                items: []
              },]
            }]
          },{
            fieldLabel: locale[lang].novatabulka,
            xtype: 'fieldcontainer',            
            layout: {              
              type: 'vbox'
            },
            items:[{
              xtype: 'button',
              icon: '/editor/add.png',
              text: locale[lang].pos_noun,
              handler: function() {
                update_deklin('podst');
              }
            },{
              xtype: 'button',
              icon: '/editor/add.png',
              text: locale[lang].pos_adv,
              handler: function() {
                update_deklin('prid');
              }
            },{
              xtype: 'button',
              icon: '/editor/add.png',
              text: locale[lang].pos_num,
              handler: function() {
                update_deklin('cisl');
              }
            },/*{
              xtype: 'button',
              icon: '/editor/add.png',
              text: locale[lang].pos_adj,
              handler: function() {
                update_deklin('pris');
              } 
            },*/{
              xtype: 'button',
              icon: '/editor/add.png',
              text: locale[lang].pos_verb,
              handler: function() {
                update_deklin('slov');
              }
            }]
          }]},        
                  create_copyright('gram_popis', false)]
      },{
        xtype: 'fieldset',
        title: locale[lang].styldesc,
        collapsible: true,
        id: 'styldesc',
        layout: {
          type: 'vbox'
        },
        items: [{
          xtype: 'container',
          layout: {
            type: 'hbox'
          },
          items: [ {
          xtype: 'container',
          layout: {
            type: 'vbox'
          },
          items: [{
            xtype: 'combobox',
            fieldLabel: locale[lang].stylhodnoceni,
            name: 'kategorie',
            queryMode: 'local',
            store: stylhodnStore,
            forceSelection: true,
            autoSelect: true,
            displayField: 'text',
            valueField: 'value',
            editable: false,
            multiSelect: true
          },{
            xtype: 'combobox',
            fieldLabel: locale[lang].stylpriznak,
            name: 'stylpriznak',
            queryMode: 'local',
            store: stylprizStore,
            forceSelection: true,
            autoSelect: true,
            displayField: 'text',
            valueField: 'value',
            editable: false,
            multiSelect: true
          },{
            xtype: 'fieldcontainer',
            fieldLabel: locale[lang].varianty,
            id: 'varbox',
            layout:  {
              type: 'vbox'
            },
            items: [{
              xtype: 'button',
              icon: '/editor/add.png',
              handler: function() {
                var sw = create_variant(entryid);
                Ext.getCmp('varbox').insert(Ext.getCmp('varbox').items.length-1,sw);
                track_change();
              }
            }]
          }]
        },
                  {
            xtype: 'container',
            layout: {
              type: 'hbox'
            },
            items:[{
              xtype: 'textarea',
              id: 'styltext_text',
              fieldLabel: 'text',
              name: 'styltext_text',
              width: 500,
              listeners: {
                'blur': function(text, ev, eopts) {
                  checkxmltext(text, 'stylistický popis');
                }
              }
            },{
              xtype: 'container',
              layout: {
                type: 'vbox'
              },
              items: [{
                xtype: 'combobox',
                name: 'rellink',
                emptyText: locale[lang].searchrel,
                store: relationlist,
                displayField: 'title',
                valueField: 'id',
                editable: true,
                queryMode: 'local',
                width: 120,
                listeners:{
                  'select': function(combo, record, index) {
                    if (combo.getValue() != '') {
                      console.log(combo.getValue())
                      var textbox = Ext.getCmp('styltext_text');
                      textbox.setValue(textbox.getValue() + '[' + combo.getValue() + ']')
                    }
                  },
                  specialkey: function(field, e) {
                    if (e.getKey() == e.ENTER) {
                      reload_rel(field.getValue(), field, dictcode);
                    }
                  }
                },
                listConfig: {
                  getInnerTpl: function() {
                    return '<div><b>{title}: {number}:</b> <i>{def}</i></div>';
                  }
                }
              },create_text_buttons('styltext_text')]
            }]
          }, {
              xtype: 'container',              
              name: 'prazdny',
              width: 250,
              fieldLabel: '',              
              }, create_comment_button('styldesc'), create_stav()]},
          create_copyright('styl_popis', false)]
      }]},{
        xtype: 'fieldset',
        title: locale[lang].meanings,
        collapsible: true,
        id: 'vyznamy_box',
        items: [sense1,{
          xtype: 'button',
          icon: '/editor/add.png',
          text: locale[lang].new_meaning,
          handler: function() {
            var vyznam = create_vyznam(entryid, true);
            Ext.getCmp('vyznamy_box').insert(Ext.getCmp('vyznamy_box').items.length-1,vyznam);
            track_change();
          }
        }]
      }]
    });

    var entryform = Ext.create('Ext.form.Panel', {
      url: '/'+dictcode,
      xtype: 'form',
      id: 'tabForm',
      title: 'Heslo id____',
      border: false,
      bodyBorder: false,
      fieldDefaults: {
        labelWidth: 100,
        msgTarget: 'side'
      },
       header:{
        titlePosition: 0,
        items: [
        {
        xtype: 'button',
        text: locale[lang].admintools,
        icon: '/editor/img/admin_list.png',
        handler: function() {           
          var odkaz = '/admin?action=report'+dictcode+'&lang='+lang;                   
          window.open(odkaz);
        }
      },
        {
        xtype: 'button',
        text: locale[lang].newlemma,
        icon: '/editor/img/newlemma.png',
        handler: function() {           
          var odkaz = '/editor'+dictcode+'/?id=&lang='+lang;                   
          window.open(odkaz);
        }
      },{
        xtype: 'button',
        text: locale[lang].admintools,
        icon: '/editor/img/timeback_m.png',
        handler: function() {           
          var odkaz = 'https://admin.dictio.info/history?code='+dictcode+'&entry='+entryid;          
          window.open(odkaz);
        }
      },{
          xtype: 'button',
          text: locale[lang].viewplus,
          icon: '/editor/img/display.png',
          handler: function() {           
            var odkaz = '/'+dictcode+'/show/'+entryid+'?lang='+lang;
            window.open(odkaz);
          }
        },{
          xtype: 'button',
        text: locale[lang].saveview,
        icon: '/editor/img/savedisplay.png',
        name: 'savebutton',
        handler: function() {
          Ext.Msg.alert('Stav', locale[lang].savemsg);
          var waitBox = Ext.MessageBox.wait(locale[lang].savemsg);
          var data = save_doc(entryid);
          if (data != false) {
            console.log('odeslat data');
            Ext.Ajax.request({
              url: '/'+dictcode+'/save',
              params: {
                data: JSON.stringify(data),
              },
              method: 'POST',
              failure: function(response) {
                console.log('fail')
                console.log(response.responseText)
              },
              success: function(response) {
                console.log(response.responseText)
                var data = JSON.parse(response.responseText);
                Ext.Msg.alert('Stav', data.msg);
                Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                window.location = '/'+dictcode+'/show/'+entryid+'?lang='+lang;
              }
            });
          }
        }
      },{
        xtype: 'label',
        text: '',
        name: 'modifiedlabel',
        cls: 'modified-box',
        style: 'width: 200px !important'
      },{
          xtype: 'tbspacer',
          flex: 6
        },{
          xtype: 'button',
          text: locale[lang].deleteentry,          
          icon: '/editor/img/delete2.png',          
          handler: function() {
            Ext.Msg.confirm('?', locale[lang].deletemsg, function(btn, text) {
              if (btn == 'yes') {
                Ext.Ajax.request({
                  url: '/'+dictcode+'/delete/'+entryid,
                  method: 'post',
                  success: function(response) {
                    console.log(response.responseText);
                    if (response.responseText.substring(0,7) == 'DELETED') {
                      Ext.Msg.alert(locale[lang].status, locale[lang].deleted);
                      Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                      window.location = '/'+dictcode;
                    } else {
                      Ext.Msg.alert('Chyba', response.responseText);
                    }
                  }
                });
              }
            });
          }
        }]
      },
      items: {
        xtype: 'tabpanel',
        activeTab: 0,
        defaults:{
          bodyPadding: 10,
          layout: 'anchor'
        },
        items: [datatab]
      },
      buttons: [{
        text: locale[lang].save,
        name: 'savebutton',
        icon: '/editor/img/save.png',        
        handler: function() {
          Ext.Msg.alert('Stav', locale[lang].savemsg);
          console.log('savedisplay horni');
          var waitBox = Ext.MessageBox.wait(locale[lang].savemsg);
          var data = save_doc(entryid);
          if (data != false) {
            console.log('odeslat data');
            Ext.Ajax.request({
              url: '/'+dictcode+'/save',
              params: {
                data: JSON.stringify(data),
              },
              method: 'POST',
              failure: function(response) {
                console.log('fail')
                console.log(response.responseText)
              },
              success: function(response) {
                console.log(response.responseText)
                var data = JSON.parse(response.responseText);
                Ext.Msg.alert('Stav', data.msg);
                Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                window.location = '/editor'+dictcode+'/?id='+entryid+'&lang='+lang;
              }
            });
          }
        }
      },{
        text: locale[lang].saveview,
        icon: '/editor/img/savedisplay.png',
        name: 'savebutton',
        handler: function() {
          Ext.Msg.alert('Stav', locale[lang].savemsg);
          console.log('savedisplay horni');
          var waitBox = Ext.MessageBox.wait(locale[lang].savemsg);
          var data = save_doc(entryid);
          if (data != false) {
            console.log('odeslat data');
            Ext.Ajax.request({
              url: '/'+dictcode+'/save',
              params: {
                data: JSON.stringify(data),
              },
              method: 'POST',
              failure: function(response) {
                console.log('fail')
                console.log(response.responseText)
              },
              success: function(response) {
                console.log(response.responseText)
                var data = JSON.parse(response.responseText);
                Ext.Msg.alert('Stav', data.msg);
                Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                window.location = '/'+dictcode+'/show/'+entryid+'?lang='+lang;
              }
            });
          }
        }
      },{
        text: locale[lang].viewplus,
        icon: '/editor/img/display.png',
        handler: function() {          
   	   var odkaz = '/'+dictcode+'/show/'+entryid+'?lang='+lang;
          window.open(odkaz);
        }
      }]
    });

    /* RENDER */
    entryform.render(document.getElementById('topdiv'),0);

    /* LOAD params */
    if (params.id != null && params.id != '') {
      /* load filelist */
      entryid = params.id;
      g_entryid = params.id;
      load_doc(params.id, params.history, params.type)
      window.onbeforeunload = function(e) {
        if (entry_updated) {
          return locale[lang].savewarning;
        }
      };
    } else {
      is_new_entry = true;
      new_entry();
    }

  }
);
