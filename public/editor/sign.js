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
var entry_updated = false;
var empty = '';
var changes = new Array();
var typingTimer;
var doneTypingInterval = 5000;
var bgAuth = 'lightsteelblue';
var bgSilver = 'silver';
const version = "2.1.3";

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
  fields: ['id', 'location', 'author', 'source', 'admin', 'copyright', 'status', 'original', 'orient', 'type'],
  data: []
});
var relationlist = Ext.create('Ext.data.Store', {
  fields: ['id', 'title', 'number', 'def', 'loc', 'target', 'front'],
  data: []
});
var linklist = Ext.create('Ext.data.Store', {
  fields: ['id', 'title', 'label', 'loc'],
  data: []
});

var posStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    { 'value': 'subst', 'text': locale[lang].lex_subst },
    { 'value': 'verb', 'text': locale[lang].lex_verb },
    { 'value': 'adj', 'text': locale[lang].lex_adj },
    { 'value': 'adv', 'text': locale[lang].lex_adv },
    { 'value': 'modif', 'text': locale[lang].lex_modif },
    { 'value': 'pron', 'text': locale[lang].lex_pron },
    { 'value': 'num', 'text': locale[lang].lex_num },
    { 'value': 'konj', 'text': locale[lang].lex_konj },
    { 'value': 'part', 'text': locale[lang].lex_part },
    { 'value': 'taz', 'text': locale[lang].lex_taz },
    { 'value': 'kat', 'text': locale[lang].lex_kat },
    { 'value': 'klf', 'text': locale[lang].lex_klf },
    { 'value': 'spc', 'text': locale[lang].lex_spc },
    { 'value': 'ustalene', 'text': locale[lang].lemma_colloc },
    { 'value': 'finger', 'text': locale[lang].lex_finger },
  ]
});
var emptyStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
  ]
});

var pos_substStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    //  {'value': 'konk', 'text':'konkrétní'},
    //  {'value': 'abs', 'text':'abstraktní'},
    { 'value': 'jmen', 'text': locale[lang].subst_vlast },
  ]
});

var pos_subst_plurStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': locale[lang].plural_text },
    { 'value': 'noplural', 'text': locale[lang].plural_noplural },
    { 'value': 'redup', 'text': locale[lang].plural_redup },
    //  {'value': 'kvan', 'text':'přidáním kvantifikátoru'},    
    //  {'value': 'plur', 'text':'přidáním plurálového specifikátoru'},
    { 'value': 'klf', 'text': locale[lang].plural_klf },
    { 'value': 'redupKLF', 'text': locale[lang].plural_redupKLF },
    //  {'value': 'ink', 'text':'inkorporací číselných morfémů'},
  ]
});

var pos_verbStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    { 'value': 'proste', 'text': locale[lang].verb_proste },
    { 'value': 'shodove', 'text': locale[lang].verb_shod },
    { 'value': 'prostor', 'text': locale[lang].verb_prostor },
    { 'value': 'klas', 'text': locale[lang].verb_klasif },
    //  {'value': 'modal', 'text':'X modální X'},
  ]
});
var pos_verb_prosteStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    { 'value': 'intr', 'text': locale[lang].verb_proste_intr },
    { 'value': 'tran', 'text': locale[lang].verb_proste_tr },
  ]
});
var pos_verb_prostorStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    { 'value': 'pohyb', 'text': locale[lang].verb_prostor_pohyb },
    { 'value': 'misto', 'text': locale[lang].verb_prostor_misto },
    { 'value': 'prost', 'text': locale[lang].verb_prostor_prost },
  ]
});
var pos_verb_shodoveStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'subj', 'text': locale[lang].verb_shod_subj },
    { 'value': 'obj', 'text': locale[lang].verb_shod_obj },
    { 'value': 'reci', 'text': locale[lang].verb_shod_reci },
    { 'value': 'polo', 'text': locale[lang].verb_shod_polo },
    { 'value': 'lok', 'text': locale[lang].verb_shod_lok },
  ]
});
var pos_verb_2Store = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': locale[lang].verb_2_ },
    { 'value': 'redo', 'text': locale[lang].verb_2_redo },
    { 'value': 'redt', 'text': locale[lang].verb_2_redt },
    { 'value': 'okol', 'text': locale[lang].verb_2_okol },
    { 'value': 'rt', 'text': locale[lang].verb_2_rt },
    { 'value': 'rp', 'text': locale[lang].verb_2_rp },
    { 'value': 'pp', 'text': locale[lang].verb_2_pp },
    { 'value': 'po', 'text': locale[lang].verb_2_po },
  ]
});

var pos_pronStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    { 'value': 'ukaz', 'text': locale[lang].pron_ukaz },
    { 'value': 'priv', 'text': locale[lang].pron_priv },
  ]
});

var pos_modStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'kval', 'text': locale[lang].mod_kval },
    { 'value': 'cas', 'text': locale[lang].mod_cas },
    { 'value': 'dej', 'text': locale[lang].mod_dej },
    { 'value': 'prostor', 'text': locale[lang].mod_prostor },
  ]
});
var pos_cas2Store = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': locale[lang].cas2_ },
    { 'value': 'kvan', 'text': locale[lang].cas2_kvan },
    { 'value': 'ink', 'text': locale[lang].cas2_ink },
  ]
});

var pos_numStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    { 'value': 'zakl', 'text': locale[lang].num_zakl },
    { 'value': 'rad', 'text': locale[lang].num_rad },
    { 'value': 'nas', 'text': locale[lang].num_nas },
    { 'value': 'ikon', 'text': locale[lang].num_ikon },
    { 'value': 'spec', 'text': locale[lang].num_spec },
    { 'value': 'neur', 'text': locale[lang].num_neur },

  ]
});
var pos_num_radStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'lok', 'text': locale[lang].num_rad_lok },
    { 'value': 'pok', 'text': locale[lang].num_rad_pok },
  ]
});
var pos_num_nasStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'dej', 'text': locale[lang].num_nas_dej },
    { 'value': 'fre', 'text': locale[lang].num_nas_fre },
    { 'value': 'mir', 'text': locale[lang].num_nas_mir },
  ]
});
var pos_num_ikoStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'obr', 'text': locale[lang].num_iko_obr },
    { 'value': 'iko', 'text': locale[lang].num_iko_iko },
    { 'value': 'spec', 'text': locale[lang].num_iko_spec },
  ]
});

var pos_partStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': '-' },
    { 'value': 'partneg', 'text': locale[lang].part_neg },
    { 'value': 'partcont', 'text': locale[lang].part_cont },
  ]
});

var pracskupinaStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'biologie', 'text': locale[lang].pracskup_biologie },
    { 'value': 'informatika', 'text': locale[lang].pracskup_informatika },
    { 'value': 'matematika', 'text': locale[lang].pracskup_matematika },
    { 'value': 'podnikani', 'text': locale[lang].pracskup_podnikani },
    { 'value': 'obecna', 'text': locale[lang].pracskup_obecna },
    { 'value': 'teires_w', 'text': locale[lang].pracskup_teires_w },
    { 'value': 'upol', 'text': locale[lang].pracskup_upol },
    { 'value': 'spec', 'text': locale[lang].pracskup_spec },
    { 'value': 'all', 'text': locale[lang].pracskup_all },
    { 'value': 'aka', 'text': locale[lang].pracskup_aka },
    { 'value': 'soc', 'text': locale[lang].pracskup_soc },
    { 'value': 'tczj', 'text': 'TCZJ MU' },
    { 'value': 'sz', 'text': 'specifické znaky' },
    { 'value': 'vut_me', 'text': 'mechanika VUT' },
    { 'value': 'krest', 'text': 'křesťanství' },
    { 'value': 'mdd', 'text': 'MobiDeafDict' },
    { 'value': 'test', 'text': 'test (MobiDeafDict)' },
    { 'value': 'ls', 'text': 'LangSkills' },
    { 'value': '', 'text': '' },
  ]
});

data = [
  { 'value': null, 'text': '-' },
  { 'value': 'spj', 'text': locale[lang].spj },
  { 'value': 'ogs', 'text': locale[lang].ogs },
  { 'value': 'pjm', 'text': locale[lang].pjm },
  { 'value': 'dgs', 'text': locale[lang].dgs },
  { 'value': 'asl', 'text': locale[lang].asl },
  { 'value': 'bsl', 'text': locale[lang].bsl },
  { 'value': 'rzj', 'text': locale[lang].rzj },
  { 'value': 'israel', 'text': locale[lang].israel },
  { 'value': 'is', 'text': locale[lang].is },
  { 'value': 'zc', 'text': locale[lang].zc },
  { 'value': 'loc', 'text': locale[lang].loc },
];
if (dictcode == 'czj') {
  data = data.filter(val => (val.value != 'czj'));
  console.log(data)
}
if (dictcode == 'spj') {
  data = data.filter(val => val.value != 'spj');
}
if (dictcode == 'asl') {
  data = data.filter(val => (val.value != 'asl'));
  console.log(data)
}
if (dictcode == 'is') {
  data = data.filter(val => (val.value != 'is'));
  console.log(data)
}
var puvodStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: data
});

var genderStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': null, 'text': '-' },
    { 'value': 'm', 'text': locale[lang].male },
    { 'value': 'f', 'text': locale[lang].female },
  ]
});

var kategorieStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': null, 'text': '-' },
    { 'value': 'neo', 'text': locale[lang].kategorie_neo },
    { 'value': 'arch', 'text': locale[lang].kategorie_arch },
  ]
});


var katStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '', 'text': 'nezařazeno' },
    { 'value': '28', 'text': locale[lang].kat_28 },
    { 'value': '6', 'text': locale[lang].kat_6 },
    { 'value': '27', 'text': locale[lang].kat_27 },
    { 'value': '14', 'text': locale[lang].kat_14 },
    { 'value': 'anat', 'text': locale[lang].kat_anat },
    { 'value': 'antr', 'text': locale[lang].kat_antr },
    { 'value': 'archeol', 'text': locale[lang].kat_archeol },
    { 'value': 'archit', 'text': locale[lang].kat_archit },
    { 'value': 'biol', 'text': locale[lang].kat_biol },
    { 'value': 'bot', 'text': locale[lang].kat_bot },
    { 'value': 'cirkev', 'text': locale[lang].kat_cirkev },
    { 'value': 'dipl', 'text': locale[lang].kat_dipl },
    { 'value': 'div', 'text': locale[lang].kat_div },
    { 'value': 'dopr', 'text': locale[lang].kat_dopr },
    { 'value': 'ekol', 'text': locale[lang].kat_ekol },
    { 'value': 'ekon', 'text': locale[lang].kat_ekon },
    { 'value': 'eltech', 'text': locale[lang].kat_eltech },
    { 'value': 'etn', 'text': locale[lang].kat_etn },
    { 'value': 'feud', 'text': locale[lang].kat_feud },
    { 'value': 'filat', 'text': locale[lang].kat_filat },
    { 'value': 'film', 'text': locale[lang].kat_film },
    { 'value': 'filoz', 'text': locale[lang].kat_filoz },
    { 'value': 'fot', 'text': locale[lang].kat_fot },
    { 'value': 'fyz', 'text': locale[lang].kat_fyz },
    { 'value': 'fyziol', 'text': locale[lang].kat_fyziol },
    { 'value': 'geol', 'text': locale[lang].kat_geol },
    { 'value': 'geom', 'text': locale[lang].kat_geom },
    { 'value': 'gnoz', 'text': locale[lang].kat_gnoz },
    { 'value': 'hist', 'text': locale[lang].kat_hist },
    { 'value': 'horn', 'text': locale[lang].kat_horn },
    { 'value': 'horol', 'text': locale[lang].kat_horol },
    { 'value': 'hosp', 'text': locale[lang].kat_hosp },
    { 'value': 'hud', 'text': locale[lang].kat_hud },
    { 'value': 'hut', 'text': locale[lang].kat_hut },
    { 'value': 'hvězd', 'text': locale[lang].kat_hvězd },
    { 'value': 'chem', 'text': locale[lang].kat_chem },
    { 'value': 'ideal', 'text': locale[lang].kat_ideal },
    { 'value': 'jad', 'text': locale[lang].kat_jad },
    { 'value': 'jaz', 'text': locale[lang].kat_jaz },
    { 'value': 'kapit', 'text': locale[lang].kat_kapit },
    { 'value': 'karet', 'text': locale[lang].kat_karet },
    { 'value': 'katol církvi', 'text': locale[lang].kat_katolcírkvi },
    { 'value': 'krim', 'text': locale[lang].kat_krim },
    { 'value': 'křesť', 'text': locale[lang].kat_křesť },
    { 'value': 'kuch', 'text': locale[lang].kat_kuch },
    { 'value': 'kult', 'text': locale[lang].kat_kult },
    { 'value': 'kyb', 'text': locale[lang].kat_kyb },
    { 'value': 'lék', 'text': locale[lang].kat_lék },
    { 'value': 'lékár', 'text': locale[lang].kat_lékár },
    { 'value': 'let', 'text': locale[lang].kat_let },
    { 'value': 'liter', 'text': locale[lang].kat_liter },
    { 'value': 'log', 'text': locale[lang].kat_log },
    { 'value': 'marx', 'text': locale[lang].kat_marx },
    { 'value': 'mat', 'text': locale[lang].kat_mat },
    { 'value': 'meteor', 'text': locale[lang].kat_meteor },
    { 'value': 'miner', 'text': locale[lang].kat_miner },
    { 'value': 'motor', 'text': locale[lang].kat_motor },
    { 'value': 'mysl', 'text': locale[lang].kat_mysl },
    { 'value': 'mytol', 'text': locale[lang].kat_mytol },
    { 'value': 'náb', 'text': locale[lang].kat_náb },
    { 'value': 'nár', 'text': locale[lang].kat_nár },
    { 'value': 'obch', 'text': locale[lang].kat_obch },
    { 'value': 'pedag', 'text': locale[lang].kat_pedag },
    { 'value': 'peněž', 'text': locale[lang].kat_peněž },
    { 'value': 'polit', 'text': locale[lang].kat_polit },
    { 'value': 'polygr', 'text': locale[lang].kat_polygr },
    { 'value': 'pošt', 'text': locale[lang].kat_pošt },
    { 'value': 'potrav', 'text': locale[lang].kat_potrav },
    { 'value': 'práv', 'text': locale[lang].kat_práv },
    { 'value': 'prům', 'text': locale[lang].kat_prům },
    { 'value': 'přír', 'text': locale[lang].kat_přír },
    { 'value': 'psych', 'text': locale[lang].kat_psych },
    { 'value': 'rybn', 'text': locale[lang].kat_rybn },
    { 'value': 'řem', 'text': locale[lang].kat_řem },
    { 'value': 'sklář', 'text': locale[lang].kat_sklář },
    { 'value': 'soc', 'text': locale[lang].kat_soc },
    { 'value': 'sociol', 'text': locale[lang].kat_sociol },
    { 'value': 'stat', 'text': locale[lang].kat_stat },
    { 'value': 'stav', 'text': locale[lang].kat_stav },
    { 'value': 'škol', 'text': locale[lang].kat_škol },
    { 'value': 'tech', 'text': locale[lang].kat_tech },
    { 'value': 'těl', 'text': locale[lang].kat_těl },
    { 'value': 'text', 'text': locale[lang].kat_text },
    { 'value': 'úč', 'text': locale[lang].kat_úč },
    { 'value': 'úř', 'text': locale[lang].kat_úř },
    { 'value': 'veř spr', 'text': locale[lang].kat_veřspr },
    { 'value': 'vet', 'text': locale[lang].kat_vet },
    { 'value': 'voj', 'text': locale[lang].kat_voj },
    { 'value': 'výptech', 'text': locale[lang].kat_výptech },
    { 'value': 'výr', 'text': locale[lang].kat_výr },
    { 'value': 'výtv', 'text': locale[lang].kat_výtv },
    { 'value': 'zahr', 'text': locale[lang].kat_zahr },
    { 'value': 'zbož', 'text': locale[lang].kat_zbož },
    { 'value': 'zeměd', 'text': locale[lang].kat_zeměd },
    { 'value': 'zeměp', 'text': locale[lang].kat_zeměp },
    { 'value': 'zool', 'text': locale[lang].kat_zool },

  ]
});

var artikStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'neutral', 'text': locale[lang].loc_neutral },
    { 'value': 'hlava', 'text': locale[lang].loc_head },
    { 'value': 'oblicej', 'text': locale[lang].loc_face },
    { 'value': 'temeno', 'text': locale[lang].loc_top },
    { 'value': 'celo', 'text': locale[lang].loc_forehead },
    { 'value': 'oci', 'text': locale[lang].loc_eyes },
    { 'value': 'nos', 'text': locale[lang].loc_nose },
    { 'value': 'usi', 'text': locale[lang].loc_ears },
    { 'value': 'tvare', 'text': locale[lang].loc_cheeks },
    { 'value': 'usta', 'text': locale[lang].loc_mouth },
    { 'value': 'brada', 'text': locale[lang].loc_chin },
    { 'value': 'krk', 'text': locale[lang].loc_neck },
    { 'value': 'hrud', 'text': locale[lang].loc_chest },
    { 'value': 'paze', 'text': locale[lang].loc_arm },
    { 'value': 'ruka', 'text': locale[lang].loc_hand },
    { 'value': 'pas', 'text': locale[lang].loc_belly },
    { 'value': 'dolni', 'text': locale[lang].loc_legs },
  ]
});

var stylprizStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': null, 'text': '-' },
    { 'value': 'abstrakt', 'text': 'abstraktní výraz' },
    { 'value': 'cirkev', 'text': 'církevní výraz' },
    { 'value': 'biblicky', 'text': 'biblický výraz' },    
    { 'value': 'hanlivy', 'text': 'hanlivý (neslušný) výraz' },    
    { 'value': 'odborny', 'text': 'odborný výraz' },
    { 'value': 'sz', 'text': 'specifický znak' },
    { 'value': 'zc', 'text': 'výraz znakované češtiny' },
    { 'value': 'basnicky', 'text': 'básnický výraz' },
    { 'value': 'detsky', 'text': 'dětský výraz' },
    { 'value': 'eufem', 'text': 'eufemismus' },    
    { 'value': 'lichotivy', 'text': 'lichotivý výraz' },
    { 'value': 'mazlivy', 'text': 'mazlivý výraz' },
    { 'value': 'zdvor', 'text': 'zdvořilostní výraz' },
    { 'value': 'zhrubely', 'text': 'zhrubělý výraz' },
    { 'value': 'zert', 'text': 'žertovný výraz' },
    { 'value': 'zdrob', 'text': 'zdrobnělina' },
    { 'value': 'zastar', 'text': 'zastaralý výraz' },
  ]
});

var uplnostStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': '0', 'text': locale[lang].pub_auto },
    { 'value': '1', 'text': locale[lang].pub_hide },
    { 'value': '2', 'text': locale[lang].pub_nonempty },
    { 'value': '100', 'text': locale[lang].pub_approved },
  ]
});

data = [
  { 'value': 'translation_cs', 'text': locale[lang].rel_trans_cs },
  { 'value': 'translation_czj', 'text': locale[lang].rel_trans_czj },
  { 'value': 'translation_en', 'text': locale[lang].rel_trans_en },
  { 'value': 'translation_is', 'text': locale[lang].rel_trans_is },
  { 'value': 'translation_asl', 'text': locale[lang].rel_trans_asl },
  { 'value': 'translation_sj', 'text': locale[lang].rel_trans_sj },
  { 'value': 'translation_spj', 'text': locale[lang].rel_trans_spj },
  { 'value': 'translation_de', 'text': locale[lang].rel_trans_de },
  { 'value': 'translation_ogs', 'text': locale[lang].rel_trans_ogs },
  { 'value': 'translation_uk', 'text': locale[lang].rel_trans_uk },
  { 'value': 'translation_uzm', 'text': locale[lang].rel_trans_uzm },
  { 'value': 'synonym', 'text': locale[lang].rel_syn },
  /*{'value': 'synonym_strategie', 'text':locale[lang].rel_strat},*/
  { 'value': 'antonym', 'text': locale[lang].rel_ant },
  { 'value': 'hyperonym', 'text': locale[lang].rel_hype },
  { 'value': 'hyponym', 'text': locale[lang].rel_hypo },
];
data = data.filter(val => val.value != 'translation_' + dictcode);
var typeStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'], data: data
});
data = [
  { 'value': 'translation_cs', 'text': locale[lang].rel_trans_cs },
  { 'value': 'translation_czj', 'text': locale[lang].rel_trans_czj },
  { 'value': 'translation_en', 'text': locale[lang].rel_trans_en },
  { 'value': 'translation_is', 'text': locale[lang].rel_trans_is },
  { 'value': 'translation_asl', 'text': locale[lang].rel_trans_asl },
  { 'value': 'translation_sj', 'text': locale[lang].rel_trans_sj },
  { 'value': 'translation_spj', 'text': locale[lang].rel_trans_spj },
  { 'value': 'translation_de', 'text': locale[lang].rel_trans_de },
  { 'value': 'translation_ogs', 'text': locale[lang].rel_trans_ogs },
  { 'value': 'translation_uk', 'text': locale[lang].rel_trans_uk },
  { 'value': 'translation_uzm', 'text': locale[lang].rel_trans_uzm },
];
data = data.filter(val => val.value != 'translation_' + dictcode);
var extypeStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'], data: data
});

var videotypeStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'front', 'text': locale[lang].frontvideo },
    { 'value': 'side', 'text': locale[lang].sidevideo },
  ]
});

var komptypeStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'nezadano', 'text': locale[lang].undefined },
    { 'value': 'povinny', 'text': locale[lang].compulsory },
    { 'value': 'nepovinny', 'text': locale[lang].obligatory },
  ]
});

var mediatypeStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'sign_style', 'text': locale[lang].style_video },
    { 'value': 'sign_grammar', 'text': locale[lang].grammar_video },
    { 'value': 'sign_usage_example', 'text': locale[lang].usage_video },
    { 'value': 'sign_definition', 'text': locale[lang].def_video },
    { 'value': 'sign_front', 'text': locale[lang].frontvideo },
    { 'value': 'sign_side', 'text': locale[lang].sidevideo },
  ]
});


var pubStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'published', 'text': locale[lang].pub_published },
    { 'value': 'hidden', 'text': locale[lang].pub_hidden }
  ]
});

if (dictcode == 'czj') {
  data = [
    { 'value': 'cr', 'text': locale[lang].region_cr },
    { 'value': 'cechy', 'text': locale[lang].region_cechy },
    { 'value': 'morava', 'text': locale[lang].region_morava },
    { 'value': 'plzen', 'text': locale[lang].region_plzen },
    { 'value': 'praha', 'text': locale[lang].region_praha },
    { 'value': 'brno', 'text': locale[lang].region_brno },
    { 'value': 'vm', 'text': locale[lang].region_vm },
    { 'value': 'hk', 'text': locale[lang].region_hk },
    { 'value': 'jih', 'text': locale[lang].region_jih },
    { 'value': 'zl', 'text': locale[lang].region_zl },
    { 'value': 'cb', 'text': locale[lang].region_cb },
    { 'value': 'ot', 'text': locale[lang].region_ot },
    { 'value': 'ol', 'text': locale[lang].region_ol },
  ];
} else {
  data = new Array();
}

var regStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: data,
});

var genStore = Ext.create('Ext.data.Store', {
  fields: ['value', 'text'],
  data: [
    { 'value': 'mlada', 'text': locale[lang].gener_mlada },
    { 'value': 'stredni', 'text': locale[lang].gener_stredni },
    { 'value': 'starsi', 'text': locale[lang].gener_starsi },
    { 'value': 'deti', 'text': locale[lang].gener_deti },
  ]
});

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

  //videa
  var vids = Ext.getCmp('videobox').query('component[name="viditem"]');
  for (var i = 0; i < vids.length; i++) {
    if (vids[i].query('component[name="type"]')[0].getValue() == 'front') {
      if (vids[i].query('[name=stav]')[0].getValue() == 'published') {
        video_front = true;
      }
    }
    if (vids[i].query('component[name="type"]')[0].getValue() == 'side') {
      if (vids[i].query('[name=stav]')[0].getValue() == 'published') {
        video_side = true;
      }
    }
  }
  if (video_front && video_side) {
    video_vyplneno = true;
  }
  console.log('video_vyplneno=' + video_vyplneno);

  //transkripce
  if (Ext.get('hamndata-inputEl').dom.value != '' && Ext.getCmp('hamnbox').query('component[name="stavcont"]')[0].query('[name=stav]')[0].getValue() == 'published') {
    trans_vyplneno = true;
  }
  if ((Ext.getCmp('swbox').query('component[name="switem"]').length > 0 && Ext.getCmp('swfieldset').query('[name=stav]')[0].getValue() == 'published') || Ext.getCmp('tabForm').query('component[name="lemma_type"]')[0].getGroupValue() != 'single') {
    trans_vyplneno = true;
  }
  console.log('trans_vyplneno=' + trans_vyplneno);

  //vyklad
  var means = Ext.getCmp('tabForm').query('component[name="vyznam"]');
  if (means.length > 0) {
    for (var j = 0; j < means.length; j++) {
      if (means[j].query('[name=vyznammeta]')[0].query('[name=stav]')[0].getValue() == 'published') {
        //vyklad_vyplneno = true;
        var exset = means[j].query('component[name="usageset"]');
        for (var i = 0; i < exset.length; i++) {
          if (exset[i].query('component[name="stav"]')[0].getValue() == 'published') {
            vyklad_vyplneno = true;
          }
        }

      }
    }
  }
  console.log('vyklad_vyplneno=' + vyklad_vyplneno);

  //preklad
  var trset = Ext.getCmp('tabForm').query('component[name="rellinkset"]');
  for (var j = 0; j < trset.length; j++) {
    if (trset[j].query('component[name="rellink"]')[0].getValue() != "" && trset[j].query('component[name="type"]')[0].getValue() != null && trset[j].query('component[name="type"]')[0].getValue().startsWith("translation")) {
      if (trset[j].query('component[name="stav"]')[0].getValue() == 'published') {
        preklad_vyplneno = true;
      }
    }
  }
  Ext.each(Ext.getCmp('vyznamy_box').query('[name=translation_unknown]'), function (item) { if (item.checked) { preklad_vyplneno = true } });
  console.log('preklad_vyplneno=' + preklad_vyplneno);

  if (video_vyplneno && preklad_vyplneno && trans_vyplneno && vyklad_vyplneno) {
    zjisteny_stav = 2;
  } else if (video_vyplneno && preklad_vyplneno) {
    zjisteny_stav = 1;
  } else if (video_vyplneno || preklad_vyplneno || trans_vyplneno || vyklad_vyplneno) {
    zjisteny_stav = 0;
  }

  var stav_popis = [locale[lang].stav_popis_nevyplnene, locale[lang].stav_popis_neuplne, locale[lang].stav_popis_uplne];

  switch (viditelnost) {
    case '0':
      if (zjisteny_stav == 2) { stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_published); }
      else if (zjisteny_stav == 1) { stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_transOnly); }
      else { stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_hidden); };
      break;
    case '1':
      stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_hidden);
      break;
    case '2':
      stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_published);
      break;
    case '100':
      if (zjisteny_stav == 2) { stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_published); }
      else if (zjisteny_stav == 1) { stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_transOnly); }
      else { stav.setValue(stav_popis[zjisteny_stav] + ' / ' + locale[lang].lemma_hidden); };
      break;
  }
}

function check_perm(heslo_skupina, user_skupina, user_perm) {
  console.log('heslo=' + heslo_skupina);
  console.log('user =' + user_skupina);
  console.log('perm =' + user_perm);
  // je admin
  if (user_perm.indexOf('admin') > -1) {
    Ext.getCmp('tabForm').query('[name=userperm]')[0].setValue('admin');
    return true;
  }
  Ext.getCmp('boxlemma').setDisabled(true);
  Ext.each(Ext.getCmp('tabForm').query('[name=stavbutton]'), function (item) {
    if (item.getEl() != undefined) {
      item.getEl().hide();
    }
  });
  if (user_skupina.indexOf(heslo_skupina) > -1 || user_skupina.indexOf('all') > -1) {
    //stejna skupina, kontrola prav
    Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topcont]'), function (tc) { Ext.each(tc.items.items, function (item) { item.setDisabled(true) }) }); //disable na vsechno ve vyznamech
    Ext.each(Ext.getCmp('tabForm').query('[name=usageset]'), function (item) { item.setDisabled(true) }); //disable usage
    Ext.each(Ext.getCmp('tabForm').query('[name=copybox]'), function (item) { item.setDisabled(true) }); //disable copy
    Ext.getCmp('swfieldset').setDisabled(true);
    Ext.getCmp('hamnbox').setDisabled(true);

    if (user_perm.indexOf('editor_preklad') > -1 || user_perm.indexOf('revizor_preklad') > -1) {
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=relbox]'), function (item) { item.up().setDisabled(false); item.setDisabled(false) });
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=translation_unknown]'), function (item) { item.setDisabled(false) });
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=translation_set]'), function (item) { item.setDisabled(false) });
      Ext.getCmp('gramdesc').collapse();
      Ext.getCmp('styldesc').collapse();
    }
    if (user_perm.indexOf('editor_video') == -1) {
      Ext.getCmp('videobox').setDisabled(true);
      Ext.getCmp('media').setDisabled(true); //disable media		
    }
    if (user_perm.indexOf('editor_formal') == -1) {
      //Ext.getCmp('gramdesc').setDisabled(true);
      Ext.each(Ext.getCmp('gramdesc').items.items, function (ii) {
        Ext.each(ii.items.items, function (iii) {
          Ext.each(iii.items.items, function (item) {
            if (item.getEl() != undefined) {
              item.setDisabled(true);
            }
          });
        });
      });
      Ext.each(Ext.getCmp('styldesc').items.items, function (ii) {
        Ext.each(ii.items.items, function (item) {
          if (item.getEl() != undefined) {
            item.setDisabled(true);
          }
        });
      });
      //Ext.getCmp('styldesc').setDisabled(true);
      //Ext.getCmp('vyznamy_box').setDisabled(true);
      //Ext.getCmp('hamnbox').collapse()
    }
    if (user_perm.indexOf('editor_formal') > -1) {
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topcont]'), function (tc) { Ext.each(tc.items.items, function (item) { item.setDisabled(false) }) });
      Ext.each(Ext.getCmp('tabForm').query('[name=usageset]'), function (item) { item.setDisabled(false) });
      Ext.each(Ext.getCmp('tabForm').query('[name=copybox]'), function (item) { item.setDisabled(false) });
    }
    if (user_perm.indexOf('revizor_video') > -1) {
      //Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznammeta]'), function(tc){ Ext.each(tc.items.items, function(item){item.setDisabled(false)})});
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topmeta]'), function (item) { item.setDisabled(false) })
      //Ext.each(Ext.getCmp('vyznamy_box').query('[name=meaning_nr]'), function(item) {item.setDisabled(true)})
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=commentbutton]'), function (item) { item.setDisabled(false) })
    }

    if (user_perm.indexOf('editor_transkripce') == -1 && user_perm.indexOf('editor_formal') == -1) {
      Ext.getCmp('boxcolloc').setDisabled(true);
      Ext.getCmp('hamnbox').collapse();
    }
    if (user_perm.indexOf('editor_transkripce') > -1) {
      Ext.getCmp('swfieldset').setDisabled(false);
      Ext.getCmp('hamnbox').setDisabled(false);
      Ext.getCmp('gvarbox').setDisabled(false);
      Ext.getCmp('varbox').setDisabled(false);
      Ext.getCmp('vyznamy_box').collapse();
    }
    if (user_perm.indexOf('editor_video') > -1) {
      Ext.getCmp('vyznamy_box').expand();
    }

    //komparator jen komentare
    if (user_perm.indexOf('editor_komparator') > -1) {
      Ext.each(Ext.getCmp('tabForm').query('[name=commentbutton]'), function (item) { item.setDisabled(false) })
      Ext.getCmp('media').setDisabled(false);
      Ext.each(Ext.getCmp('mediabox').query('component[name=mediaiteminfo]'), function (item) { item.setDisabled(true); })
    }

    //revizor
    if (user_perm.indexOf('revizor_lemmaczj') > -1 || user_perm.indexOf('editor_czjlemma') > -1) {
      Ext.getCmp('boxlemma').setDisabled(false);
      Ext.getCmp('boxcolloc').setDisabled(false);
    }
    if (user_perm.indexOf('revizor_transkripce') > -1) {
      Ext.getCmp('swfieldset').setDisabled(false);
      Ext.getCmp('hamnbox').setDisabled(false);
      Ext.getCmp('boxcolloc').setDisabled(false);
      Ext.getCmp('gvarbox').setDisabled(false);
      Ext.getCmp('varbox').setDisabled(false);
      Ext.each(Ext.getCmp('swfieldset').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('hamnbox').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('boxcolloc').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
    }
    if (user_perm.indexOf('revizor_preklad') > -1) {
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=relbox] [name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
    }
    // revizor lingvista
    if (user_perm.indexOf('revizor_lingvist') > -1) {
      //Ext.getCmp('gramdesc').setDisabled(false);
      //Ext.getCmp('styldesc').setDisabled(false);
      Ext.each(Ext.getCmp('gramdesc').items.items, function (ii) {
        Ext.each(ii.items.items, function (iii) {
          Ext.each(iii.items.items, function (item) {
            if (item.getEl() != undefined) {
              item.setDisabled(false);
            }
          });
        });
      });
      Ext.each(Ext.getCmp('styldesc').items.items, function (ii) {
        Ext.each(ii.items.items, function (item) {
          if (item.getEl() != undefined) {
            item.setDisabled(false);
          }
        });
      });
      Ext.getCmp('boxcolloc').setDisabled(false);
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topcont]'), function (tc) { Ext.each(tc.items.items, function (item) { item.setDisabled(false) }) });
      Ext.each(Ext.getCmp('tabForm').query('[name=usageset]'), function (item) { item.setDisabled(false) });
      Ext.each(Ext.getCmp('tabForm').query('[name=copybox]'), function (item) { item.setDisabled(false) });
      Ext.each(Ext.getCmp('boxcolloc').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('styldesc').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('gramdesc').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
    }
    // revizor video
    if (user_perm.indexOf('revizor_video') > -1) {
      Ext.getCmp('videobox').setDisabled(false);
      Ext.each(Ext.getCmp('videobox').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=stavbutton]'), function (item) {
        if (item.getEl() != undefined) {
          item.getEl().show();
        }
      });
      Ext.each(Ext.getCmp('vyznamy_box').query('[name=vyznam_topcont]'), function (tc) { Ext.each(tc.items.items, function (item) { item.setDisabled(false) }) });
      Ext.each(Ext.getCmp('tabForm').query('[name=usageset]'), function (item) { item.setDisabled(false) });
    }

  } else if (user_perm.indexOf('editor_formal') > -1) {
    //ruzna skupina, muze pridat vyznam
    Ext.each(Ext.getCmp('gramdesc').items.items, function (ii) {
      Ext.each(ii.items.items, function (iii) {
        Ext.each(iii.items.items, function (item) {
          if (item.getEl() != undefined) {
            item.setDisabled(true);
          }
        });
      });
    });
    Ext.each(Ext.getCmp('styldesc').items.items, function (ii) {
      Ext.each(ii.items.items, function (item) {
        if (item.getEl() != undefined) {
          item.setDisabled(true);
        }
      });
    });
    Ext.each(Ext.getCmp('tabForm').query('[name=copybox]'), function (item) { item.setDisabled(true) }); //disable copy
    Ext.getCmp('swfieldset').setDisabled(true);
    Ext.getCmp('hamnbox').setDisabled(true);
    Ext.getCmp('boxcolloc').collapse();
    Ext.getCmp('boxcolloc').setDisabled(true);
    Ext.getCmp('formaldesc').setDisabled(true);
    Ext.getCmp('hamnbox').collapse();
    Ext.each(Ext.getCmp('tabForm').query('component[name="vyznam"]'), function (item) {
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

function change_gram(elid, pos, typ) {
  if (typ == undefined) {
    Ext.getCmp(elid).query('component[name=skupina]')[0].clearValue();
  }
  Ext.getCmp(elid).query('component[name=skupina2]')[0].clearValue();
  Ext.getCmp(elid).query('component[name=skupina3]')[0].clearValue();
  if (typ == undefined) {
    switch (pos) {
      case 'subst':
        Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_substStore);
        Ext.getCmp(elid).query('component[name=skupina3]')[0].bindStore(pos_subst_plurStore);
        break;
      case 'verb':
        Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_verbStore);
        Ext.getCmp(elid).query('component[name=skupina3]')[0].bindStore(pos_verb_2Store);
        break;
      case 'pron':
        Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_pronStore);
        Ext.getCmp(elid).query('component[name=skupina3]')[0].bindStore(emptyStore);
        break;
      case 'modif':
        Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_modStore);
        // Ext.getCmp(elid).query('component[name=skupina3]')[0].bindStore(pos_cas2Store);
        break;
      case 'num':
        Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_numStore);
        Ext.getCmp(elid).query('component[name=skupina3]')[0].bindStore(emptyStore);
        break;
      case 'part':
        Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(pos_partStore);
        Ext.getCmp(elid).query('component[name=skupina3]')[0].bindStore(emptyStore);
        break;
      default:
        Ext.getCmp(elid).query('component[name=skupina]')[0].bindStore(emptyStore);
        break;
    }
  } else {
    switch (pos) {
      case 'verb':
        switch (typ) {
          case 'proste':
            Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_verb_prosteStore);
            break;
          case 'prostor':
            Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_verb_prostorStore);
            break;
          case 'shodove':
            Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_verb_shodoveStore);
            break;
          default:
            Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
            break;
        }
        break;
      case 'num':
        switch (typ) {
          case 'rad':
            Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_num_radStore);
            break;
          case 'nas':
            Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(pos_num_nasStore);
            break;
          default:
            Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
            break;
        }
        break;
      default:
        Ext.getCmp(elid).query('component[name=skupina2]')[0].bindStore(emptyStore);
        break;
    }
  }
}

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
          var cid = data.comments[i]['_id']['$oid']; // ID komentáře
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
                    name: 'user',
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
                xtype: 'combo', name: 'user', queryMode: 'local', emptyText: locale[lang].commentassign, cls: 'transparent',
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

function prepare_swe(sw_id) {
  var swar = Ext.getCmp(sw_id).query('component[name=swdata]')[0].getValue().split("_");
  var set = [];

  for (var i = 0; i < swar.length; i++) {
    if (swar[i] != '') {
      var found = swar[i].match(/([0-9]+)(\(.*\))?/);
      var found2 = null;
      if (found[2] != null) {
        found2 = found[2].match(/\((x[\-0-9]+)?(y[\-0-9]+)?\)/);
      }
      var hash = { "symbol_id": found[1] };
      if (found2 != null) {
        if (found2[1] != undefined) {
          hash['x'] = found2[1].substring(1);
        } else {
          hash['x'] = '0';
        }
        if (found2[2] != undefined) {
          hash['y'] = found2[2].substring(1);
        } else {
          hash['y'] = '0';
        }
      } else {
        hash['y'] = '0';
        hash['x'] = '0';
      }
      set.push(hash);
    }
  }
  return JSON.stringify({ "id": sw_id, "name": "", "set": set });
}
function open_swe(sw_id) {
  var swar = Ext.getCmp(sw_id).query('component[name=swdata]')[0].getValue().split("_");
  var set = [];

  for (var i = 0; i < swar.length; i++) {
    if (swar[i] != '') {
      var found = swar[i].match(/([0-9]+)(\(.*\))?/);
      var found2 = null;
      if (found[2] != null) {
        found2 = found[2].match(/\((x[\-0-9]+)?(y[\-0-9]+)?\)/);
      }
      var hash = { "symbol_id": found[1] };
      if (found2 != null) {
        if (found2[1] != undefined) {
          hash['x'] = found2[1].substring(1);
        } else {
          hash['x'] = '0';
        }
        if (found2[2] != undefined) {
          hash['y'] = found2[2].substring(1);
        } else {
          hash['y'] = '0';
        }
      } else {
        hash['y'] = '0';
        hash['x'] = '0';
      }
      set.push(hash);
    }
  }
  var sw_obj = { "id": sw_id, "name": "", "set": set };
  var nw = window.open('/editor/swe/test.html');
  nw.onload = function () {
    nw.onload(JSON.stringify(sw_obj));
  };
}

function getglyph(swid, swdata) {
  //alert(swid, swdata)
  var swobj = JSON.parse(swdata);
  var swar = [];
  for (var i = 0; i < swobj.set.length; i++) {
    var sws = swobj.set[i].symbol_id;
    if ((swobj.set[i].x != undefined && swobj.set[i].x != '') || (swobj.set[i].y != undefined && swobj.set[i].y != '')) {
      sws += '(';
      if (swobj.set[i].x != undefined && swobj.set[i].x != '') {
        sws += 'x' + swobj.set[i].x;
      }
      if (swobj.set[i].y != undefined && swobj.set[i].y != '') {
        sws += 'y' + swobj.set[i].y;
      }
      sws += ')';
    }
    swar.push(sws);
  }
  Ext.getCmp(swid).query('component[name="swdata"]')[0].setValue(swar.join('_'));
  Ext.Ajax.request({
    url: '/' + dictcode + '/getfsw',
    params: {
      sw: swar.join('_'),
    },
    method: 'get',
    success: function (response) {
      Ext.getCmp(swid).query('component[name="fsw"]')[0].setValue(response.responseText);
      Ext.getCmp(swid).query('component[name="swimg"]')[0].el.setHTML('<img src="https://sign.dictio.info/fsw/sign/png/' + response.responseText + '-CG_white_"/>');
    }
  });
}

function recieveDatahamndata(data) {
  if (typeof console != "undefined") {
    console.log("recieveData(), " + data);
  }
  Ext.get('hamndata-inputEl').dom.value = data;
}

function reload_rel(search, field, target) {
  relationlist.loadData([], false);
  Ext.Ajax.request({
    url: '/' + target + '/relfind',
    params: {
      search: search,
    },
    method: 'get',
    success: function (response) {
      /* fill media info */
      relationlist.loadData([], false);
      var data = JSON.parse(response.responseText);
      Ext.suspendLayouts();
      var html = '';
      for (i = 0; i < data.length; i++) {
        if (data[i] != undefined && data[i].id && !(data[i].id.startsWith(entryid + '-'))) {
          try {
            relationlist.add({ id: data[i].id, title: data[i].title, number: data[i].number, def: data[i].def, loc: data[i].loc, target: target, front: data[i].front });
          } catch (er) {
            console.log(er);
          }
        }
      }
      Ext.resumeLayouts(true);
      field.expand();
      console.log(relationlist)
    }
  });
}
function reload_link(search, field) {
  linklist.loadData([], false);
  Ext.Ajax.request({
    url: '/' + dictcode + '/linkfind',
    params: {
      search: search,
    },
    method: 'get',
    success: function (response) {
      /* fill media info */
      var data = JSON.parse(response.responseText);
      Ext.suspendLayouts();
      var html = '';
      for (i = 0; i < data.length; i++) {
        linklist.add({ id: data[i].id, title: data[i].title, label: data[i].label, loc: data[i].loc });
      }
      Ext.resumeLayouts(true);
      field.expand();
    }
  });
}

function reload_files(id, search, add_preview, load_variant, type) {
  console.log('reload files start ' + new Date().getTime());
  if (type == undefined) {
    type = '';
  }
  filelist.loadData([], false);
  Ext.Ajax.request({
    url: '/' + dictcode + '/filelist/' + id,
    params: {
      search: search,
      type: type
    },
    method: 'get',
    success: function (response) {
      /* fill media info */
      var data = JSON.parse(response.responseText);
      console.log('reload files response ' + new Date().getTime())
      Ext.suspendLayouts();
      var html = '';
      for (i = 0; i < data.length; i++) {
        var med = create_media(id, false, data[i].location);
        Ext.getCmp('mediabox').add(med);
        med.query('component[name="mediaid"]')[0].setValue(data[i].id);
        med.query('component[name="videoid"]')[0].setValue(data[i].id);
        med.query('component[name="vidid"]')[0].setValue(data[i].location);
        med.query('component[name="type"]')[0].setValue(data[i].type);
        med.query('component[name="copy_admin"]')[0].setValue(data[i].admin_comment);
        med.query('component[name="copy_autor"]')[0].setValue(data[i].id_meta_author);
        med.query('component[name="copy_copy"]')[0].setValue(data[i].id_meta_copyright);
        med.query('component[name="copy_zdroj"]')[0].setValue(data[i].id_meta_source);
        med.query('component[name="original"]')[0].setValue(data[i].original_file_name);
        if (data[i].orient == 'lr') {
          med.query('component[inputValue="lr"]')[0].setValue(true);
        } else {
          med.query('component[inputValue="pr"]')[0].setValue(true);
        }

        change_stav(med.query('component[name="stavcont"]')[0], data[i].status);

        filelist.add({ id: data[i].id, location: data[i].location, author: data[i].id_meta_author, source: data[i].id_meta_source, admin: data[i].admin_comment, copyright: data[i].id_meta_copyright, status: data[i].status, original: data[i].original_file_name, orient: data[i].orient, type: data[i].type });
      }
      Ext.resumeLayouts(true);
      console.log('reload files end ' + new Date().getTime());
      if (add_preview == true) {
        add_videopreview();
      }
      if (Ext.getCmp('tabForm').query('component[name="userperm"]')[0].getValue().indexOf('editor_komparator') > -1) {
        Ext.each(Ext.getCmp('mediabox').query('component[name=mediaiteminfo]'), function (item) { item.setDisabled(true); })
      }
      if (load_variant == true) {
        var variants = Ext.getCmp('tabForm').query('[name=variantitem]');
        for (var i = 0; i < variants.length; i++) {
          if (filelist.findRecord('id', variants[i].query('[name=variant]')[0].getValue()) != null) {
            var vdata = filelist.findRecord('id', variants[i].query('[name=variant]')[0].getValue()).data;
            variants[i].query('component[name="variant_name"]')[0].setValue(vdata.location);
            variants[i].query('component[name="variantpreview"]')[0].update('<div class="videofancybox" data-ratio="0.8" class="usage" style="width:120px; cursor: zoom-in;"><video class=' + dictcode + ' width="120px" poster="https://www.dictio.info/thumb/video' + dictcode + '/' + vdata.location + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + vdata.location + '"></source></video></div>');
            variants[i].query('component[name="variantpreview"]')[0].setHeight(90);
          }
        }
      }
    }
  });
}

function activate_player(player, autoplay) {
  /* activate players, set size for flash */
  $(player).flowplayer({ width: 150, height: 120, ratio: 0.8, autoplay: autoplay });
  $(player + ' .fp-ratio').css('padding-top', 0)
  $(player + ' object').attr('width', '150');
  $(player + ' object').attr('height', '120');
}

// hlavní video - co dělá tato funkce?
function add_preview_main() {  
  /* add video player tag */
  var mar = Ext.getCmp('videobox').query('component[name=viditem]');
  for (var i = 0; i < mar.length; i++) {
    var loc = mar[i].query('component[name="vidid"]')[0].getValue();
    mar[i].query('component[name="videoimg"]')[0].el.setHTML('<div class="videofancybox main" id="flowvideo' + mar[i].query('component[name="mediaid"]')[0].getValue() + '" data-width="300" data-ratio="0.8" style="width:300px; height: 225px; background:#777 url(https://www.dictio.info/thumb/video' + dictcode + '/' + loc + ') no-repeat; background-size: 300px 225px; background-image-opacity: 0.5; cursor: zoom-in;"><video class=' + dictcode + ' poster="https://www.dictio.info/thumb/video' + dictcode + '/' + loc + '" onmouseover="this.play()" onmouseout="this.pause()" width="300px" height="225px" loop="loop"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + loc + '"></source></video></div>');
  }
  //activate_player('.player');
  /* add SW img */
  var swar = Ext.getCmp('swbox').query('component[name=switem]');
  for (var i = 0; i < swar.length; i++) {
    var fsw = swar[i].query('component[name="fsw"]')[0].getValue();
    swar[i].query('component[name="swimg"]')[0].el.setHTML('<img src="https://sign.dictio.info/fsw/sign/png/' + fsw + '-CG_white_"/>');
  }
}

// náhled videa ve vyskakovacím okně
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

// náhled v připojených souborech
function add_videopreview() {
  /* add player tag */
  var mar = Ext.getCmp('mediabox').query('component[name=mediaitem]');
  console.log(mar);
  for (var i = 0; i < mar.length; i++) {
    var loc = mar[i].query('component[name="vidid"]')[0].getValue();
    console.log('add preview ' + loc);
    mar[i].query('component[name="mediaimg"]')[0].el.setHTML('<div id="flowvideo' + mar[i].query('component[name="mediaid"]')[0].getValue() + '" data-width="200" data-ratio="0.8" style="width:200px; background:#777 url(https://www.dictio.info/thumb/video' + dictcode + '/' + loc + ') no-repeat; background-size: 200px 160px; background-image-opacity: 0.5; "><video class=' + dictcode + ' poster="https://www.dictio.info/thumb/video' + dictcode + '/' + loc + '" onmouseover="this.play()" onmouseout="this.pause()" width="200px" loop="loop"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + loc + '"></source></video></div>');
  }
  //  activate_player('.player2');
}

function new_entry() {
  var loadMask = new Ext.LoadMask(Ext.getBody(), { msg: " " });
  console.log('new start ' + new Date().getTime())
  Ext.suspendLayouts();
  loadMask.show();
  Ext.Ajax.request({
    url: '/' + dictcode + '/newentry',
    method: 'get',
    success: function (response) {
      var data = JSON.parse(response.responseText);
      entryid = data['newid'].toString();
      entrydata = { 'meanings': [{ 'id': data['newid'] + '-1', 'created_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s') }], 'lemma': { 'created_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s') } };
      Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase() + '-' + entryid);
      document.title = dictcode.toUpperCase() + ' ' + entryid;
      Ext.getCmp('tabForm').query('component[name="userskupina"]')[0].setValue(data['user_info']['skupina'].join(','));
      Ext.getCmp('tabForm').query('component[name="userperm"]')[0].setValue(data['user_info']['perm']);
      Ext.getCmp('tabForm').query('component[name="usersetrel"]')[0].setValue(data['set_rel']);
      Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].setValue(data['user_info']['copy']);
      Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].setValue(data['user_info']['zdroj']);
      Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].setValue(data['user_info']['autor']);
      Ext.getCmp('tabForm').query('component[name="completeness"]')[0].setValue('0');
      if (data['user_info']['skupina'] != undefined) {
        var skupiny = data['user_info']['skupina'];
        Ext.getCmp('tabForm').query('component[name="pracskupina"]')[0].setValue(skupiny[0]);
      }

      Ext.getCmp('vyznamy_box').remove(Ext.getCmp('vyznamy_box').query('component[name="vyznam"]')[0]);
      Ext.getCmp('vyznamy_box').insert(Ext.getCmp('vyznamy_box').items.length - 1, create_vyznam(data['newid'], true, data['newid'] + '-1'));
      max_meaning = 1;
      var copys = Ext.getCmp('tabForm').query('[name=copybox]');
      for (var i = 0; i < copys.length; i++) {
        copys[i].query('[name=copy_copy]')[0].setValue(data['user_info']['copy']);
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
  const footerCopy = document.querySelector('.footer__copy');
  if (footerCopy) { footerCopy.innerHTML += ` (eDictSIGN v ${version})`; }
  var loadMask = new Ext.LoadMask(Ext.getBody(), { msg: " " });
  console.log('load start ' + new Date().getTime())
  Ext.suspendLayouts();
  loadMask.show();
  if (history != undefined && historytype != undefined) {
    var url = '/' + dictcode + '/json/' + id + '?history=' + history + '&historytype=' + historytype;
  } else {
    var url = '/' + dictcode + '/json/' + id;
  }
  Ext.Ajax.request({
    url: url,
    method: 'get',
    success: function (response) {
      console.log('parse start ' + new Date().getTime())
      var data = JSON.parse(response.responseText);
      entrydata = data;
      console.log(data)
      console.log('ext form start ' + new Date().getTime())
      Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase() + '-' + id);
      document.title = dictcode.toUpperCase() + ' ' + id;

      if (data['lemma'] != undefined) {
        /* heslo */
        Ext.getCmp('tabForm').query('component[name="userskupina"]')[0].setValue(data['user_info']['skupina'].join(','));
        Ext.getCmp('tabForm').query('component[name="userperm"]')[0].setValue(data['user_info']['perm']);
        Ext.getCmp('tabForm').query('component[name="usersetrel"]')[0].setValue(data['set_rel']);
        Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].setValue(data['user_info']['copy']);
        Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].setValue(data['user_info']['zdroj']);
        Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].setValue(data['user_info']['autor']);
        Ext.getCmp('tabForm').query('component[name="media_folder_id"]')[0].setValue(data['lemma']['media_folder_id']);
        Ext.getCmp('tabForm').query('component[name="completeness"]')[0].setValue(data['lemma']['completeness']);
        if (Ext.getCmp('tabForm').query('component[name="completeness"]')[0].getValue() === null) {
          Ext.getCmp('tabForm').query('component[name="completeness"]')[0].setValue('0');
        }
        Ext.getCmp('tabForm').query('component[name="pracskupina"]')[0].setValue(data['lemma']['pracskupina']);
        Ext.getCmp('tabForm').query('component[name="puvod_slova"]')[0].setValue(data['lemma']['puvod']);
        Ext.getCmp('tabForm').query('component[name="admin_comment"]')[0].setValue(data['lemma']['admin_comment']);
        if (data['lemma']['homonym']) {
          Ext.getCmp('tabForm').query('component[name="homonym"]')[0].setValue(data['lemma']['homonym'].filter(item => item != '').join(','));
        }
        if (data['collocations'] && data['collocations']['swcompos'] && data['collocations']['swcompos'] != "") {
          Ext.getCmp('tabForm').query('component[name="swcompos"]')[0].setValue(data['collocations']['swcompos'].toUpperCase());
        }

        /* videa */
        if (data['lemma']['video_front'] && data['lemma']['video_front'].length > 0) {
          var vid = create_video(id, false, data['lemma']['video_front']);
          Ext.getCmp('videobox').insert(Ext.getCmp('videobox').items.length - 1, vid);
          vid.query('component[name="vidid"]')[0].setValue(data['lemma']['video_front']);
          vid.query('component[name="type"]')[0].setValue('front');
          var file = data['media']['video_front'];
          vid.query('component[name="mediaid"]')[0].setValue(file['id']);
          vid.query('component[name="copy_admin"]')[0].setValue(file['admin_comment']);
          vid.query('component[name="copy_autor"]')[0].setValue(file['id_meta_author']);
          vid.query('component[name="copy_copy"]')[0].setValue(file['id_meta_copyright']);
          vid.query('component[name="copy_zdroj"]')[0].setValue(file['id_meta_source']);
          vid.query('component[name="original"]')[0].setValue(file['original_file_name']);
          change_stav(vid.query('component[name="stavcont"]')[0], file['status']);
          if (file['orient'] == 'lr') {
            vid.query('component[inputValue="lr"]')[0].setValue(true);
          } else {
            vid.query('component[inputValue="pr"]')[0].setValue(true);
          }
        }
        if (data['lemma']['video_side'] && data['lemma']['video_side'].length > 0) {
          var vid = create_video(id, false, data['lemma']['video_side']);
          Ext.getCmp('videobox').insert(Ext.getCmp('videobox').items.length - 1, vid);
          vid.query('component[name="vidid"]')[0].setValue(data['lemma']['video_side']);
          vid.query('component[name="type"]')[0].setValue('side');
          var file = data['media']['video_side'];
          vid.query('component[name="mediaid"]')[0].setValue(file['id']);
          vid.query('component[name="copy_admin"]')[0].setValue(file['admin_comment']);
          vid.query('component[name="copy_autor"]')[0].setValue(file['id_meta_author']);
          vid.query('component[name="copy_copy"]')[0].setValue(file['id_meta_copyright']);
          vid.query('component[name="copy_zdroj"]')[0].setValue(file['id_meta_source']);
          vid.query('component[name="original"]')[0].setValue(file['original_file_name']);
          change_stav(vid.query('component[name="stavcont"]')[0], file['status']);
          if (file['orient'] == 'lr') {
            vid.query('component[inputValue="lr"]')[0].setValue(true);
          } else {
            vid.query('component[inputValue="pr"]')[0].setValue(true);
          }
        }

        /* gramatika */
        if (data['lemma']['grammar_note'] && data['lemma']['grammar_note'].length > 0) {
          var gram = data['lemma']['grammar_note'][0];
          if (gram['_text']) {
            Ext.getCmp('tabForm').query('component[name="gramatikatext_text"]')[0].setValue(gram['_text']);
            if (gram['_text'].match(/\[media_id=[0-9]*\]/)) {
              let tmed = gram['_text'].match(/\[media_id=([0-9]*)\]/)[1];
              let prevloc = data['media'][tmed]['location'];
              if (prevloc) Ext.getCmp('tabForm').query('component[id="gramatikatext_videoprev"]')[0].update('<div class="videofancybox" id="flowvideo' + prevloc + '" data-width="150" data-ratio="0.8" style="width:150; background:#777) no-repeat; background-size: 150px 125px; cursor: zoom-in"><video poster="https://www.dictio.info/thumb/video' + dictcode + '/' + prevloc + '" width="150" loop="loop" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + prevloc + '"></source></video></div>');
            }
          }
          if (gram['@author']) Ext.getCmp('gramdesc').query('component[name="copy_autor"]')[0].setValue(gram['@author']);
          if (gram['@admin']) Ext.getCmp('gramdesc').query('component[name="copy_admin"]')[0].setValue(gram['@admin']);
          if (gram['@source']) Ext.getCmp('gramdesc').query('component[name="copy_zdroj"]')[0].setValue(gram['@source']);
          if (gram['@copyright']) Ext.getCmp('gramdesc').query('component[name="copy_copy"]')[0].setValue(gram['@copyright']);
          if (gram['@mluv_komp']) Ext.getCmp('gramdesc').query('component[name="mluv_komp"]')[0].setValue(gram['@mluv_komp']);
          if (gram['@mluv_komp_sel']) Ext.getCmp('gramdesc').query('component[name="mluv_komp_sel"]')[0].setValue(gram['@mluv_komp_sel']);
          if (gram['@oral_komp']) Ext.getCmp('gramdesc').query('component[name="oral_komp"]')[0].setValue(gram['@oral_komp']);
          if (gram['@oral_komp_sel']) Ext.getCmp('gramdesc').query('component[name="oral_komp_sel"]')[0].setValue(gram['@oral_komp_sel']);
          if (gram['@region']) Ext.getCmp('styldesc').query('component[name="region"]')[0].setValue(gram['@region'].split(';'));
          change_stav(Ext.getCmp('gramdesc').query('component[name="stavcont"]')[0], gram['@status']);
          /* gram. kategorie */
          Ext.getCmp('gramcont').query('[name=gramitem]')[0].destroy();
          data['lemma']['grammar_note'].forEach(function (gram) {
            var gramit = create_gram(id);
            Ext.getCmp('gramcont').insert(Ext.getCmp('gramcont').items.length - 1, gramit);
            /* zmena skupiny */
            Ext.getCmp(gramit.id).query('component[name="slovni_druh"]')[0].setValue(gram['@slovni_druh']);
            change_gram(gramit.id, gram['@slovni_druh']);
            change_gram(gramit.id, gram['@slovni_druh'], gram['@skupina']);
            Ext.getCmp(gramit.id).query('component[name="skupina"]')[0].setValue(gram['@skupina']);
            if (gram['@skupina2'] != null) {
              Ext.getCmp(gramit.id).query('component[name="skupina2"]')[0].setValue(gram['@skupina2'].split(';'));
            }
            if (gram['@skupina3'] != null) {
              Ext.getCmp(gramit.id).query('component[name="skupina3"]')[0].setValue(gram['@skupina3'].split(';'));
            }
          });
        }
        /* stylistika */
        if (data['lemma']['style_note'] && data['lemma']['style_note'].length > 0) {
          var gram = data['lemma']['style_note'][0];
          if (gram['_text']) {
            Ext.getCmp('tabForm').query('component[name="styltext_text"]')[0].setValue(gram['_text']);
            if (gram['_text'].match(/\[media_id=[0-9]*\]/)) {
              let tmed = gram['_text'].match(/\[media_id=([0-9]*)\]/)[1];
              let prevloc = data['media'][tmed]['location'];
              if (prevloc) Ext.getCmp('tabForm').query('component[id="styltext_videoprev"]')[0].update('<div class="videofancybox" id="flowvideo' + prevloc + '" data-width="150" data-ratio="0.8" style="width:150; background:#777) no-repeat; background-size: 150px 125px; cursor: zoom-in"><video poster="https://www.dictio.info/thumb/video' + dictcode + '/' + prevloc + '" width="150" loop="loop" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + prevloc + '"></source></video></div>');
            }
          }
          if (gram['@generace'] != null) {
            Ext.getCmp('styldesc').query('component[name="generace"]')[0].setValue(gram['@generace'].split(';'));
          }
          Ext.getCmp('styldesc').query('component[name="kategorie"]')[0].setValue(gram['@kategorie']);
          if (gram['@stylpriznak']) Ext.getCmp('styldesc').query('component[name="stylpriznak"]')[0].setValue(gram['@stylpriznak']);
          Ext.getCmp('styldesc').query('component[name="gender"]')[0].setValue(gram['@gender']);
          Ext.getCmp('styldesc').query('component[name="copy_autor"]')[0].setValue(gram['@author']);
          Ext.getCmp('styldesc').query('component[name="copy_admin"]')[0].setValue(gram['@admin']);
          Ext.getCmp('styldesc').query('component[name="copy_zdroj"]')[0].setValue(gram['@source']);
          Ext.getCmp('styldesc').query('component[name="copy_copy"]')[0].setValue(gram['@copyright']);
          change_stav(Ext.getCmp('styldesc').query('component[name="stavcont"]')[0], gram['@status']);
        }
        /* varianty - načtení */
        if (data['lemma']['grammar_note'] && data['lemma']['grammar_note'][0] && data['lemma']['grammar_note'][0]['variant']) {
          data['lemma']['grammar_note'][0]['variant'].forEach(function (gramvar) {
            console.log(gramvar)
            var variant = create_variant(id);
            Ext.getCmp('gvarbox').insert(Ext.getCmp('gvarbox').items.length - 1, variant);
            variant.query('component[name="variant"]')[0].setValue(gramvar['_text']);
            variant.query('component[name="variant_desc"]')[0].setValue(gramvar['@desc']);
            variant.query('component[name="variant_sw"]')[0].setValue(gramvar['@sw']);
            var videoloc = data['media'][gramvar['_text']]['location'];
            variant.query('component[name="variantpreview"]')[0].update('<div class="videofancybox usage" data-ratio="0.8" style="width:120px; cursor: zoom-in;"><video class=' + dictcode + ' width="120px" poster="https://www.dictio.info/thumb/video' + dictcode + '/' + videoloc + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + videoloc + '"></source></video></div>');
            variant.query('component[name="variantpreview"]')[0].setHeight(90);
          });
        }
        if (data['lemma']['style_note'] && data['lemma']['style_note'][0] && data['lemma']['style_note'][0]['variant']) {
          data['lemma']['style_note'][0]['variant'].forEach(function (gramvar) {
            var variant = create_variant(id);
            Ext.getCmp('varbox').insert(Ext.getCmp('varbox').items.length - 1, variant);
            variant.query('component[name="variant"]')[0].setValue(gramvar['_text']);
            variant.query('component[name="variant_desc"]')[0].setValue(gramvar['@desc']);
            variant.query('component[name="variant_sw"]')[0].setValue(gramvar['@sw']);
            var videoloc = data['media'][gramvar['_text']]['location'];
            variant.query('component[name="variantpreview"]')[0].update('<div class="videofancybox" data-ratio="0.8" class="usage" style="width:120px; cursor: zoom-in;"><video class=' + dictcode + ' width="120px" poster="https://www.dictio.info/thumb/video' + dictcode + '/' + videoloc + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + videoloc + '"></source></video></div>');
            variant.query('component[name="variantpreview"]')[0].setHeight(90);
          });
        }

        /* transkripce */
        if (data['lemma']['sw'] && data['lemma']['sw'].length > 0) {
          data['lemma']['sw'].forEach(function (swx) {
            var sw = create_sw(id);
            Ext.getCmp('swbox').insert(Ext.getCmp('swbox').items.length - 1, sw);
            if (swx['@id']) sw.query('component[name="swid"]')[0].setValue(swx['@id']);
            if (swx['@fsw']) sw.query('component[name="fsw"]')[0].setValue(swx['@fsw']);
            if (swx['@misto']) sw.query('component[name="misto"]')[0].setValue(swx['@misto'].split(';'));
            if (swx['@primary'] && (swx['@primary'] == 'true' || swx['@primary'] == true)) sw.query('component[name="primary_sw"]')[0].setValue(true);
            if (swx['_text']) sw.query('component[name="swdata"]')[0].setValue(swx['_text']);
            //copyright
            if (swx['@author']) sw.query('component[name="copy_autor"]')[0].setValue(swx['@author']);
            if (swx['@copyright']) sw.query('component[name="copy_copy"]')[0].setValue(swx['@copyright']);
            if (swx['@source']) sw.query('component[name="copy_zdroj"]')[0].setValue(swx['@source']);
            if (swx['@admin']) sw.query('component[name="copy_admin"]')[0].setValue(swx['@admin']);
          });
        }
        change_stav(Ext.getCmp('swfieldset').query('component[name="stavcont"]')[0], data['lemma']['@swstatus']);

        /*kolokace*/
        if (data['lemma']['lemma_type'] && ['derivat', 'collocation', 'kompozitum', 'fingerspell'].includes(data['lemma']['lemma_type'])) {
          Ext.getCmp('tabForm').query('component[inputValue="' + data['lemma']['lemma_type'] + '"]')[0].setValue(true);
          Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].show();
        } else {
          Ext.getCmp('tabForm').query('component[inputValue="single"]')[0].setValue(true);
        }
        if (data['collocations'] && data['collocations']['status']) {
          change_stav(Ext.getCmp('boxcolloc').query('component[name="stavcont"]')[0], data['collocations']['status']);
        }
        if (data['collocations'] && data['collocations']['colloc']) {
          data['collocations']['colloc'].forEach(function (colloc) {
            var col = create_colloc(id);
            Ext.getCmp('colbox').insert(Ext.getCmp('colbox').items.length - 1, col);
            col.query('component[name="colid"]')[0].setValue(colloc);
          });
        }

        /* hamnosys */
        if (data['lemma']['hamnosys']) {
          if (data['lemma']['hamnosys']['_text']) Ext.getCmp('tabForm').query('component[name="hamndata"]')[0].setValue(data['lemma']['hamnosys']['_text']);
          if (Ext.getCmp('tabForm').query('component[name="hamndata"]')[0].getValue() != '') {
            Ext.getCmp('tabForm').query('component[name="hamnimg"]')[0].el.setHTML('<img src="/sw/tex2img.png?generator[template]=hamnosys&generator[dpi]=200&generator[engine]=x&generator[tex]=' + encodeURI(Ext.getCmp('tabForm').query('component[name="hamndata"]')[0].getValue()) + '"/>');
            Ext.getCmp('tabForm').query('component[name="hamnbutton"]')[0].hide();
          }
          if (data['lemma']['hamnosys']['@author']) Ext.getCmp('hamnosys_copybox').query('component[name="copy_autor"]')[0].setValue(data['lemma']['hamnosys']['@author']);
          if (data['lemma']['hamnosys']['@admin']) Ext.getCmp('hamnosys_copybox').query('component[name="copy_admin"]')[0].setValue(data['lemma']['hamnosys']['@admin']);
          if (data['lemma']['hamnosys']['@source']) Ext.getCmp('hamnosys_copybox').query('component[name="copy_zdroj"]')[0].setValue(data['lemma']['hamnosys']['@source']);
          if (data['lemma']['hamnosys']['@copyright']) Ext.getCmp('hamnosys_copybox').query('component[name="copy_copy"]')[0].setValue(data['lemma']['hamnosys']['@copyright']);
          if (data['lemma']['hamnosys']['@status']) change_stav(Ext.getCmp('hamnbox').query('component[name="stavcont"]')[0], data['lemma']['hamnosys']['@status']);
        }

        /* vyznamy */
        var add_class_rels = {};
        if (data['meanings'] && data['meanings'].length > 0) {
          Ext.getCmp('vyznamy_box').query('component[name="vyznam"]')[0].destroy();
          data['meanings'].sort(function (a, b) { return parseInt(a['number']) - parseInt(b['number']) }).forEach(function (meaning) {
            var vyznam = create_vyznam(id, false, meaning['id']);
            Ext.getCmp('vyznamy_box').insert(Ext.getCmp('vyznamy_box').items.length - 1, vyznam);
            if (meaning['author']) Ext.getCmp(vyznam.id + '_copybox').query('component[name="copy_autor"]')[0].setValue(meaning['author']);
            if (meaning['admin']) Ext.getCmp(vyznam.id + '_copybox').query('component[name="copy_admin"]')[0].setValue(meaning['admin']);
            if (meaning['source']) Ext.getCmp(vyznam.id + '_copybox').query('component[name="copy_zdroj"]')[0].setValue(meaning['source']);
            if (meaning['copyright']) Ext.getCmp(vyznam.id + '_copybox').query('component[name="copy_copy"]')[0].setValue(meaning['copyright']);
            if (meaning['number']) vyznam.query('component[name="meaning_nr"]')[0].setValue(meaning['number']);
            let textval = '';
            let previews = new Array();
            if (meaning['text'] && meaning['text']['file']) {
              if (Array.isArray(meaning['text']['file'])) {
                textval += ' [media_id=' + meaning['text']['file'][0]['@media_id'] + ']';
                previews.push(meaning['text']['file'][0]['@media_id']);
              } else {
                textval += ' [media_id=' + meaning['text']['file']['@media_id'] + ']';
                previews.push(meaning['text']['file']['@media_id']);
              }
            }
            vyznam.query('component[name="' + vyznam.id + '_text_text"]')[0].setValue($.trim(textval));
            let previewstext = '';
            console.log(data['media'])
            for (let p = 0; p < previews.length; p++) {
              if (data['media'][previews[p]]) {
                let prevloc = data['media'][previews[p]]['location'];
                previewstext += '<div class="videofancybox" data-ratio="0.8" class="usage" style="width:240px; cursor: zoom-in;"><video width="240px" poster="https://www.dictio.info/thumb/video' + dictcode + '/' + prevloc + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + prevloc + '"></source></video></div><br/>';
              }
            }
            vyznam.query('component[name="vyznampreviews"]')[0].update(previewstext);
            change_stav(vyznam.query('component[name="stavcont"]')[0], meaning['status']);
            if (meaning['category'] && meaning['category'].length > 0) {
              let categ_array = new Array();
              meaning['category'].forEach(function (cat) {
                categ_array.push(cat);
              });
              vyznam.query('component[name="obor"]')[0].setValue(categ_array);
            }
            if (meaning['style_region']) vyznam.query('component[name="region"]')[0].setValue(meaning['style_region'].split(';'));
            if (meaning['pracskupina']) vyznam.query('component[name="pracskupina"]')[0].setValue(meaning['pracskupina']);
            if (meaning['is_translation_unknown'] && meaning['is_translation_unknown'] == '1') vyznam.query('component[name="translation_unknown"]')[0].setValue(true);

            /* relations */
            if (meaning['relation']) {
              var vztahy = new Array();
              meaning['relation'].forEach(function (trans) {
                var parentid = vyznam.query('component[name="relbox"]')[0].id;
                var transset = create_vyznam_links(parentid);
                var type = trans['type'];
                var target = dictcode;
                if (type == 'translation') {
                  if (trans['target'] == null || trans['target'] == '') {
                    target = 'cs';
                  } else {
                    target = trans['target'];
                  }
                  type = trans['type'] + '_' + target;
                }
                transset.query('component[name="type"]')[0].setValue(type);
                transset.query('component[name="type"]')[0].addCls('relation_' + type);
                if (trans['meaning_id'] != "") {
                  transset.query('component[name="rellink"]')[0].setValue(trans['meaning_id']);
                } else if (trans['entry'] && trans['entry']['lemma']['title']) {
                  transset.query('component[name="rellink"]')[0].setValue(trans['entry']['lemma']['title']);
                }
                if (trans['status']) change_stav(transset.query('component[name="stavcont"]')[0], trans['status']);
                //zobrazeni textu nebo obrazku
                if (target == 'cs' || target == 'en' || target == 'sj' || target == 'de' || target == 'uk') {
                  if (trans['entry'] && trans['entry']['lemma']['title']) {
                    transset.query('component[name="vztahtitle"]')[0].update(trans['entry']['lemma']['title']);
                  }
                } else {
                  if (trans['entry'] && trans['entry']['lemma']['video_front']) {
                    var videoloc = trans['entry']['lemma']['video_front'];
                    transset.query('component[name="vztahtitle"]')[0].update('<div class="videofancybox" data-ratio="0.8" class="usage" style="width:120px; cursor: zoom-in;"><video class=' + target + ' width="80px" poster="https://www.dictio.info/thumb/video' + target + '/' + videoloc + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + target + '/' + videoloc + '"></source></video></div>')
                    transset.query('component[name="vztahtitle"]')[0].setHeight(60);
                  }
                }
                var inner = transset.query('component[name="vztahtitle"]')[0].id + "-innerCt";
                if (trans['title_only'] == 'true' || trans['meaning_id'].match(/^[0-9]*-[_us0-9]*$/) == null) {
                  add_class_rels[inner] = 'redtext';
                } else {
                  add_class_rels[inner] = 'text-' + target;
                  transset.query('component[name=row2]')[0].hide();
                }
                if (trans['notrans'] && trans['notrans'] == true && trans['meaning_id'].match(/^[0-9]*-[_us0-9]*$/) == null) {
                  transset.query('component[name=notrans]')[0].setValue(true);
                  transset.query('component[name=notransuser]')[0].setValue(trans['notransuser']);
                }
                vztahy.push({ type: type, meaningid: trans['meaning_id'], link: transset, transinfo: trans });
              });
              //sort 
              var vztahysort = { synonym: 1, translation_cs: 2, translation_czj: 3, translation_en: 4, translation_is: 5, translation_asl: 6, translation_sj: 7, translation_spj: 8, translation_de: 9, translation_ogs: 10 }
              vztahy.sort(function (a, b) {
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
              vztahy.forEach(function (relation) {
                var cc = create_comment_button(relation.link.id, 'meaning' + meaning['id'] + 'rel' + relation.transinfo['target'] + relation.transinfo['meaning_id'])
                relation.link.query('component[name=row2]')[0].add(cc);
                Ext.getCmp(parentid).insert(Ext.getCmp(parentid).items.length - 3, relation.link);
              });
            }

            /* usages */
            ar_priklady[meaning['id']] = 0;
            if (meaning['usages']) {
              var j = 0;
              meaning['usages'].forEach(function (usage) {
                var usageid, usagec;
                if (usage['id'] && usage['id'] != '') {
                  usageid = usage['id'];
                  usagec = parseInt(usageid.replace(/[0-9\-]*_us/, ''));
                } else {
                  usagec = j;
                }
                var priklad = create_priklad(vyznam.id + '_uziti', id, false, meaning['id'], usageid);
                priklad.query('[name="usage_id"]')[0].setValue(usageid);
                if (ar_priklady[meaning['id']] < usagec) {
                  ar_priklady[meaning['id']] = usagec;
                }
                Ext.getCmp(vyznam.id + '_uziti').insert(Ext.getCmp(vyznam.id + '_uziti').items.length - 1, priklad);
                if (usage['author']) Ext.getCmp(priklad.id + 'copyright_copybox').query('component[name="copy_autor"]')[0].setValue(usage['author']);
                if (usage['admin']) Ext.getCmp(priklad.id + 'copyright_copybox').query('component[name="copy_admin"]')[0].setValue(usage['admin']);
                if (usage['source']) Ext.getCmp(priklad.id + 'copyright_copybox').query('component[name="copy_zdroj"]')[0].setValue(usage['source']);
                if (usage['copyright']) Ext.getCmp(priklad.id + 'copyright_copybox').query('component[name="copy_copy"]')[0].setValue(usage['copyright']);
                if (usage['type'] === 'colloc') { 
                  priklad.query('[inputValue=colloc]')[0].setValue(true);
                } else if (usage['type'] === 'gram') { 
                  priklad.query('[inputValue=gram]')[0].setValue(true);
                } else { 
                  priklad.query('[inputValue=sentence]')[0].setValue(true);
                }
                /* relations */
                if (usage['relation']) {
                  usage['relation'].forEach(function (trans) {
                    var parentid = priklad.query('component[name="exrelbox"]')[0].id;
                    var transset = create_priklad_links(parentid);
                    Ext.getCmp(parentid).insert(Ext.getCmp(parentid).items.length - 1, transset);
                    var type = trans['type'];
                    var target = dictcode;
                    if (type == 'translation') {
                      if (trans['target'] == null || trans['target'] == '') {
                        target = 'cs';
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
                var previews = new Array();
                if (usage['text'] && usage['text']['file']) {
                  if (Array.isArray(usage['text']['file'])) {
                    usage['text']['file'].forEach(function (mf) {
                      textval += ' [media_id=' + mf['@media_id'] + ']';
                      previews.push(mf['@media_id']);
                    });
                  } else {
                    if (usage['text']['file']['@media_id']) {
                      textval += ' [media_id=' + usage['text']['file']['@media_id'] + ']';
                      previews.push(usage['text']['file']['@media_id']);
                    }
                  }
                }
                if (usage['text'] && usage['text']['_text']) textval = usage['text']['_text'];
                priklad.query('component[name="' + priklad.id + 'text_text"]')[0].setValue($.trim(textval));
                var previewstext = '';
                for (var p = 0; p < previews.length; p++) {
                  var prevloc = data['media'][previews[p]]['location'];
                  previewstext += '<div class="videofancybox" data-ratio="0.8" class="usage" style="width:200px; cursor: zoom-in;"><video width="200px" poster="https://www.dictio.info/thumb/video' + dictcode + '/' + prevloc + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + prevloc + '"></source></video></div><br/>';
                }
                priklad.query('component[name="vyznampreviews"]')[0].update(previewstext);
                ar_priklady[meaning['id']]++;
                j++;
              });
            }
          });
        }

        Ext.getCmp('hamnosys').hide();
        console.log('load end ' + new Date().getTime())
        update_stav();
        Ext.resumeLayouts(true);
        check_perm(Ext.getCmp('tabForm').query('[name=pracskupina]')[0].getValue(), Ext.getCmp('tabForm').query('[name=userskupina]')[0].getValue(), Ext.getCmp('tabForm').query('[name=userperm]')[0].getValue());
        loadMask.hide();
        console.log('after mask ' + new Date().getTime())
        add_preview_main();
        setTimeout(add_video_fancybox, 1000); // pridat fancybox se zpozdenim
        for (let [key, value] of Object.entries(add_class_rels)) {
          document.getElementById(key).classList.add(value);
        }
        console.log('layout end ' + new Date().getTime())
        reload_files(id, '', false, true);
        track_change();
        entry_updated = false;
      } else {
        Ext.resumeLayouts(true);
        loadMask.hide();
        Ext.Msg.show({
          title: 'Error',
          msg: locale[lang]['no_entry'] + ' (' + dictcode.toUpperCase() + ' ' + id + ').',
          buttons: Ext.Msg.YESNO, 
          buttonText: {
              yes: locale[lang]['showhistory'], 
              no: locale[lang]['back'] 
          },
          fn: function (btn) {
              if (btn === 'yes') {
                  window.location = 'https://admin.dictio.info/history?code=' + dictcode + '&entry=' + entryid;
              } else if (btn === 'no') {
                  window.history.back();
              }            
          }
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

function entry_update_show(updated) {
  if (updated) {
    document.title = dictcode.toUpperCase() + ' ' + entryid + ' *';
    Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase() + '-' + entryid);
    Ext.getCmp('btnSV1').removeCls('hidden');
    Ext.getCmp('btnSV1').addCls('unhidden');
    /* Ext.getCmp('btnSV2').removeCls('hidden');
    Ext.getCmp('btnSV2').addCls('unhidden');
    Ext.getCmp('btnS2').removeCls('hidden');
    Ext.getCmp('btnS2').addCls('unhidden'); */
    Ext.getCmp('tabForm').query('component[name=modifiedlabel]')[0].setText(' * ' + locale[lang].modified);
  } else {
    document.title = dictcode.toUpperCase() + ' ' + entryid;
    Ext.getCmp('tabForm').setTitle(dictcode.toUpperCase() + '-' + entryid);
    Ext.getCmp('tabForm').query('component[name=modifiedlabel]')[0].setText('');
    Ext.getCmp('btnSV1').removeCls('unhidden');
    Ext.getCmp('btnSV1').addCls('hidden');
    /* Ext.getCmp('btnSV2').removeCls('unhidden');
    Ext.getCmp('btnSV2').addCls('hidden');
    Ext.getCmp('btnS2').removeCls('unhidden');
    Ext.getCmp('btnS2').addCls('hidden'); */
  } 
}

// ukladani
function save_doc(id) {
  var tracking = changes.filter(function (value, index, self) { return self.indexOf(value) === index; }).join(", ");
  changes = new Array();
  var data = {
    'dict': dictcode,
    'id': id.toString(),
    'track_changes': tracking,
    'lemma': {
      'updated_at': Ext.Date.format(new Date(), 'Y-m-d H:i:s'),
      'media_folder_id': Ext.getCmp('tabForm').query('component[name="media_folder_id"]')[0].getValue(),
      'created_at': entrydata['lemma']['created_at'],
      'completeness': Ext.getCmp('tabForm').query('component[name="completeness"]')[0].getValue(),
      'pracskupina': Ext.getCmp('tabForm').query('component[name="pracskupina"]')[0].getValue(),
      'puvod': Ext.getCmp('tabForm').query('component[name="puvod_slova"]')[0].getValue(),
      'admin_comment': Ext.getCmp('tabForm').query('component[name="admin_comment"]')[0].getValue(),
      'status': Ext.getCmp('tabForm').query('component[name="stav"]')[0].getValue(),
      'homonym': Ext.getCmp('tabForm').query('component[name="homonym"]')[0].getValue().split(',').map(x => x.trim()),
      'grammar_note': [{
        '_text': Ext.getCmp('tabForm').query('component[name="gramatikatext_text"]')[0].getValue(),
        '@region': Ext.getCmp('styldesc').query('component[name="region"]')[0].getValue().filter(item => item != '').join(';'),
        '@author': Ext.getCmp('gramdesc').query('component[name="copy_autor"]')[0].getValue(),
        '@copyright': Ext.getCmp('gramdesc').query('component[name="copy_copy"]')[0].getValue(),
        '@source': Ext.getCmp('gramdesc').query('component[name="copy_zdroj"]')[0].getValue(),
        '@admin': Ext.getCmp('gramdesc').query('component[name="copy_admin"]')[0].getValue(),
        '@status': Ext.getCmp('gramdesc').query('component[name="stav"]')[0].getValue(),
        '@mluv_komp': Ext.getCmp('gramdesc').query('component[name="mluv_komp"]')[0].getValue(),
        '@mluv_komp_sel': Ext.getCmp('gramdesc').query('component[name="mluv_komp_sel"]')[0].getValue(),
        '@oral_komp': Ext.getCmp('gramdesc').query('component[name="oral_komp"]')[0].getValue(),
        '@oral_komp_sel': Ext.getCmp('gramdesc').query('component[name="oral_komp_sel"]')[0].getValue(),
        'variant': []
      }],
      'style_note': [{
        '_text': Ext.getCmp('tabForm').query('component[name="styltext_text"]')[0].getValue(),
        '@generace': Ext.getCmp('styldesc').query('component[name="generace"]')[0].getValue().join(';'),
        '@kategorie': Ext.getCmp('styldesc').query('component[name="kategorie"]')[0].getValue(),
        '@stylpriznak': Ext.getCmp('styldesc').query('component[name="stylpriznak"]')[0].getValue().join(';'),
        '@gender': Ext.getCmp('styldesc').query('component[name="gender"]')[0].getValue(),
        '@author': Ext.getCmp('styldesc').query('component[name="copy_autor"]')[0].getValue(),
        '@copyright': Ext.getCmp('styldesc').query('component[name="copy_copy"]')[0].getValue(),
        '@source': Ext.getCmp('styldesc').query('component[name="copy_zdroj"]')[0].getValue(),
        '@admin': Ext.getCmp('styldesc').query('component[name="copy_admin"]')[0].getValue(),
        '@status': Ext.getCmp('styldesc').query('component[name="stav"]')[0].getValue(),
        'variant': []
      }],
      'sw': [],
    },
    'media': [],
  };

  /* gramatika */
  var grams = Ext.getCmp('gramcont').query('[name=gramitem]');
  for (var i = 0; i < grams.length; i++) {
    if (i == 0) {
      data.lemma.grammar_note[0]['@slovni_druh'] = grams[i].query('component[name="slovni_druh"]')[0].getValue();
      data.lemma.grammar_note[0]['@skupina'] = grams[i].query('component[name="skupina"]')[0].getValue();
      data.lemma.grammar_note[0]['@skupina2'] = grams[i].query('component[name="skupina2"]')[0].getValue().join(';');
      data.lemma.grammar_note[0]['@skupina3'] = grams[i].query('component[name="skupina3"]')[0].getValue().join(';');
    } else {
      data.lemma.grammar_note.push({
        '@slovni_druh': grams[i].query('component[name="slovni_druh"]')[0].getValue(),
        '@skupina': grams[i].query('component[name="skupina"]')[0].getValue(),
        '@skupina2': grams[i].query('component[name="skupina2"]')[0].getValue().join(';'),
        '@skupina3': grams[i].query('component[name="skupina3"]')[0].getValue().join(';')
      });
    }
  }
  /* varianty */
  var variants = Ext.getCmp('styldesc').query('[name=variantitem]');
  var variants_ar = new Array();
  for (var i = 0; i < variants.length; i++) {
    var varvid = variants[i].query('[name=variant]')[0].getValue();
    if (varvid != '' && variants_ar.indexOf(varvid) == -1) {
      variants_ar.push(varvid);
      data.lemma.style_note[0].variant.push({
        '_text': varvid,
        '@desc': variants[i].query('[name=variant_desc]')[0].getValue(),
        '@sw': variants[i].query('[name=variant_sw]')[0].getValue()
      });
    }
  }
  var variants = Ext.getCmp('gramdesc').query('[name=variantitem]');
  var variants_ar = new Array();
  for (var i = 0; i < variants.length; i++) {
    var varvid = variants[i].query('[name=variant]')[0].getValue();
    if (varvid != '' && variants_ar.indexOf(varvid) == -1) {
      variants_ar.push(varvid);
      data.lemma.grammar_note[0].variant.push({
        '_text': varvid,
        '@desc': variants[i].query('[name=variant_desc]')[0].getValue(),
        '@sw': variants[i].query('[name=variant_sw]')[0].getValue()
      });
    }
  }
  /* videa */
  data.update_video = []
  var vids = Ext.getCmp('videobox').query('component[name="viditem"]');
  for (var i = 0; i < vids.length; i++) {
    if (vids[i].query('component[name="type"]')[0].getValue() == '' || vids[i].query('component[name="type"]')[0].getValue() == null) {
      Ext.Msg.alert('Chyba', 'U videa není zadán typ.');
      return false;
    }
    if (vids[i].query('component[name="type"]')[0].getValue() == 'front') {
      data.lemma.video_front = vids[i].query('component[name="vidid"]')[0].getValue();
    }
    if (vids[i].query('component[name="type"]')[0].getValue() == 'side') {
      data.lemma.video_side = vids[i].query('component[name="vidid"]')[0].getValue();
    }
    data.update_video.push({
      'id': vids[i].query('component[name="mediaid"]')[0].getValue(),
      'id_meta_author': vids[i].query('component[name="copy_autor"]')[0].getValue(),
      'id_meta_copyright': vids[i].query('component[name="copy_copy"]')[0].getValue(),
      'id_meta_source': vids[i].query('component[name="copy_zdroj"]')[0].getValue(),
      'admin_comment': vids[i].query('component[name="copy_admin"]')[0].getValue(),
      'location': vids[i].query('component[name="vidid"]')[0].getValue(),
      'status': vids[i].query('component[name="stav"]')[0].getValue(),
      'type': 'sign_' + vids[i].query('component[name="type"]')[0].getValue(),
      'orient': vids[i].query('component[name="' + vids[i].id + 'orient"]')[0].getGroupValue(),
    });
  }

  /* transkripce */
  data.lemma.hamnosys = {
    '_text': Ext.get('hamndata-inputEl').dom.value,
    '@author': Ext.getCmp('hamnosys_copybox').query('component[name="copy_autor"]')[0].getValue(),
    '@source': Ext.getCmp('hamnosys_copybox').query('component[name="copy_zdroj"]')[0].getValue(),
    '@copyright': Ext.getCmp('hamnosys_copybox').query('component[name="copy_copy"]')[0].getValue(),
    '@admin': Ext.getCmp('hamnosys_copybox').query('component[name="copy_admin"]')[0].getValue(),
    '@status': Ext.getCmp('hamnbox').query('component[name="stav"]')[0].getValue(),
  };
  var sws = Ext.getCmp('swbox').query('component[name="switem"]');
  for (var i = 0; i < sws.length; i++) {
    var newsw = {
      '@id': sws[i].query('component[name="swid"]')[0].getValue(),
      '@fsw': sws[i].query('component[name="fsw"]')[0].getValue(),
      '@misto': sws[i].query('component[name="misto"]')[0].getValue().join(';'),
      '@author': sws[i].query('component[name="copy_autor"]')[0].getValue(),
      '@copyright': sws[i].query('component[name="copy_copy"]')[0].getValue(),
      '@source': sws[i].query('component[name="copy_zdroj"]')[0].getValue(),
      '@admin': sws[i].query('component[name="copy_admin"]')[0].getValue(),
      '@primary': sws[i].query('component[name="primary_sw"]')[0].checked,
      '_text': sws[i].query('component[name="swdata"]')[0].getValue()
    };
    data.lemma.sw.push(newsw);
    data.lemma['@swstatus'] = Ext.getCmp('swfieldset').query('component[name="stav"]')[0].getValue();
  }

  /*slovni spojeni*/
  if (Ext.getCmp('tabForm').query('component[name="lemma_type"]')[0].getGroupValue() != null) {
    data.lemma.lemma_type = Ext.getCmp('tabForm').query('component[name="lemma_type"]')[0].getGroupValue();
  }
  if (data.lemma.lemma_type != 'single') {
    data.collocations = { 'status': Ext.getCmp('boxcolloc').query('component[name="stav"]')[0].getValue() };
    if (Ext.getCmp('tabForm').query('component[name="swcompos"]')[0].getValue()) {
      data.collocations.swcompos = Ext.getCmp('tabForm').query('component[name="swcompos"]')[0].getValue().toUpperCase();
    }
    data.collocations.colloc = [];
    var cols = Ext.getCmp('colbox').query('component[name="colitem"]');
    for (var i = 0; i < cols.length; i++) {
      data.collocations.colloc.push(cols[i].query('component[name="colid"]')[0].getValue());
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
      'category': [],
      'relation': [],
      'author': Ext.getCmp(meanings[i].id + '_copybox').query('component[name="copy_autor"]')[0].getValue(),
      'copyright': Ext.getCmp(meanings[i].id + '_copybox').query('component[name="copy_copy"]')[0].getValue(),
      'source': Ext.getCmp(meanings[i].id + '_copybox').query('component[name="copy_zdroj"]')[0].getValue(),
      'admin': Ext.getCmp(meanings[i].id + '_copybox').query('component[name="copy_admin"]')[0].getValue(),
      'style_region': meanings[i].query('component[name="region"]')[0].getValue().join(';'),
      'pracskupina': meanings[i].query('component[name="pracskupina"]')[0].getValue(),
    };
    maxnr += 1;
    if (isNaN(parseInt(meanings[i].query('component[name="meaning_nr"]')[0].getValue()))) {
      newmean['number'] = maxnr;
    } else {
      newmean['number'] = parseInt(meanings[i].query('component[name="meaning_nr"]')[0].getValue());
    }
    mean_numbers.push(newmean['@number']);
    if (max_mean < newmean['@number']) {
      max_mean = newmean['@number'];
    }
    var categ_array = meanings[i].query('component[name="obor"]')[0].getValue();
    for (var ci = 0; ci < categ_array.length; ci++) {
      newmean.category.push(categ_array[ci]);
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
        if (reltype != null && reltype.startsWith('translation_')) {
          reltar = reltype.split('_')[1];
          reltype = 'translation';
        }
        if ((trset_ar.indexOf(reltype + rellink + reltar) == -1) && (!(rellink.startsWith(id + '-')) || reltype == 'translation' || reltype == 'translation_colloc')) {
          trset_ar.push(reltype + rellink + reltar);
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
    var textval = meanings[i].query('component[name="' + meanings[i].id + '_text_text"]')[0].getValue();
    if (textval.match(/\[media_id=[0-9]*\]/)) {
      var tmed = textval.match(/\[media_id=([0-9]*)\]/)[1];
      newmean.text = { 'file': { '@media_id': tmed } };
    } else {
      newmean.text = { '_text': textval };
    }

    /* priklady */
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
        'copyright': uses[j].query('component[name="copy_copy"]')[0].getValue(),
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
          var reltar = 'cs';
          if (reltype != null && reltype.startsWith('translation_') && reltype != 'translation_colloc') {
            reltar = reltype.split('_')[1];
            reltype = 'translation';
          }
          if ((trset_ar.indexOf(reltype + rellink + reltar) == -1) && (!(rellink.startsWith(id + '-')) || reltype == 'translation' || reltype == 'translation_colloc')) {
            trset_ar.push(reltype + rellink + reltar);
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
      } else if (uses[j].query('[inputValue=gram]')[0].getValue()) {
        newuse['type'] = 'gram';
      } else {
        newuse['type'] = 'sentence';
      }
      if (uses[j].query('component[name="usage_id"]')[0].getValue() != ''
          && entrydata['meanings'] != undefined
          && entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0] != undefined
          && entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0]['usages'] != undefined
          && entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0]['usages'].filter(usg => usg['id'] == uses[j].query('component[name="usage_id"]')[0].getValue())[0] != undefined) {
        newuse.created_at = entrydata['meanings'].filter(mean => mean['id'] == meanings[i].query('component[name="meaning_id"]')[0].getValue())[0]['usages'].filter(usg => usg['id'] == uses[j].query('component[name="usage_id"]')[0].getValue())[0]['created_at'];
      } else {
        newuse.created_at = Ext.Date.format(new Date(), 'Y-m-d H:i:s');
      }
      var textval = uses[j].query('component[name="' + uses[j].id + 'text_text"]')[0].getValue();
      if (textval.match(/\[media_id=[0-9]*\]/)) {
        var tmed = textval.match(/\[media_id=([0-9]*)\]/)[1];
        newuse.text = { 'file': { '@media_id': tmed } };
      } else {
        newuse.text = { '_text': textval };
      }

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

// stav skryto schvaleno
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

function create_src_list(textid) {
  var select = Ext.create('Ext.form.field.ComboBox', {
    id: 'srclist' + Ext.id(),
    cls: 'src_select',
    matchFieldWidth: false,
    value: '...',
    width: 40,
    queryMode: 'local',
    store: [
      'MU, Středisko Teiresiás',
      'POTMĚŠIL, M. a kol. Všeobecný slovník českého znakového jazyka, A-N. Praha: Fortuna, 2002.',
      'POTMĚŠIL, M. a kol. Všeobecný slovník českého znakového jazyka, O-Ž. Praha: Fortuna, 2004.',
      'POTMĚŠIL, M. a kol. Všeobecný slovník českého znakového jazyka, doplněk O-Ž. Praha: Fortuna, 2006.',
      'LANGER, J. a kol. Znaková zásoba českého znakového jazyka k rozšiřujícímu studiu surdopedie se zaměřením na znakový jazyk (1. a 2. díl). 2. doplněné vydání, Olomouc: Univerzita Palackého, 2005.',
      'LANGER, J. a kol. Slovník pojmů znakového jazyka pro oblast tělesné výchovy a sportu [CD-ROM]. Praha: Fortuna, 2006.',
      'LANGER, J. a kol. Slovník vybraných pojmů znakového jazyka pro oblast dopravní výchovy[CD-ROM]. Praha: Fortuna, 2009.',
      'LANGER, J. a kol. Znaková zásoba českého znakového jazyka k rozšiřujícímu studiu surdopedie se zaměřením na znakový jazyk (3. a 4. díl). 2. doplněné vydání, Olomouc: Univerzita Palackého, 2005.',
      'LANGER, J. a kol. Slovník pojmů znakového jazyka pro oblast vlastivědy [CD-ROM]. Praha: Fortuna, 2007.',
      'LANGER, J. a kol. Slovník vybraných pojmů znakového jazyka pro oblast biologie člověka a zdravovědy [CD-ROM]. Praha: Fortuna, 2008.',
      'FRITZ, Milan. Znaky pro základní kalendářní jednotky v českém znakovém jazyce. Bakalářská práce. Praha: Univerzita Karlova v Praze, 2014.'
    ],
    listeners: {
      'select': function (combo, record, index) {
        if (combo.getValue() != '') {
          Ext.getCmp(textid).setValue(combo.getValue(), false);
        }
      }
    },
  });
  return select;
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

// copyright zakladni 
function create_copyright(idstart, hidden) {
  if (hidden == undefined) {
    hidden = true;
  }
  var copy = Ext.create('Ext.container.Container', {
    id: idstart + '_copybox',
    name: 'copybox',
    cls: 'auth',
    hidden: hidden,
    layout: { type: 'hbox' },
    items: [
      { fieldLabel: locale[lang].author, xtype: 'textfield', labelWidth: 150, width: 350, id: idstart + '_autor', name: 'copy_autor' },
      create_src_list(idstart + '_autor'),
      { /* fieldLabel: locale[lang].authorvideo, */ xtype: 'textfield', labelWidth: 0, width: 0, id: idstart + '_copy',  name: 'copy_copy' },
      { fieldLabel: locale[lang].source, xtype: 'textfield', labelWidth: 100, width: 300,  id: idstart + '_zdroj', name: 'copy_zdroj' }, 
      create_src_list(idstart + '_zdroj'),
      { fieldLabel: locale[lang].admincomment, xtype: 'textfield', labelWidth: 100, width: 300, id: idstart + '_poznamka', name: 'copy_admin' }
    ]
  });
  return copy;
}

// copyright zakladni  SW
function create_copyrightSW(idstart, hidden) {
  if (hidden == undefined) { hidden = true; }
  var copy = Ext.create('Ext.container.Container', 
    { id: idstart + '_copybox',
      name: 'copybox',
      width: '600',
      cls: 'auth',
      hidden: hidden,
      layout: { type: 'hbox' },
      items: [
        { fieldLabel: locale[lang].author, labelWidth: 50, width: 150, xtype: 'textfield', id: idstart + '_autor', name: 'copy_autor' },
        create_src_list(idstart + '_autor'),
        { fieldLabel: locale[lang].authorvideo, labelWidth: 0, width: 0, xtype: 'textfield', id: idstart + '_copy',  name: 'copy_copy', style: { display: 'none' }},
        { fieldLabel: locale[lang].source, xtype: 'textfield',  labelWidth: 50, width: 150,  id: idstart + '_zdroj', name: 'copy_zdroj' }, 
        create_src_list(idstart + '_zdroj'),
        { fieldLabel: locale[lang].admincomment, xtype: 'textfield', labelWidth: 50, width: 150, id: idstart + '_poznamka', name: 'copy_admin' }
      ]
  });
  return copy;
}

function create_copyrightM(idstart, hidden) {
  if (hidden == undefined) {
    hidden = true;
  }
  var copy = Ext.create('Ext.container.Container', {
    id: idstart + '_copybox',
    name: 'copybox',
    cls: 'auth',
    width: 650,
    hidden: hidden,
    layout: { type: 'hbox' },
    items: [
      { xtype: 'container',
        layout: { type: 'vbox'},
        items: [
          { xtype: 'container',
            layout: { type: 'hbox' },
            items: [
              { labelWidth: 50, fieldLabel: locale[lang].author, width: 200, xtype: 'textfield', id: idstart + '_autor', name: 'copy_autor' },
              create_src_list(idstart + '_autor'),
              { labelWidth: 50, fieldLabel: locale[lang].videosrc, width: 200, xtype: 'textfield', id: idstart + '_copy', name: 'copy_copy' },
              create_src_list(idstart + '_copy'),              
              { labelWidth: 50, width: 200, fieldLabel: locale[lang].admincomment, xtype: 'textfield', id: idstart + '_poznamka', name: 'copy_admin' }
            ]
          },
          { xtype: 'container',
            layout: { type: 'hbox' },
            items: [
              { labelWidth: 50, fieldLabel: locale[lang].source, width: 500, xtype: 'textfield', id: idstart + '_zdroj', name: 'copy_zdroj' }, 
              create_src_list(idstart + '_zdroj')
            ]
          }
        ]
      }
    ]
  });
  return copy;
}

// slovní druh
function create_gram(entryid) {
  var name = 'gram_' + Ext.id();
  var text = Ext.create('Ext.container.Container', {
    layout: {
      type: 'hbox'
    },
    frame: true,
    id: name,
    cls: 'gramframe',
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
      listeners: {
        select: function (combo, record, index) {
          change_gram(name, combo.getValue());
        }
      }
    }, {
      xtype: 'combobox',
      fieldLabel: locale[lang].type,
      labelWidth: 50,
      name: 'skupina',
      queryMode: 'local',
      width: 150,
      forceSelection: true,
      autoSelect: true,
      editable: false,
      displayField: 'text',
      valueField: 'value',
      listeners: {
        select: function (combo, record, index) {
          change_gram(name, Ext.getCmp(name).query('component[name="slovni_druh"]')[0].getValue(), combo.getValue());
        }
      }
    }, {
      xtype: 'combobox',
      fieldLabel: locale[lang].subtype,
      labelWidth: 50,
      name: 'skupina2',
      width: 200,
      queryMode: 'local',
      forceSelection: true,
      autoSelect: true,
      editable: false,
      displayField: 'text',
      valueField: 'value',
      multiSelect: true,
    }, {
      xtype: 'combobox',
      name: 'skupina3',
      queryMode: 'local',
      forceSelection: true,
      autoSelect: true,
      width: 385,
      editable: false,
      displayField: 'text',
      valueField: 'value',
      multiSelect: true,
    }, {
      xtype: 'button',
      icon: '/editor/delete.png',
      cls: 'del',
      handler: function () {
        Ext.getCmp(name).destroy();
      }
    }]
  });
  return text;
}

// varianty
function create_variant(entryid) {
  var name = 'var_' + Ext.id();
  var text = Ext.create('Ext.container.Container', {
    layout: { type: 'hbox' },
    id: name,
    name: 'variantitem',
    items: [
      { xtype: 'container', 
        layout: { type: 'vbox' },
        items: [
          { xtype: 'panel', name: 'variantpreview', cls: 'variant-preview', html: '', height: 90}, 
          { xtype: 'textfield', cls: 'transparent', name: 'variant', hidden: true }, 
          { xtype: 'textfield', cls: 'transparent', name:'variant_name', disabled: true, hidden: true }
        ]
      },
      { xtype: 'container',  
        layout: { type: 'vbox' },
        items: [
          { xtype: 'combobox', name: 'video', cls: 'transparent', store: filelist, displayField: 'location',
            valueField: 'id', editable: true, queryMode: 'local',
            width: 150, minChars: 10,enableKeyEvents: true,
            listeners: {
              'expand': function (field, e) {
                console.log('*updatelist*')
                if (field.getValue() != null && field.getValue().length > 2) {
                  reload_files(entryid, field.getValue(), false, false, 'A')
                }
                if (field.getValue() == null || field.getValue().length == 0) {
                  reload_files(entryid, '', false, false, '')
                }
              },
              specialkey: function (field, e) {
                if (e.getKey() == e.ENTER) {
                  console.log('*updatelist*')
                  /* search video, update filelist store */
                  console.log(entryid);
                  console.log(field);
                  console.log(field.getRawValue() + ' - ' + field.getValue());
                  if (field.getValue() != null && field.getValue().length > 2) {
                    reload_files(entryid, field.getValue(), false, false, 'A')
                  }
                  if (field.getValue() == null || field.getValue().length == 0) {
                    reload_files(entryid, '', false, false, '')
                  }
                }
              },
              'select': function (combo, record, index) {
                if (combo.getValue() != '') {
                  Ext.getCmp(name).query('component[name="variant"]')[0].setValue(combo.getValue());
                  var data = filelist.findRecord('id', combo.getValue()).data;
                  Ext.getCmp(name).query('component[name="variant_name"]')[0].setValue(data.location); 
                  Ext.getCmp(name).query('component[name="variantpreview"]')[0].update('<div class="videofancybox" data-ratio="0.8" class="usage" style="width:120px; cursor: zoom-in;"><video class=' + dictcode + ' width="120px" poster="https://www.dictio.info/thumb/video' + dictcode + '/' + data.location + '" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/' + data.location + '"></source></video></div>')
                  Ext.getCmp(name).query('component[name="variantpreview"]')[0].setWidth(120);
                }
              },
            },
            listConfig: {
              getInnerTpl: function () {
                return '<div cursor: hand;"><video width="120px" poster="https://www.dictio.info/thumb/video' + dictcode + '/{location}" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/{location}"></source></video>{location}</div>';

              }
            }
          }, 
          { xtype: 'textfield', name: 'variant_desc', fieldLabel: locale[lang].description, labelWidth: 40, width: 150 }, 
          { xtype: 'textfield', name: 'variant_sw', cls: 'transparent', fieldLabel: locale[lang].sw, labelWidth: 40, width: 70 }
        ]
      },
      { xtype: 'button', icon: '/editor/delete.png', cls: 'del',
        handler: function () {
          Ext.getCmp(name).destroy();
        }
      }
    ]
  });
  return text;
}

// náhledy videí (gramatika, stylistika, výklad, příklady)
function create_text_video(idstart, entryid, label, show_copy, video_type) {
  if (show_copy == undefined || show_copy == true) {
    var copybutton = create_copy_button(idstart);
  } else {
    var copybutton = null;
  }
  var x_video_type = 'sign_front';
  if (video_type == 'G') x_video_type = 'sign_grammar';
  if (video_type == 'S') x_video_type = 'sign_style';
  if (video_type == 'D') x_video_type = 'sign_definition';
  if (video_type == 'K') x_video_type = 'sign_usage_example';

  // Podmínky pro nastavení velikosti panelu podle typu videa Deafult pro G a S
  var panelWidth = 150;
  var panelHeight = 125;
  var videoLabel = locale[lang].description;
  
  if (video_type == 'D') {
    panelWidth = 240;
    panelHeight = 180;
    videoLabel = locale[lang].definice;
  } else if (video_type == 'K') {
    panelWidth = 200;
    panelHeight = 150;
    videoLabel = locale[lang].video;
  }
  
  var text = Ext.create('Ext.container.Container', 
  { layout: { type: 'hbox' },
    cls: 'video-text',
    name: 'text_video',
    width: 565,
    items: [
      { xtype: 'label', text: videoLabel, width: 100, cls: 'video-label'}, 
      { xtype: 'panel', id: idstart +'_videoprev', name: 'vyznampreviews', cls: 'vyznam-prev', height: panelHeight, width: panelWidth }, 
      {
        xtype: 'container',
        layout: { type: 'vbox' },
        items: [
          { xtype: 'combobox',
          name: idstart + '_video',
          store: filelist,
          displayField: 'location',
          valueField: 'id',
          editable: true,
          queryMode: 'local',
          cls: 'vyznam-select transparent',
          width: 160,
          emptyText: locale[lang].search_video,
          minChars: 10,
          enableKeyEvents: true,
          listeners: {
            specialkey: function (field, e) {
             if (e.getKey() == e.ENTER) {
              console.log('*updatelist*')
              /* search video, update filelist store */
              if (entryid == undefined) { var eid = g_entryid;} 
              else {var eid = entryid; }
              console.log('eid' + eid);
              console.log(field);
              console.log(field.getRawValue() + ' - ' + field.getValue());
              if (field.getValue() != null && field.getValue().length > 2) {
                reload_files(eid, field.getValue(), false, false, video_type)
              }
              if (field.getValue() == null || field.getValue().length == 0) {
                reload_files(eid, '', false, false, video_type)
              }
             }
            },
            'expand': function (field, e) {
              console.log('*updatelist expand*')
              if (entryid == undefined) {
                var eid = g_entryid;
              } else {
                var eid = entryid;
              }
              console.log('eid' + eid);
              console.log(field);
              console.log(field.getRawValue() + ' - ' + field.getValue());
              console.log(video_type)
              if (field.getValue() != null && field.getValue().length > 2) {
                reload_files(eid, field.getValue(), false, false, video_type)
              }
              if (field.getValue() == null || field.getValue().length == 0) {
                reload_files(eid, '', false, false, video_type)
              }
            },
            'keyup': function (field, e) {
               //clearTimeout(typingTimer);
               //console.log(e)
            },
            'select': function (combo, record, index) {
              if (combo.getValue() != '') {
                var data = filelist.findRecord('id', combo.getValue()).data;
                Ext.getCmp('tabForm').query('component[name="' + idstart + '_text"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="' + idstart + '_text"]')[0].getValue() + ' [media_id=' + combo.getValue() + ']');                
                Ext.getCmp('tabForm').query('component[id="' + idstart + '_videoprev"]')[0].update('<div id="flowvideo'+data.id+'" data-width="'+panelWidth+'" data-ratio="0.8" style="width:'+panelWidth+'; background:#777) no-repeat; background-size: '+panelWidth+'px '+panelHeight+'px"><video poster="https://www.dictio.info/thumb/video'+dictcode+'/'+data.location+'" width="'+panelWidth+'" loop="loop" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video'+dictcode+'/'+data.location+'"></source></video></div>');
              }  
            },
         },
         listConfig: {
          tpl: new Ext.XTemplate(
            '<ul class="x-list-plain">',
            '<tpl for=".">',
            '<tpl if="type == \'' + x_video_type + '\'">',
            '<li role="option" unselectable="on" class="x-boundlist-item">',
            '<div cursor: hand;"><video width="120px" poster="https://www.dictio.info/thumb/video' + dictcode + '/{location}" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/{location}"></source></video>{location}</div>',
            '</li>',
            '</tpl>',
            '</tpl>',
            '</ul>'
          )
         }
          },
          { xtype: 'textarea', id: idstart + '_text', name: idstart + '_text', cls: 'vyznam-text transparent', width: 160, height: 25}
        ]
      }
    ]
  });
  return text;
}

function refresh_relations(parentid, set_rel) {
  window.setTimeout(function () {
    console.log('refresh timeout');
    Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function (item) { item.show() });
    Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.hide() });
  }, 90 * 1000);

  var trset = Ext.getCmp(parentid).query('component[name="rellinkset"]');
  for (var j = 0; j < trset.length; j++) {
    //Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function(item) {item.hide()});
    Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.show() });
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

  Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function (item) { item.show() });
  Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.hide() });
}

function get_selected_dict() {
  cookie = Ext.util.Cookies.get('dictio_pref')
  selected = new Array();
  if (cookie != undefined) {
    cook_ar = cookie.split(';');
    cook_ar.forEach(function (el) {
      if (el.startsWith('dict-') && el.endsWith('=true')) {
        var selcode = el.substring(5, el.indexOf('='))
        selected.push(selcode);
      }
    });
  }
  return selected;
}

function load_link_relations(target, combo, name, parentid, set_rel) {
  Ext.Ajax.request({
    url: '/' + target + '/getrelations',
    timeout: 30000,
    params: {
      meaning_id: combo.getValue(),
      type: set_rel
    },
    method: 'get',
    failure: function () {
      console.log('get relations fail');
      //waitBoxRels.hide();
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function (item) { item.show() });
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.hide() });
    },
    success: function (response) {
      //waitBoxRels.hide();
      //Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function(item) {item.show()});
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.hide() });
      var trset = Ext.getCmp(name).up().query('component[name="rellinkset"]');
      var trset_ar = new Array();
      var selected_dicts = get_selected_dict();
      console.log(selected_dicts)
      for (var j = 0; j < trset.length; j++) {
        if (trset[j].query('component[name="rellink"]')[0].getValue() != null && trset[j].query('component[name="rellink"]')[0].getValue() != "" && trset[j].query('component[name="type"]')[0].getValue() != "") {
          var rellink = trset[j].query('component[name="rellink"]')[0].getValue();
          var reltype = trset[j].query('component[name="type"]')[0].getValue();
          var reltar = dictcode;
          if (reltype.startsWith('translation_')) {
            reltar = reltype.split('_')[1];
            reltype = 'translation';
          }
          trset_ar.push(reltype + rellink + reltar);
        }
      }
      console.log(trset_ar)
      var linkrels = JSON.parse(response.responseText);
      Ext.each(linkrels, function (relitem) {
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
        if ((!(relitem.target == dictcode && relitem.meaning_id.startsWith(entryid + '-'))) && (trset_ar.indexOf(relitem.type + relitem.title + relitem.target) == -1) && (trset_ar.indexOf(relitem.type + relitem.meaning_id + relitem.target) == -1) && selected_dicts.includes(relitem.target)) {
          //add
          var newrel = create_vyznam_links(parentid);
          console.log(newrel);
          console.log('length=' + Ext.getCmp(parentid).items.length);
          Ext.getCmp(parentid).insert(Ext.getCmp(parentid).items.length - 3, newrel);
          newrel.query('component[name="type"]')[0].setValue(newtype);
          if (relitem.title != '') {
            newrel.query('component[name="rellink"]')[0].setValue(relitem.title);
          } else {
            newrel.query('component[name="rellink"]')[0].setValue(relitem.meaning_id.split('-')[0]);
          }
          newrel.query('component[name="vztahtitle"]')[0].update(relitem.meaning_id);
          var inner = newrel.query('component[name="vztahtitle"]')[0].id + '-innerCt';
          if (inner != '' && document.getElementById(inner) != null) {
            document.getElementById(inner).classList.add('redtext');
          }
        }
      });
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relsadd]'), function (item) { item.show() });
      Ext.Array.each(Ext.getCmp('tabForm').query('[name=relswait]'), function (item) { item.hide() });
    }
  });
}

// překlady vazby
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

// překlady v příkladech
function create_priklad_links(parentid) {
  var name = 'exrellink' + Ext.id();

  var transset = Ext.create('Ext.container.Container', { 
    border: false,
    id: name,
    cls: 'rellinkset',
    name: 'exrellinkset',
    layout: { type: 'hbox' },
    items: [
      { xtype: 'combobox', name: 'type', queryMode: 'local', displayField: 'text', valueField: 'value', store: extypeStore, forceSelection: true, autoSelect: true, editable: false, width: 110, allowBlank: true }, 
      { xtype: 'combobox', name: 'rellink', store: relationlist, displayField: 'title', valueField: 'id', editable: true, queryMode: 'local', width: 220,
      listeners: {
        'blur': function (combo) {
          if ((!(Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_'))) && combo.getValue().startsWith(entryid + '-')) {
            Ext.Msg.alert('', locale[lang]['warn_same_entry']);
          }
        },
        'select': function (combo, record, index) {
          if (combo.getValue() != '') {
            console.log(combo.getValue())
            combo.setRawValue(combo.getValue())
          }
        },
        specialkey: function (field, e) {
          if (e.getKey() == e.ENTER) {
            if (Ext.getCmp(name).query('component[name="type"]')[0].getValue().startsWith('translation_')) {
              var reltar = Ext.getCmp(name).query('component[name="type"]')[0].getValue().split('_')[1];
              reload_rel(field.getValue(), field, reltar);
            } else {
              reload_rel(field.getValue(), field, 'cs');
            }
          }
        }
      },
      tpl: Ext.create('Ext.XTemplate', '<tpl for="."><div class="x-boundlist-item"><b>{title}: {number}:</b> <i>{def}</i><tpl if="loc!=\'\'"><br/><img src="https://www.dictio.info/thumb/video{target}/{loc}" width="120" height="96"/></tpl></div></tpl>'),
    },
    { xtype: 'button', icon: '/editor/delete.png', cls: 'del',
      handler: function () 
        { Ext.getCmp(name).destroy(); }
      }
    ]
  });
  return transset;
}

// příklady užití
function create_priklad(parentid, entryid, add_copy, meaning_id, saved_usage_id) {
  if (ar_priklady[meaning_id] == undefined) {
    ar_priklady[meaning_id] = 0;
  }
  let usage_id;
  if (saved_usage_id && saved_usage_id != '') {
    usage_id = saved_usage_id;
  } else {
    usage_id = meaning_id + '_us' + ar_priklady[meaning_id];
  }
  var name = 'prikladuziti_' + Ext.id();
  var priklad = Ext.create('Ext.form.FieldSet', {
    fieldDefaults: {
      labelAlign: 'right'
    },
    frame: true,
    id: name,
    name: 'usageset',
    layout: { type: 'hbox' },
    items:
      [
        {
          xtype: 'container',
          layout: { type: 'vbox' },
          items:
            [{
              xtype: 'container',
              layout: { type: 'hbox' },
              items: [
                { xtype: 'textfield', disabled: true, name: 'usage_id', labelWidth: 50, fieldLabel: 'ID', value: usage_id },
                { xtype: 'container', name: 'prazdny', width: 347, fieldLabel: '' }
                , create_stav(),
                {
                  xtype: 'button', icon: '/editor/delete.png', cls: 'del',
                  handler: function () { Ext.getCmp(name).destroy(); }
                }
              ]
            },
            {
              xtype: 'container',
              layout: { type: 'hbox' },
              items: [create_text_video(name + 'text', entryid, 'text', false, 'K'), create_comment_button(name, usage_id)]
            }, 
            {
              xtype: 'container', // typ příkladu, pokud běžné spojení pak přidání ekvivalentů         
              layout: { type: 'hbox' },
              items: [
                { xtype: 'container', name: 'prazdny', width: 106, fieldLabel: '' },
                { xtype: 'radiofield', style: { width: '100px' }, name: name + 'usage_type', boxLabel: locale[lang].usage_veta, inputValue: 'sentence' },
                { xtype: 'radiofield', style: { width: '130px' }, name: name + 'usage_type', boxLabel: locale[lang].usage_spojeni, inputValue: 'colloc', 
                  handler: function (ctl, val) {
                    if (val) { ctl.up().query('[name=exrelbox]')[0].show(); }
                  }
                },
                { xtype: 'radiofield', style: { width: '100px' }, name: name + 'usage_type', boxLabel: locale[lang].usage_gram, inputValue: 'gram', 
                  handler: function (ctl, val) {
                    if (val) { ctl.up().query('[name=exrelbox]')[0].show(); }
                  }
                },
                { xtype: 'container', hidden: true, id: name + '_rellinks', name: 'exrelbox', cls: 'equiv',
                  items: [{
                    xtype: 'button', icon: '/editor/add.png', cls: 'add', text: locale[lang].new_translation,
                    handler: function () {
                      var transset = create_priklad_links(name + '_rellinks');
                      Ext.getCmp(name + '_rellinks').insert(Ext.getCmp(name + '_rellinks').items.length - 1, transset);
                      track_change();
                    }
                  }]
                }
              ]
            },
            create_copyrightSW(name + 'copyright', false)
            ]
        }, {
          xtype: 'container',
          layout: {
            type: 'vbox'
          },
          items: []
        }
      ]
  });
  if (add_copy) {
    ar_priklady[meaning_id]++;
    priklad.query('[name=copy_copy]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
    priklad.query('[name=copy_zdroj]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
    priklad.query('[name=copy_autor]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
  }

  return priklad;
}

// signwriting box
function create_sw(entryid, add_copy) {
  counter_sw += 1;
  var name = 'sw_' + Ext.id();
  var sw = Ext.create('Ext.container.Container', {
    layout: {
      type: 'hbox'
    },
    id: name,
    name: 'switem',
    border: 1,
    items: [{
      xtype: 'container',
      layout: { type: 'vbox' },
      items: [
        {
          xtype: 'container',
          layout: { type: 'hbox'},
          items: [
            {
              xtype: 'textfield',
              name: 'swid',
              hidden: true
            }, {
              xtype: 'displayfield',
              value: String.fromCharCode(64 + counter_sw),
              cls: 'sw-label',
            }, {
              name: 'swimg',
              xtype: 'box',
              cls: 'sw-img',
              width: 200,
            }, {
              xtype: 'container',
              layout: {
                type: 'vbox'
              },
              items: [{
                xtype: 'container',
                layout: {
                  type: 'hbox'
                },
                items: [
                  { xtype: 'button',
                    text: locale[lang].change,
                    cls: 'sw-change',
                    width: 100,
                    handler: function () 
                      { $.fancybox.open(
                          { 'src': '/editor/swe/test2.html?lang=' + lang }, 
                          { type: 'iframe',
                            'autoScale': false,
                            'transitionIn': 'elastic',
                            'transitionOut': 'elastic',
                            'titlePosition': 'inside',
                            'hideOnContentClick': true,
                            'speedIn': 100,
                            'speedOut': 100,
                            'changeSpeed': 100,
                            'centerOnScroll': false,
                            iframe: { css: { height: '850px' } },
                            autoSize: false,
                            padding: 0,
                            closeClick: true,
                            afterLoad: function (instance, current) 
                              { $('.fancybox-iframe')[0].contentWindow.onload(prepare_swe(name)); },
                            afterClose: function () 
                              { console.log(name)
                                console.log($('#' + name).attr('swe'))
                                var swe = $('#' + name).attr('swe');
                                Ext.getCmp(name).query('component[name="swdata"]')[0].setValue(swe);
                                Ext.Ajax.request({
                                  url: '/' + dictcode + '/getfsw',
                                  params: { sw: swe },
                                  method: 'get',
                                  success: function (response) {
                                    Ext.getCmp(name).query('component[name="fsw"]')[0].setValue(response.responseText);
                                    Ext.getCmp(name).query('component[name="swimg"]')[0].el.setHTML('<img src="https://sign.dictio.info/fsw/sign/png/' + response.responseText + '-CG_white_"/>');
                                  }
                                });
                              }
                          }
                        );
                      },                   
                  },
                  { xtype:'tbfill', width:230},
                  { xtype: 'button', icon: '/editor/delete.png', cls: 'del',
                    handler: function () {
                      Ext.getCmp(name).destroy();
                    }
                  }
                ]
              }, {
                xtype: 'textfield',
                name: 'swdata',
                hidden: true
              }, {
                xtype: 'combobox',
                name: 'misto',
                queryMode: 'local',
                displayField: 'text',
                valueField: 'value',
                store: artikStore,
                forceSelection: true,
                autoSelect: true,
                editable: false,
                allowBlank: true,
                fieldLabel: locale[lang].artikulace,
                multiSelect: true,
              }, {
                xtype: 'button',
                text: 'FSW',
                handler: function () {
                  var field = this.up('[name=switem]').query('[name=fsw]')[0];
                  Ext.MessageBox.prompt('FSW', 'Zadejte FSW', function (btn, text) {
                    if (btn == 'ok' && text != '') {
                      field.setValue(text);
                      Ext.Ajax.request({
                        url: '/' + dictcode + '/fromfsw',
                        params: {
                          fsw: text,
                          width: 600,
                        },
                        method: 'get',
                        success: function (response) {
                          console.log(field)
                          console.log(response.responseText)
                          var swparent = field.up('[name=switem]')
                          swparent.query('[name=swdata]')[0].setValue(response.responseText);
                          if (response.responseText != '') {
                            swparent.query('[name=swimg]')[0].el.setHTML('<img src="https://www.dictio.info/sw/signwriting.png?generator[sw]=' + response.responseText + '&generator[align]=top_left&generator[set]=sw10"/>');
                          } else {
                            swparent.query('[name=swimg]')[0].el.setHTML('');
                          }
                        }
                      });
                    }
                  }, this, false, field.getValue());
                }
              }, {
                xtype: 'textfield',
                name: 'fsw',
                width: 330,
                fieldLabel: '',
                disabled: true,
              }, {
                xtype: 'radiofield',
                name: 'primary_sw',
                boxLabel: locale[lang].primarysw,
                inputValue: 'primary'
              }]
            }
          ]
        }, create_copyrightSW(name, false)
      ]
    }]
  });
  if (add_copy) {
    sw.query('[name=copy_copy]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
    sw.query('[name=copy_zdroj]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
    sw.query('[name=copy_autor]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
  }
  return sw;
}

// části spojení, derivátu, kompozita
function create_colloc(entryid) {
  counter_colloc += 1;
  var name = 'colloc_' + Ext.id();
  var sw = Ext.create('Ext.container.Container', {
    layout: { type: 'hbox' },
    width: 200,
    style: {float: 'left'},
    id: name,
    name: 'colitem',
    items: [
      { xtype: 'displayfield',
        value: counter_colloc + ': ',
        cls: 'col-label',
      }, 
      { xtype: 'combobox',
        name: 'colid',
        store: linklist, displayField: 'title',
        valueField: 'id',
        editable: true,
        queryMode: 'local',
        emptyText: locale[lang].searchrel,
        width: 160,
        listeners: {
          'select': function (combo, record, index) {
            console.log('select')
            if (combo.getValue() != '') {
              console.log(combo.getValue())
              combo.setRawValue(combo.getValue())
            }
          },
          specialkey: function (field, e) {
            console.log('key')
            console.log(e)
            if (e.getKey() == e.ENTER) {
              reload_link(field.getValue(), field);
            }
          }
        },
        listConfig: {
          getInnerTpl: function () {
            return '<div cursor: hand;"><video width="120px" poster="https://www.dictio.info/thumb/video' + dictcode + '/{loc}" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video' + dictcode + '/{loc}"></source></video>{id}</div>';
          }
        }
      }, 
      { xtype: 'button', icon: '/editor/delete.png', cls: 'del',
        handler: function () {
          Ext.getCmp(name).destroy();
        }
      }
    ]
  });
  return sw;
}

function click_player_thumb(e, s) {
  console.log(e.target)
  console.log(e.target.parentNode.id)
  console.log(e.target.parentNode)
  var vid = e.target.parentNode.id;
  console.log(e.target)
  console.log(s)
}

// čelní (boční) video
function create_video(entryid, selectnew, vidid) {
  counter_video += 1;
  var name = 'video_'+Ext.id();
  var sw = Ext.create('Ext.container.Container', {
    layout: { type: 'hbox' },
    width: 505,
    cls: 'celnibocni',   
    id: name,
    name: 'viditem',
    items: [
      { xtype: 'container',
        layout: { type: 'hbox' },
        items: [
          { name: 'videoimg', xtype: 'box', width: 300, height: 225,
            listeners: {
              'render': function(c) {
                c.getEl().on('click', click_player_thumb);
                c.getEl().on('click', function(e) {
                  c.getEl().un('click', click_player_thumb);
                });
              },
            }
          },
          { xtype: 'container', layout: {type: 'vbox'},
            items: [
              { xtype: 'container', layout: {type: 'hbox'},
                items: [              
                  { xtype:'tbfill', width:18},
                  create_stav(),
                  { xtype: 'button', icon: '/editor/delete.png', cls: 'del',
                    handler: function() { Ext.getCmp(name).destroy();}
                  }
                ]
              },
              create_comment_button(name, 'video' + vidid),
              { xtype:'tbfill', height:50},
              { fieldLabel: locale[lang].video, xtype: 'textfield', name: 'mediaid', hidden: true},
              { xtype: 'combobox',
                name: 'selectvideo',
                store: filelist,
                displayField: 'location',
                valueField: 'id',
                editable: true,
                queryMode: 'local',
                width: 200,
                typeAhead: false,
                triggerAction: 'all',
                disableKeyFilter: true,
                autoSelect: false,
                minChars: 100,
                hidden: true,
                labelWidth: 50,
                fieldLabel: locale[lang].selectvideo,
                listeners: {
                  specialkey: function(field, e) {
                    if (e.getKey() == e.ENTER) {
                      console.log('*updatelist*')
                      /* search video, update filelist store */
                      console.log(field);
                      console.log(field.getRawValue() + ' - ' +field.getValue());
                      if (field.getValue().length > 2) {
                        reload_files(entryid, field.getValue(), false, false, 'AB');
                      }
                    }
                  },
                  'select': function(combo, record, index) {
                    if (combo.getValue() != '') {
                      var data = filelist.findRecord('id', combo.getValue()).data;
                      var cont = combo.up('component[name=viditem]');
                      console.log(data);
                      cont.query('component[name="mediaid"]')[0].setValue(data.id);
                      cont.query('component[name="vidid"]')[0].setValue(data.location);
                      cont.query('component[name="original"]')[0].setValue(data.original);
                      cont.query('component[name="copy_admin"]')[0].setValue(data.admin);
                      cont.query('component[name="copy_autor"]')[0].setValue(data.author);
                      cont.query('component[name="copy_copy"]')[0].setValue(data.copyright);
                      cont.query('component[name="copy_zdroj"]')[0].setValue(data.source);
                      change_stav(cont.query('component[name="stavcont"]')[0], data.status);
                      if (data.type == 'sign_front') {
                        cont.query('component[name="type"]')[0].setValue('front');
                      }
                      if (data.type == 'sign_side') {
                        cont.query('component[name="type"]')[0].setValue('side');
                      }
                      cont.query('component[name="videoimg"]')[0].el.setHTML('<div id="flowvideo'+data.id+'" data-width="300" data-ratio="0.8" style="width:300px; background:#777) no-repeat; background-size: 300px 225px"><video poster="https://www.dictio.info/thumb/video'+dictcode+'/'+data.location+'" width="300px" loop="loop" onmouseover="this.play()" onmouseout="this.pause()"><source type="video/mp4" src="https://files.dictio.info/video'+dictcode+'/'+data.location+'"></source></video></div>');
                     // activate_player('#flowvideo'+data.id);
                    }
                  },
                },
                listConfig: {
                  getInnerTpl: function() {
                    return '<div><img width="140" src="https://www.dictio.info/thumb/video'+dictcode+'/{location}">{location}</div>';
                  }
                }
              },
              { labelWidth: 50, width: 200, cls: 'transparent', fieldLabel: locale[lang].video, xtype: 'textfield', name: 'vidid'},
              { labelWidth: 50, width: 200, cls: 'transparent', xtype: 'combobox', name: 'type', queryMode: 'local', displayField: 'text', valueField: 'value', store: videotypeStore, forceSelection: true, autoSelect: true, editable: false, allowBlank: true, fieldLabel: locale[lang].type},
              { labelWidth: 50, width: 200, xtype: 'textfield', disabled: true, name: 'original', fieldLabel: locale[lang].originalname},
              { labelWidth: 50, xtype: 'radiogroup', fieldLabel: locale[lang].dominance,
                layout: {type: 'hbox'},
                items: 
                  [
                    { boxLabel: locale[lang].lr, inputValue: 'lr', name: name+'orient'},
                    { boxLabel: locale[lang].pr, inputValue: 'pr', name: name+'orient', checked: true}
                  ]
              }]
          }
        ]
      },
      create_copyrightM(name, false) 
    ]
  });
  
  if (selectnew) {
    sw.query('component[name=selectvideo]')[0].hidden = false;
    sw.query('component[name=commentbutton]')[0].hidden = true;
  }  
  return sw;
}

// videa na stránce připojené soubory
function create_media(entryid, upload, vidid) {
  var name = 'media_' + Ext.id();
  var sw = Ext.create('Ext.container.Container', {
    layout: { type: 'vbox' },
    width: 650,
    id: name,
    cls: 'celnibocni',
    name: 'mediaitem',
    items: [
      { xtype: 'container',
        layout: { type: 'hbox' },
        items: [
          { name: 'mediaimg', xtype: 'box', width: 200, height: 160 }, 
          { xtype: 'container',
            name: 'mediaiteminfo',
            layout: { type: 'vbox' }, 
            items: [              
              { xtype: 'container',
                layout: { type: 'hbox' },
                items: [
                  { xtype: 'tbfill', width: 265 },
                  create_stav(), 
                  { xtype: 'button',
                    icon: '/editor/delete.png',
                    cls: 'del',
                    handler: function () {
                      Ext.Ajax.request({
                        url: '/' + dictcode + '/remove_video',
                        params: {
                          entry_id: entryid,
                          media_id: sw.query('[name=mediaid]')[0].getValue()
                        },
                        method: 'post',
                        success: function (response) {
                          Ext.getCmp(name).destroy();
                        }
                      });
                    }
                  },
                ]
              },              
              { fieldLabel: locale[lang].video, xtype: 'textfield', name: 'mediaid', inputId: name + 'mediaid', hidden: true }, 
              { xtype: 'filefield', text: 'vybrat soubor', name: 'filebutton', inputId: name + 'filebutton', hidden: true }, 
              { xtype: 'button', text: locale[lang].upload, name: 'uploadbutton', hidden: true,
                handler: function () 
                { var mediaitem = this.up('[name=mediaitem]');
                  var metadata = 
                  { 'id_meta_author': mediaitem.query('component[name="copy_autor"]')[0].getValue(),
                    'id_meta_copyright': mediaitem.query('component[name="copy_copy"]')[0].getValue(),
                    'id_meta_source': mediaitem.query('component[name="copy_zdroj"]')[0].getValue(),
                    'admin_comment': mediaitem.query('component[name="copy_admin"]')[0].getValue(),
                    'status': mediaitem.query('component[name="stav"]')[0].getValue(),
                    'type': mediaitem.query('component[name="type"]')[0].getValue(),
                    'location': mediaitem.query('component[name="vidid"]')[0].getValue(),
                    'orient': mediaitem.query('component[name="' + mediaitem.id + 'orient"]')[0].getGroupValue()
                  };
                  console.log(metadata)
                  var waitBox = Ext.MessageBox.wait('Upload');
                  console.log(mediaitem.query('component[name="filebutton"]'))
                  var filedata = mediaitem.query('component[name="filebutton"]')[0].fileInputEl.dom.files[0];
                  var formData = new FormData();
                  formData.append("filedata", filedata);
                  formData.append('entryid', entryid);
                  formData.append('metadata', JSON.stringify(metadata));
                  console.log(formData)
                  xhr = new XMLHttpRequest();
                  xhr.open('POST', '/' + dictcode + '/upload', true);
                  xhr.onload = function () {
                    if (xhr.readyState == 4 && xhr.status === 200) {
                      Ext.suspendLayouts();
                      while (Ext.getCmp('mediabox').child('[name=mediaitem]')) {
                        Ext.getCmp('mediabox').remove(Ext.getCmp('mediabox').child('[name=mediaitem]'))
                      }
                      reload_files(entryid, null, true);
                      Ext.resumeLayouts(true);
                      Ext.Msg.alert('Stav', JSON.parse(xhr.responseText).message);
                      Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                    } else {
                      if (xhr.status === 413) {
                        Ext.Msg.alert('Stav', 'Příliš velký soubor');
                        Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                      } else {
                        Ext.Msg.alert('Stav', JSON.parse(xhr.responseText).message);
                        Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                      }
                      //error
                    }
                  };
                  xhr.send(formData);
                }
              },              
              { fieldLabel: locale[lang].video, xtype: 'textfield', width: 350, labelWidth: 100, name: 'vidid', align: 'right', cls: 'transparent'}, 
              { xtype: 'combobox', name: 'type', width: 350, labelWidth: 100, cls: 'transparent', queryMode: 'local', displayField: 'text', valueField: 'value', store: mediatypeStore, forceSelection: true, autoSelect: true, editable: false, allowBlank: true, fieldLabel: locale[lang].type}, 
              { xtype: 'textfield', width: 350, labelWidth: 100, disabled: true, fieldLabel: locale[lang].originalname, name: 'original'}, 
              { xtype: 'textfield', width: 350, labelWidth: 100, disabled: true, fieldLabel: 'ID', name: 'videoid'}, 
              { xtype: 'radiogroup', width: 350, labelWidth: 100, fieldLabel: locale[lang].dominance,
                layout: { type: 'hbox' },
                items: [
                  { boxLabel: locale[lang].lr, inputValue: 'lr', name: name + 'orient'}, 
                  { boxLabel: locale[lang].pr, inputValue: 'pr', name: name + 'orient', checked: true}
                ]
              }
            ]
          }, 
          { xtype: 'container', name: 'prazdny', width: 300, fieldLabel: ''},
          create_comment_button(name, 'video' + vidid)
        ]
      }, create_copyrightM(name, false)
    ]
  });
  if (upload) {
    sw.query('component[name=uploadbutton]')[0].hidden = false;
    sw.query('component[name=filebutton]')[0].hidden = false;
    sw.query('[name=copy_copy]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
    sw.query('[name=copy_zdroj]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
    sw.query('[name=copy_autor]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
  }
  return sw;
}

// významy 
function create_vyznam(entryid, add_copy, meaning_id) {
  var meanskupina = '';
  if (meaning_id == undefined) {
    max_meaning += 1;
    var meaning_id = entryid + '-' + max_meaning;
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

  var name = 'vyznam_' + Ext.id();
  var sense = Ext.create('Ext.form.FieldSet', {
    layout: { type: 'vbox' },
    id: name,
    name: 'vyznam',
    style: { borderColor: '#03c9a9', borderBottomStyle: 'dashed', borderBottomWidth: '2px' },
    frame: true,
    items: [
      { xtype: 'container',  // záhlaví významu 
        name: 'vyznam_topmeta',
        height: 30,
        width: 1640,
        cls: 'vyznam-zahlavi',
        layout: { type: 'hbox' },
        items: [
          { xtype: 'textfield', name: 'meaning_nr', allowBlank: false, labelWidth: 50, width: 100, fieldLabel: locale[lang].order, cls: 'vyznamNum'},                  
          { xtype: 'textfield', disabled: true, name: 'meaning_id', labelWidth: 50, fieldLabel: 'ID', value: meaning_id, cls: 'meaning_id'},             
          { xtype: 'container', name: 'prazdny', width: 70, fieldLabel: ''}, 
          { fieldLabel: locale[lang].workgroup, name: 'pracskupina', 
            cls: 'transparent', xtype: 'combobox', editable: false, queryMode: 'local', displayField: 'text', valueField: 'value', store: pracskupinaStore, allowBlank: true, value: meanskupina},
          { xtype: 'tbfill', width: 300},
          { xtype: 'button', icon: '/editor/delete.png', cls: 'del',
            handler: function () {
              Ext.getCmp(name).destroy();
            }
          }
        ]
      },
      { xtype: 'tbfill', height: 5},     
      { xtype: 'container',  // dva sloupce, vlevo definice, příklady, vpravo překlady
        layout: { type: 'hbox' },
        items: [
          { xtype: 'container',  // levý sloupec defince, atd
            layout: { type: 'vbox' },
            width: 970,
            flex: 1,
            name: 'vyznam_topcont',
            items: [              
              { xtype: 'container',
                layout: { type: 'hbox' },
                items: [
                  { xtype: 'combobox', 
                    fieldLabel: locale[lang].obor, 
                    name: 'obor', 
                    queryMode: 'local', displayField: 'text', labelWidth: 100, valueField: 'value', store: katStore, forceSelection: true, autoSelect: true, editable: false, allowBlank: true, multiSelect: true,
                  },
                  { xtype: 'combobox',
                    name: 'region',
                    fieldLabel: locale[lang].oblastuziti, // oblast užití
                    labelWidth: 275, queryMode: 'local', displayField: 'text', valueField: 'value', store: regStore, forceSelection: true, autoSelect: true, editable: false, multiSelect: true,
                  },
                  { xtype: 'container', name: 'vyznammeta', 
                    layout: { type: 'vbox'},
                    items: [
                      create_stav(),
                    ]
                  }            
                ]
              }, 
              { xtype: 'container', // box s náhledem videa definice
                layout: { type: 'hbox' },
                items: [ 
                  create_text_video(name + '_text', entryid, 'text', false, 'D'), 
                  create_comment_button(name, 'vyznam' + meaning_id)
                ]
              },
              create_copyrightSW(name, false), // copyright pro definici
              { xtype: 'fieldset',    // příklady užití
                collapsible: true,
                title: locale[lang].usages,                                
                id: name + '_uziti',
                name: 'usagebox',
                cls: 'priklady',
                layout: { type: 'vbox' },
                items: [
                  { xtype: 'button',
                    icon: '/editor/add.png',
                    cls: 'add',
                    handler: function () {
                      var priklad = create_priklad(name + '_uziti', entryid, true, meaning_id);
                      Ext.getCmp(name + '_uziti').insert(Ext.getCmp(name + '_uziti').items.length - 1, priklad);
                      track_change();
                    }
                  }
                ]
              },              
              
            ] 
          }, 
          { xtype: 'fieldset',    // překlady box užití
            collapsible: true,
            title: locale[lang].relations,   
            cls: 'equiv', 
            items: [
              { xtype: 'container',  // překlady, ekvivalenty
                layout: { type: 'hbox' },
                items: [
                  { xtype: 'fieldcontainer',
                    width: 625,                  
                    id: name + '_rellinks',
                    name: 'relbox',
                    items: [
                      { xtype: 'button', icon: '/editor/add.png', cls: 'add', text: locale[lang].new_translation,
                        name: 'relsadd',
                        handler: function () 
                          { var transset = create_vyznam_links(name + '_rellinks');
                            Ext.getCmp(name + '_rellinks').insert(Ext.getCmp(name + '_rellinks').items.length - 3, transset);
                            track_change();
                          }
                      }, 
                      { xtype: 'button',
                        icon: '/editor/refresh.png',
                        name: 'relsrefresh',
                          handler: function () 
                            { var set_rel = Ext.getCmp('tabForm').query('[name=usersetrel]')[0].getValue()
                              refresh_relations(name + '_rellinks', set_rel);
                            }
                      }, 
                      { name: 'relswait', width: 20, height: 20,
                        xtype: 'image', hidden: true,
                        src: '/editor/wait.gif',
                      }, 
                      { xtype: 'checkbox',
                        boxLabel: locale[lang].translationunknown,
                        name: 'translation_unknown',
                        handler: function () {
                          update_stav();
                        }
                      }, 
                      create_comment_button(name, 'vyznam' + meaning_id + 'vazby')
                    ]
                  }
                ]
              }
            ] // konec přidaného fieldsetu
          }   
        ]
      } 
    ]
  });
  if (add_copy) {
    Ext.getCmp(name + '_copybox').query('[name=copy_copy]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
    Ext.getCmp(name + '_copybox').query('[name=copy_zdroj]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
    Ext.getCmp(name + '_copybox').query('[name=copy_autor]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
    sense.query('[name=meaning_nr]')[0].setValue(max_meaning);
  }

  return sense;
}

function makeDroppable(element, callback) {

  var input = document.createElement('input');
  input.setAttribute('type', 'file');
  input.setAttribute('multiple', true);
  input.setAttribute('disabled', 'disabled');
  input.style.display = 'none';

  input.addEventListener('change', triggerCallback);
  element.appendChild(input);

  element.addEventListener('dragover', function (e) {
    e.preventDefault();
    e.stopPropagation();
    element.classList.add('dragover');
  });

  element.addEventListener('dragleave', function (e) {
    e.preventDefault();
    e.stopPropagation();
    element.classList.remove('dragover');
  });

  element.addEventListener('drop', function (e) {
    e.preventDefault();
    e.stopPropagation();
    element.classList.remove('dragover');
    triggerCallback(e);
  });

  element.addEventListener('click', function () {
    input.value = null;
    input.click();
  });

  function triggerCallback(e) {
    var files;
    if (e.dataTransfer) {
      files = e.dataTransfer.files;
    } else if (e.target) {
      files = e.target.files;
    }
    callback.call(null, files);
  }
}

function callback(files) {
  var waitBox = Ext.MessageBox.wait('Upload');
  console.log(files);
  var filesv = new Array();
  for (var i = 0; i < files.length; i++) {
    console.log(files[i].type)
    if (files[i].type == 'video/mp4' || files[i].type == 'video/x-ms-wmv' || files[i].type == 'video/mpeg') {
      filesv.push(files[i]);
    }
  }
  console.log(filesv)
  if (filesv.length > 0) {
    xhr = new Array(filesv.length);
    for (let j = 0; j < filesv.length; j++) {
      console.log(filesv[j])
      var formData = new FormData();
      formData.append("filedata", filesv[j], filesv[j].name);
      formData.append('entryid', entryid);
      var mtype = '';
      switch (filesv[j].name.charAt(0)) {
        case 'G':
          mtype = 'sign_grammar';
          break;
        case 'S':
          mtype = 'sign_style';
          break;
        case 'K':
          mtype = 'sign_usage_example';
          break;
        case 'D':
          mtype = 'sign_definition';
          break;
        case 'A':
          mtype = 'sign_front';
          break;
        case 'B':
          mtype = 'sign_side';
          break;
      }

      var metadata = {
        'id_meta_author': Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue(),
        'id_meta_copyright': Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue(),
        'id_meta_source': Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue(),
        'admin_comment': '',
        'status': '',
        'type': mtype,
        'location': filesv[j].name,
        'orient': ''
      };
      formData.append('metadata', JSON.stringify(metadata));
      xhr[j] = new XMLHttpRequest();
      xhr[j].open('POST', '/' + dictcode + '/upload', true);
      xhr[j].onerror = function () {
        Ext.Msg.alert('Chyba uploadu');
        Ext.Function.defer(Ext.MessageBox.hide, 3000, Ext.MessageBox);
      }
      xhr[j].onload = function () {
        if (xhr[j].readyState == 4 && xhr[j].status === 200) {
          console.log('Upload Done', xhr[j].responseText);
          var updata = JSON.parse(xhr[j].responseText);
          var mediaid = updata.mediaid;
          Ext.getCmp('tabpanel');
          Ext.Msg.alert('Stav', locale[lang].fileupload + ' ' + updata.filename);
          console.log('upload DONE');
          console.log(filesv[j]);

          //add on media tab
          // check name if already on media tab
          var meds = Ext.getCmp('mediabox').query('[name=mediaitem]');
          var med = null;
          for (var i = 0; i < meds.length; i++) {
            if (meds[i].query('[name=vidid]')[0].getValue() == filesv[j].name) {
              med = meds[i];
            }
          }
          if (med == null) {
            var med = create_media(entryid, false, filesv[j].name);
            Ext.getCmp('mediabox').add(med);
            if (mediaid != undefined && mediaid != "") {
              med.query('component[name="videoid"]')[0].setValue(mediaid);
              med.query('component[name="mediaid"]')[0].setValue(mediaid);
            }
            med.query('component[name="vidid"]')[0].setValue(filesv[j].name);
            med.query('component[name="copy_autor"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
            med.query('component[name="copy_copy"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
            med.query('component[name="copy_zdroj"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
          }

          switch (filesv[j].name.charAt(0)) {
            case 'K':
              med.query('component[name="type"]')[0].setValue('sign_usage_example');
              break;
            case 'D':
              med.query('component[name="type"]')[0].setValue('sign_definition');
              break;
            case 'A':
              med.query('component[name="type"]')[0].setValue('sign_front');
              var vids = Ext.getCmp('videobox').query('component[name="viditem"]');
              var video_is = false;
              for (var i = 0; i < vids.length; i++) {
                if (vids[i].query('component[name="type"]')[0].getValue() == 'front') {
                  if (confirm(filesv[j].name + ': ' + locale[lang].upload_replace_front)) {
                    vids[i].up().remove(vids[i].id);
                  } else {
                    video_is = true;
                  }
                }
              }
              if (!video_is) {
                var vid = create_video(entryid, false, filesv[j].name);
                Ext.getCmp('videobox').insert(Ext.getCmp('videobox').items.length - 1, vid);
                vid.query('component[name="mediaid"]')[0].setValue(med.query('component[name="mediaid"]')[0].getValue());
                vid.query('component[name="vidid"]')[0].setValue(filesv[j].name.replace('.mpeg', '.mp4'));
                vid.query('component[name="type"]')[0].setValue('front');
                vid.query('component[name="copy_autor"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
                vid.query('component[name="copy_copy"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
                vid.query('component[name="copy_zdroj"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
                add_preview_main();
                add_video_fancybox();
              }
              break;
            case 'B':
              med.query('component[name="type"]')[0].setValue('sign_side');
              var vids = Ext.getCmp('videobox').query('component[name="viditem"]');
              var video_is = false;
              for (var i = 0; i < vids.length; i++) {
                if (vids[i].query('component[name="type"]')[0].getValue() == 'side') {
                  if (confirm(filesv[j].name + ': ' + locale[lang].upload_replace_side)) {
                    vids[i].up().remove(vids[i].id);
                  } else {
                    video_is = true;
                  }
                }
              }
              if (!video_is) {
                var vid = create_video(entryid, false, filesv[j].name);
                Ext.getCmp('videobox').insert(Ext.getCmp('videobox').items.length - 1, vid);
                vid.query('component[name="mediaid"]')[0].setValue(med.query('component[name="mediaid"]')[0].getValue());
                vid.query('component[name="vidid"]')[0].setValue(filesv[j].name.replace('.mpeg', '.mp4'));
                vid.query('component[name="type"]')[0].setValue('side');
                vid.query('component[name="copy_autor"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultautor"]')[0].getValue());
                vid.query('component[name="copy_copy"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultcopy"]')[0].getValue());
                vid.query('component[name="copy_zdroj"]')[0].setValue(Ext.getCmp('tabForm').query('component[name="defaultzdroj"]')[0].getValue());
                add_preview_main();
                add_video_fancybox();
              }
              break;
          }
          Ext.Function.defer(Ext.MessageBox.hide, 3000, Ext.MessageBox);
        } else {
          if (xhr[j].status === 413) {
            Ext.Msg.alert('Stav', 'Příliš velký soubor');
          } else {
            Ext.Msg.alert('Stav', JSON.parse(xhr.responseText).message);
          }
        }
      };
      xhr[j].send(formData);
    }
  }
}

// načtení hesla
Ext.onReady(function () {
  //var entryid = 1;
  var sense1 = create_vyznam(entryid);

  var datatab = Ext.create('Ext.form.Panel', {

    title: locale[lang].lemma,
    layout: 'anchor',
    fieldDefaults: { labelAlign: 'right' },
    items: [
      { xtype: 'fieldset',
        title: locale[lang].basicinfo,
        cls: 'techinfo-box',
        id: 'boxlemma',
        collapsible: true,
        layout: { type: 'vbox'},
        items: [
          { xtype: 'container',
            layout: { type: 'hbox' },
            items: [
              { name: 'media_folder_id', hidden: true, xtype: 'textfield'}, 
              { fieldLabel: locale[lang].zverejnovani,
                name: 'completeness',
                width: 350,
                xtype: 'combobox',
                queryMode: 'local',
                displayField: 'text',
                valueField: 'value',
                store: uplnostStore,
                forceSelection: true,
                autoSelect: true,
                editable: false,
                listeners: 
                  { 'change': function (com, val, oldval) 
                    { var user_perm = Ext.getCmp('tabForm').query('[name=userperm]')[0].getValue();
                      if (user_perm.indexOf('admin') == -1 && (val == '2' || val == '100') && oldval != undefined) 
                        { com.setValue(oldval); }
                      update_stav();
                    }
                  }
              }, 
              { fieldLabel: locale[lang].workgroup, name: 'pracskupina', 
                cls: 'transparent',
                xtype: 'combobox', editable: false, queryMode: 'local', displayField: 'text', valueField: 'value', 
                store: pracskupinaStore, forceSelection: true, autoSelect: true, allowBlank: true }, 
              { name: 'autostav', fieldLabel: locale[lang].status, xtype: 'displayfield' }, 
              { xtype: 'button', text: locale[lang].checkstatus,
                handler: function () {
                  update_stav();
                }
              }, 
              { xtype: 'tbfill' }, 
              create_comment_button('boxlemma')
            ]
          }, 
          { xtype: 'container',
            layout: { type: 'hbox' },
            items: [
              { xtype: 'textfield', fieldLabel: locale[lang].admincomment2, width: 350, name: 'admin_comment' }, 
              { xtype: 'displayfield', name: 'usersetrel', labelWidth: 0, width: 0, hidden: true }, 
              { xtype: 'displayfield', name: 'userskupina', fieldLabel: locale[lang].usergroup, labelWidth: 150 }, 
              { xtype: 'displayfield', name: 'userperm', fieldLabel: locale[lang].userperm }, 
              { xtype: 'displayfield', name: 'defaultautor', labelWidth: 200, fieldLabel: locale[lang].defaultauthor }, 
              { xtype: 'displayfield', name: 'defaultcopy', fieldLabel: locale[lang].copyright }, 
              { xtype: 'displayfield', name: 'defaultzdroj', fieldLabel: locale[lang].source }
            ]
          }
        ]
      }, 
      { xtype: 'fieldset', 
        title: locale[lang].formaldesc, 
        id: 'formaldesc', 
        cls: 'formaltop', 
        items: [
          { xtype: 'fieldset',
            title: locale[lang].entrytype,
            id: 'boxcolloc',
            collapsible: true,
            items: [{
              xtype: 'fieldcontainer',
              //fieldLabel: 'typ hesla',
              layout: {
                type: 'hbox'
              },
              items: [{
                xtype: 'radiofield',
                name: 'lemma_type',
                boxLabel: locale[lang].lemma_single,
                inputValue: 'single',
                checked: true,
                handler: function (ctl, val) {
                  if (val) {
                    Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].hide();
                    Ext.getCmp('boxcolloc').query('component[name="swcompos"]')[0].setDisabled(true);
                    Ext.getCmp('gramcont').setDisabled(false);
                  }
                }
              }, {
                xtype: 'radiofield',
                name: 'lemma_type',
                boxLabel: locale[lang].lemma_derivat,
                inputValue: 'derivat',
                handler: function (ctl, val) {
                  if (val) {
                    Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].show();
                    Ext.getCmp('boxcolloc').query('component[name="swcompos"]')[0].setDisabled(false);
                    Ext.getCmp('gramcont').setDisabled(false);
                  }
                }
              }, {
                xtype: 'radiofield',
                name: 'lemma_type',
                boxLabel: locale[lang].lemma_kompozitum,
                inputValue: 'kompozitum',
                handler: function (ctl, val) {
                  if (val) {
                    Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].show();
                    Ext.getCmp('boxcolloc').query('component[name="swcompos"]')[0].setDisabled(false);
                    Ext.getCmp('gramcont').setDisabled(false);
                  }
                }
              }, {
                xtype: 'radiofield',
                name: 'lemma_type',
                boxLabel: locale[lang].lemma_fingerspell,
                inputValue: 'fingerspell',
                handler: function (ctl, val) {
                  if (val) {
                    Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].show();
                    Ext.getCmp('boxcolloc').query('component[name="swcompos"]')[0].setDisabled(false);
                    Ext.getCmp('gramcont').setDisabled(false);
                  }
                }
              }, {
                xtype: 'radiofield',
                name: 'lemma_type',
                boxLabel: locale[lang].lemma_colloc,
                inputValue: 'collocation',
                handler: function (ctl, val) {
                  if (val) {
                    Ext.getCmp('boxcolloc').query('component[name="collocationinfo"]')[0].show();
                    Ext.each(Ext.getCmp('tabForm').query('[name=slovni_druh]'), function (item) { item.setValue('ustalene') });
                    Ext.getCmp('gramcont').setDisabled(true);
                  }
                }
              }, {
                xtype: 'splitter',
                width: 200
              }, { xtype: 'tbfill' }, create_comment_button('boxcolloc'), create_stav()
              ]
            }, 
            { xtype: 'container',
              name: 'collocationinfo',
              hidden: true,
              width: 1630,
              layout: { type: 'hbox' },
              items: [
                { xtype: 'fieldset', id: 'colbox',
                  title: locale[lang].lemma_composed,  // části spojení, kompozita
                  width: 1030,
                  items: [
                    { xtype: 'button', icon: '/editor/add.png', cls: 'add',
                      handler: function () {
                        var sw = create_colloc(entryid);
                        Ext.getCmp('colbox').insert(Ext.getCmp('colbox').items.length - 1, sw);
                        track_change();
                      }
                    }
                  ]
                }, 
                { xtype: 'fieldset', 
                  title: locale[lang].trans_composed,
                  items: [
                    { xtype: 'textfield', 
                      name: 'swcompos'
                    }
                  ]
                }
              ]
            }]
          },
          { xtype: 'fieldset',
            collapsible: true,
            title: locale[lang].presentform, //záhlaví, prezentační forma box 
            cls: 'lemma-box',
            layout: { type: 'vbox'},
            items: [
              { xtype: 'container',
                layout: { type: 'hbox' }, // videa + sw             
                items: [                                        
                  { xtype: 'fieldset',
                    id: 'videobox',   // box pro videa
                    type: 'hbox',
                    title: locale[lang].video, 
                    flex: 1,
                    width: 1030,                  
                    items: [
                      { xtype: 'container', layout: { type: 'hbox'},
                        items: [
                          { xtype: 'button',
                            icon: '/editor/add.png',
                            cls: 'add',
                            handler: function () {
                              var vid = create_video(entryid, true);
                              Ext.getCmp('videobox').insert(Ext.getCmp('videobox').items.length - 1, vid);
                              track_change();
                            }
                          }, 
                          { xtype: 'tbfill'}, /*create_comment_button('videobox')*/]
                      },                
                    ]
                  },                
                  { xtype: 'fieldset',  // signwriting
                    id: 'swfieldset',
                    collapsible: true,
                    cls: 'sw-box',
                    width: 600,
                    layout: { type: 'vbox' },
                    title: locale[lang].signwriting,
                    items: [
                      { xtype: 'container',
                        layout: {type: 'hbox'},
                        items: [
                          { xtype: 'container', name: 'prazdny', width: 400, fieldLabel: ''},
                          create_stav(),                          
                        ]
                      },
                      { xtype: 'container',
                        layout: {type: 'hbox'},
                        items: [
                          { xtype: 'container', name: 'prazdny', width: 385, fieldLabel: ''},
                          create_comment_button('swfieldset'),                          
                        ]
                      },                                                                
                      { xtype: 'container',
                        layout: {type: 'vbox'},
                        id: 'swbox',
                        items: [                        
                          { xtype: 'container',
                            layout: { type: 'hbox' },
                            items: [
                              { xtype: 'button', icon: '/editor/add.png', cls: 'add',
                                handler: function () {
                                  var sw = create_sw(entryid, true);
                                  Ext.getCmp('swbox').insert(Ext.getCmp('swbox').items.length - 1, sw);
                                  track_change();
                                }
                              },
                              { xtype:'tbfill', width:200},
                              { xtype: 'radiofield',
                                name: 'primary_sw',
                                boxLabel: locale[lang].removeprimary,
                                labelWidth: 250,
                                inputValue: 'primary'}
                            ]
                          }
                        ]
                      }
                    ]
                  }
                ]
            }, {
              xtype: 'fieldset',
              title: locale[lang].hamnosys,
              checkboxToggle: true,
              id: 'hamnbox',
              items: [{
                xtype: 'textfield',
                id: 'hamndata',
                name: 'hamndata',
                hidden: true,
                listeners: {
                  'change': function () {
                    Ext.getCmp('tabForm').query('component[name="hamnimg"]')[0].el.setHTML('<img src="http://znaky.zcu.cz/proxy/tts/tex2img.png?generator[template]=hamnosys&generator[dpi]=200&generator[engine]=x&generator[tex]=' + encodeURI(Ext.getCmp('tabForm').query('component[name="hamndata"]')[0].getValue()) + '"/>');
                  }
                }
              }, {
                xtype: 'container',
                layout: {
                  type: 'hbox'
                },
                items: [{
                  xtype: 'button',
                  name: 'hamnbutton',
                  text: 'HNS editor',
                  handler: function () {
                    Ext.getCmp('hamnosys').show();
                    var task = new Ext.util.DelayedTask(function () {
                      document.getElementById('hamnosys').childNodes[0].receiveData(entrydata['lemma']['hamnosys']['_text']);
                    });
                    task.delay(1000);
                  }
                }, {
                  xtype: 'box',
                  name: 'hamnimg',
                  width: 500,
                  listeners: {
                    'render': function (comp) {
                      comp.getEl().on('click', function () {
                        Ext.getCmp('hamnosys').show();
                        var task = new Ext.util.DelayedTask(function () {
                          document.getElementById('hamnosys').childNodes[0].receiveData(entrydata['lemma']['hamnosys']['_text']);
                        });
                        task.delay(1000);
                      });
                    }
                  }
                }, create_comment_button('hamnbox'), create_stav()]
              }, {
                xtype: 'flash',
                name: 'hamnosys',
                id: 'hamnosys',
                /* url: '/editor/hamnosys1.swf?lang=cs&table_xml_url=/editor/ham.txt&charsLayout_xml_url=/editor/charactersLayout.xml&form_field_id=hamndata',*/
                width: 700,
                height: 250,
              }, create_copyrightSW('hamnosys', false)]
            }]
          }, 
          { xtype: 'fieldset',
            title: 'homonymum (více oddělit ,)',
            id: 'boxhomon',
            items: [
              { xtype: 'textfield', name: 'homonym' }
            ]
          }, 
          { xtype: 'fieldset', // gramatický popis
            collapsible: true,
            title: locale[lang].gramdesc,
            id: 'gramdesc',
            width: 1635,
            layout: { type: 'vbox' },
            items: [
              { xtype: 'container',
                layout: { type: 'hbox' },
                items: [
                  { xtype: 'container',
                    layout: { type: 'vbox' },
                    items: [
                      { xtype: 'container',
                        layout: { type: 'vbox' },
                        name: 'gramcont',
                        id: 'gramcont',
                        items: [
                          create_gram(entryid), // přidá slovní druh
                          { xtype: 'button', icon: '/editor/add.png', cls: 'add',
                            handler: function () {
                              var transset = create_gram(entryid);
                              Ext.getCmp('gramcont').insert(Ext.getCmp('gramcont').items.length - 1, transset);
                              track_change();
                            }
                          }
                        ]
                      }, 
                      { xtype: 'container',
                        layout: { type: 'hbox' },
                        items: [
                          { xtype: 'container',
                            layout: { type: 'vbox' },
                            items: [
                              { xtype: 'container',
                                layout: { type: 'hbox' },
                                items: [
                                  { xtype: 'textfield', fieldLabel: locale[lang].mluvkomp, name: 'mluv_komp'}, 
                                  { xtype: 'combobox', name: 'mluv_komp_sel', queryMode: 'local', displayField: 'text', 
                                    valueField: 'value', store: komptypeStore, forceSelection: true, autoSelect: true, editable: false, allowBlank: true, width: 100 }
                                ]
                              }, 
                              { xtype: 'container',
                                layout: { width: 100, fieldLabel: '', type: 'vbox' },
                                items: []
                              }, 
                              { xtype: 'container',
                                layout: { type: 'hbox' },
                                items: [
                                  { xtype: 'textfield', fieldLabel: locale[lang].oralkomp, name: 'oral_komp' }, 
                                  { xtype: 'combobox', name: 'oral_komp_sel', queryMode: 'local', displayField: 'text', valueField: 'value', 
                                    store: komptypeStore, forceSelection: true, autoSelect: true, editable: false, allowBlank: true, width: 100 }
                                ]
                              }
                            ]
                          },
                          create_text_video('gramatikatext', entryid, 'text', false, 'G')
                        ]
                      },
                      { xtype: 'fieldcontainer', // gramatická varianta
                        fieldLabel: locale[lang].gramvariant,
                        id: 'gvarbox',
                        layout: { type: 'hbox' },
                        items: [
                          { xtype: 'button', icon: '/editor/add.png', cls: 'add',
                            handler: function () {
                              var sw = create_variant(entryid);
                              Ext.getCmp('gvarbox').insert(Ext.getCmp('gvarbox').items.length - 1, sw);
                              track_change();
                            }
                          }
                        ]
                      }
                    ]
                  }, 
                  { xtype: 'container',
                    layout: { type: 'hbox' },
                    items: [create_comment_button('gramdesc'), create_stav()]
                  }
                ]
              }, 
              { xtype: 'container',
                layout: { type: 'hbox' },
                items: [create_copyright('gram_popis', false)]
              }
            ]
          }, 
          { xtype: 'fieldset',
            collapsible: true,
            title: locale[lang].styldesc,
            id: 'styldesc',
            width: 1635,
            layout: { type: 'vbox' },
            items: [
              { xtype: 'container',
                layout: { type: 'hbox' },
                items: [
                  { xtype: 'container',
                    layout: { type: 'vbox' },
                    items: [
                      { xtype: 'combobox', 
                        fieldLabel: locale[lang].puvod2, 
                        name: 'puvod_slova', queryMode: 'local', displayField: 'text', valueField: 'value', store: puvodStore, forceSelection: false, autoSelect: true, editable: true 
                      }, 
                      { xtype: 'combobox', name: 'region', 
                        fieldLabel: locale[lang].oblastuziti, queryMode: 'local', displayField: 'text', valueField: 'value', store: regStore, forceSelection: true, autoSelect: true, editable: false, multiSelect: true 
                      }, 
                      { xtype: 'combobox', fieldLabel: locale[lang].kategorie, 
                        name: 'kategorie', queryMode: 'local', displayField: 'text', valueField: 'value', store: kategorieStore, forceSelection: true, autoSelect: true, editable: false
                      }, 
                      { xtype: 'combobox', name: 'generace', 
                        fieldLabel: locale[lang].generace, queryMode: 'local', displayField: 'text', valueField: 'value', store: genStore, forceSelection: true, autoSelect: true, editable: false, multiSelect: true
                      }, 
                      { xtype: 'combobox', fieldLabel: locale[lang].stylpriznak, 
                        name: 'stylpriznak', queryMode: 'local', store: stylprizStore, forceSelection: true, autoSelect: true, displayField: 'text', valueField: 'value', editable: false, multiSelect: true
                      }, 
                      { xtype: 'combobox', fieldLabel: locale[lang].gender, 
                        name: 'gender', queryMode: 'local', displayField: 'text', valueField: 'value', store: genderStore, forceSelection: true, autoSelect: true, editable: false
                      }
                    ]
                  }, 
                  { xtype: 'container', name: 'prazdny', width: 100, fieldLabel: '' }, 
                  create_text_video('styltext', entryid, 'text', false, 'S'),
                  { xtype: 'container', 
                    layout: { type: 'vbox' },
                    items: [
                      create_stav(), create_comment_button('styldesc')
                    ]
                  }
                ]
              }, 
              { xtype: 'container', // stylistická varianta
                layout: { type: 'hbox' },
                items: [
                  { xtype: 'fieldcontainer',
                    fieldLabel: locale[lang].stylvariant,
                    id: 'varbox',
                    layout: { type: 'hbox' },
                    items: [
                      { xtype: 'button', icon: '/editor/add.png', cls: 'add',
                        handler: function () {
                          var sw = create_variant(entryid);
                          Ext.getCmp('varbox').insert(Ext.getCmp('varbox').items.length - 1, sw);
                          track_change();
                        }
                      }
                    ]
                  }
                ]
              }, 
              { xtype: 'container',
                layout: { type: 'hbox' },
                items: [
                  create_copyright('styl_popis', false)
                ]
              }
            ]
          }
        ]
      }, 
      { xtype: 'fieldset',
        title: locale[lang].meanings,
        collapsible: true,
        id: 'vyznamy_box',
        items: [
          sense1, 
          { xtype: 'button', icon: '/editor/add.png', cls: 'add',
            text: locale[lang].new_meaning,
            handler: function () {
              var vyznam = create_vyznam(entryid, true);
              Ext.getCmp('vyznamy_box').insert(Ext.getCmp('vyznamy_box').items.length - 1, vyznam);
              track_change();
            }
          }
        ]
      }
    ]
  });

  // panely - připojené soubory
  var mediatab = Ext.create('Ext.form.Panel', {
    title: locale[lang].attachedfiles,
    id: 'media',
    layout: 'anchor',
    fieldDefaults: { labelAlign: 'center' },
    listeners: {
      afterrender: function () {
        add_videopreview();
      }
    },
    items: [
      { xtype: 'container',
        layout: { type: 'hbox' },
        width: 1650,
        id: 'mediabox-container',
        items: [
          { xtype: 'container',
            layout: { type: 'vbox' },
            id: 'media-buttons',
            items: [
              { xtype: 'button', text: locale[lang].attachfile,
                handler: function () 
                  { var vid = create_media(entryid, true);
                    Ext.getCmp('mediabox').insert(Ext.getCmp('mediabox').items.length, vid);
                  }
              }, 
              { xtype: 'button', text: locale[lang].savefiles,
                handler: function () {
                  var data = {};
                  data.update_video = []
                  var mar = Ext.getCmp('mediabox').query('[name=mediaitem]');
                  for (var i = 0; i < mar.length; i++) 
                    { data.update_video.push(
                      { 'id': mar[i].query('component[name="mediaid"]')[0].getValue(),
                        'id_meta_author': mar[i].query('component[name="copy_autor"]')[0].getValue(),
                        'id_meta_copyright': mar[i].query('component[name="copy_copy"]')[0].getValue(),
                        'id_meta_source': mar[i].query('component[name="copy_zdroj"]')[0].getValue(),
                        'admin_comment': mar[i].query('component[name="copy_admin"]')[0].getValue(),
                        'location': mar[i].query('component[name="vidid"]')[0].getValue(),
                        'status': mar[i].query('component[name="stav"]')[0].getValue(),
                        'orient': mar[i].query('component[name="' + mar[i].id + 'orient"]')[0].getGroupValue(),
                        'type': mar[i].query('component[name="type"]')[0].getValue(),
                      });
                    } 
                  console.log(data);
                  Ext.MessageBox.show(
                    { msg: 'Ukládám informace...',
                      progressText: 'Ukládám...',
                      width: 300,
                      wait: true,
                      waitConfig: { interval: 200 }
                    }
                  );
                  Ext.Ajax.request(
                    { url: '/' + dictcode + '/update_video',
                      timeout: 240000,
                      params: { data: Ext.encode(data)},
                      method: 'post',
                      success: function (response) 
                        { console.log (response.responseText);
                          Ext.Msg.alert
                            ('Uloženo', 'uloženo', function (btn) { window.location.reload(); });
                        }
                    }
                  );
                }
              }
            ]
          },
          { xtype: 'fieldset',
            layout: 'anchor',
            width: 1250,
            autoHeight: true,
            flex: 1,
            id: 'mediabox',
            items: [
              { xtype: 'tbfill'}
            ]
          }     
        ]
      }
    ]
  });

  var entryform = Ext.create('Ext.form.Panel', {
    url: '/' + dictcode,
    xtype: 'form',
    id: 'tabForm',
    title: 'Lemma id____',
    border: false,    
    bodyBorder: false,
    fieldDefaults: {
      labelWidth: 100,
      msgTarget: 'side'
    },
    header: {
      titlePosition: 0,
      items: [
        {
          xtype: 'button',
          text: locale[lang].admintools,
          cls: 'btn',
          icon: '/editor/img/admin_list.png',
          handler: function () {
            var odkaz = '/' + dictcode + '/report';
            window.open(odkaz);
          }
        },
        {
          xtype: 'button',
          text: locale[lang].newlemma,
          cls: 'btn',
          icon: '/editor/img/newlemma.png',
          handler: function () {
            var odkaz = '/editor' + dictcode + '/?id=&lang=' + lang;
            window.open(odkaz);
          }
        }, {
          xtype: 'button',
          text: locale[lang].admintools,
          cls: 'btn',
          icon: '/editor/img/timeback_m.png',
          handler: function () {
            var odkaz = 'https://admin.dictio.info/history?code=' + dictcode + '&entry=' + entryid;
            window.open(odkaz);
          }
        }, {
          xtype: 'button',
          text: locale[lang].viewplus,
          icon: '/editor/img/display.png',
          cls: 'btn',
          handler: function () {
            var odkaz = '/' + dictcode + '/show/' + entryid + '?lang=' + lang;
            window.open(odkaz);
          }
        }, {
          xtype: 'button',
          text: locale[lang].saveview, 
          name: 'savebutton',
          cls: 'btn hidden',
          id: 'btnSV1',
          icon: '/editor/img/savedisplay.png',
          handler: function () {
            Ext.Msg.alert('Stav', locale[lang].savemsg);
            console.log('savedisplay horni');
            var waitBox = Ext.MessageBox.wait(locale[lang].savemsg);
            var data = save_doc(entryid);
            if (data != false) {
              console.log('odeslat data');
              Ext.Ajax.request({
                url: '/' + dictcode + '/save',
                params: {
                  data: JSON.stringify(data),
                },
                method: 'POST',
                timeout: 30000,
                failure: function (response) {
                  console.log('fail')
                  console.log(response.responseText)
                },
                success: function (response) {
                  console.log(response.responseText)
                  var data = JSON.parse(response.responseText);
                  Ext.Msg.alert('Stav', data.msg);
                  Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                  window.location = '/' + dictcode + '/show/' + entryid + '?lang=' + lang;
                }
              });
            }
          }
        }, {
          xtype: 'label',
          text: '',
          name: 'modifiedlabel',
          cls: 'modified-box',
          style: 'width: 200px !important'
        },
        /*{
          xtype: 'button',
          text: 'komentáře',
          handler: function() {
            if ($('#comments').is(':hidden')) {
              $('#comments').show();
              $('#topdiv').css('position', 'absolute');
              let height = parseInt($('#topdiv').css('height'));
              height -= 150;
              $('#comments').css('height', height + 'px');
            } else {
              $('#comments').hide();
              $('#topdiv').css('position', '');
            }
          }
        },*/
        {
          xtype: 'tbspacer',
          flex: 6
        }, {
          xtype: 'button',
          cls: 'btn del',
          text: locale[lang].deleteentry,
          icon: '/editor/img/delete2.png',
          handler: function () {
            //Ext.Msg.confirm(locale[lang].delete, locale[lang].deletemsg, function(btn, text) {
            Ext.Msg.show({
              title: locale[lang].delete, msg: locale[lang].deletemsg, buttons: Ext.Msg.YESNO, icon: Ext.MessageBox.QUESTION,
              buttonText: { yes: locale[lang].buttonyes, no: locale[lang].buttonno },
              fn: function (btn) {
                if (btn == 'yes') {
                  Ext.Ajax.request({
                    url: '/' + dictcode + '/delete/' + entryid,
                    method: 'post',
                    success: function (response) {
                      console.log(response.responseText);
                      if (response.responseText.substring(0, 7) == 'DELETED') {
                        Ext.Msg.alert('Stav', locale[lang].deleted);
                        Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
                        window.location = '/' + dictcode;
                      } else {
                        Ext.Msg.alert('Chyba', response.responseText);
                      }
                    }
                  });
                }
              }
            });
          }
        }]
    },
    items: {
      xtype: 'tabpanel',
      activeTab: 0,
      defaults: {
        bodyPadding: 10,
        layout: 'anchor'
      },
      items: [datatab, mediatab]
    },
    buttons: [{
      text: locale[lang].save,
      cls: 'btn',
      id: 'btnS2',
      name: 'savebutton',
      icon: '/editor/img/save.png',
      handler: function () {
        var waitBox = Ext.MessageBox.wait(locale[lang].savemsg);
        var data = save_doc(entryid);
        if (data != false) {
          Ext.Ajax.request({
            url: '/' + dictcode + '/save',
            timeout: 30000,
            params: {
              data: JSON.stringify(data),
            },
            method: 'POST',
            success: function (response) {
              entry_updated = false;
              entry_update_show(false);
              var data = JSON.parse(response.responseText);
              console.log(data)
              Ext.Msg.alert('Stav', data.msg);
              Ext.Function.defer(Ext.MessageBox.hide, 9000, Ext.MessageBox);
              if (is_new_entry) {
                window.location = '/editor' + dictcode + '/?id=' + entryid + '&lang=' + lang;
              }
            }
          });
        }
      }
    },
    {
      text: locale[lang].saveview,
      name: 'savebutton',
      cls: 'btn',
      id: 'btnSV2',
      icon: '/editor/img/savedisplay.png',
      handler: function () {
        console.log('savedisplay spodni');
        var data = save_doc(entryid);
        if (data != false) {
          Ext.Msg.alert('Stav', locale[lang].savemsg);
          var waitBox = Ext.MessageBox.wait(locale[lang].savemsg);
          console.log('odeslat data');
          Ext.Ajax.request({
            url: '/' + dictcode + '/save',
            timeout: 30000,
            params: {
              data: JSON.stringify(data),
            },
            method: 'POST',
            failure: function (response) {
              console.log('fail')
              console.log(response.responseText)
            },
            success: function (response) {
              var data = JSON.parse(response.responseText);
              console.log(data)
              Ext.Msg.alert('Stav', data.msg);
              Ext.Function.defer(Ext.MessageBox.hide, 300, Ext.MessageBox);
              window.location = '/' + dictcode + '/show/' + entryid + '?lang=' + lang;
            }
          });
        }
      }
    },
    {
      text: locale[lang].viewplus,
      cls: 'btn',
      icon: '/editor/img/display.png',
      handler: function () {
        var odkaz = '/' + dictcode + '/show/' + entryid + '?lang=' + lang;
        window.open(odkaz);
      }
    }]
  });

  /* RENDER */
  //entryform.render(document.body);
  entryform.render(document.getElementById('topdiv'), 0);
  document.getElementById('inform').innerHTML = locale[lang].upload_video;

  //makeDroppable(document.getElementById('uploadtarget'), callback);
  //document.getElementById('tabForm').className += ' droppable';
  //makeDroppable(document.getElementById('tabForm'), callback);
  makeDroppable(document.getElementById('topdiv'), callback);

  /* LOAD params */
  var params = Ext.Object.fromQueryString(window.location.search.substring(1));
  if (params.id != null && params.id != '') {
    /* load filelist */
    entryid = params.id;
    g_entryid = params.id;
    load_doc(params.id, params.history, params.type)
    //reload_files(params.id);
    window.onbeforeunload = function (e) {
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
