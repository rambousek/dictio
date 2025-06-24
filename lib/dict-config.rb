pos_sign = %w[subst verb modif pron num konj par taz kat klf spc]
pos_write = %w[subst verb pron num konj par adj adv prep int]
$dict_info = {
    'cs' => {'type' => 'write', 'label'=>'Czech', 'target'=>'czj', 'pos'=>pos_write},
    'czj' => {'type' => 'sign', 'label'=>'ČZJ', 'search_in'=>'cs', 'target'=>'cs', 'pos'=>pos_sign+['finger']},
    'en' => {'type' => 'write', 'label'=>'English', 'target'=>'is', 'pos'=>pos_write},
    'asl' => {'type' => 'sign', 'label'=>'ASL', 'search_in'=>'en', 'target'=>'en', 'pos'=>pos_sign},
    'is' => {'type' => 'sign', 'label'=>'IS', 'search_in'=>'en', 'target'=>'en', 'pos'=>pos_sign},
    'sj' => {'type' => 'write', 'label'=>'Slovak', 'target'=>'spj', 'pos'=>pos_write},
    'spj' => {'type' => 'sign', 'label'=>'SPJ', 'search_in'=>'sj', 'target'=>'sj', 'pos'=>pos_sign},
    'de' => {'type' => 'write', 'label'=>'German', 'target'=>'ogs', 'pos'=>pos_write},
    'ogs' => {'type' => 'sign', 'label'=>'OGS', 'search_in'=>'de', 'target'=>'de', 'pos'=>pos_sign},
    'uk' => {'type' => 'write', 'label'=>'Ukrainian', 'target'=>'uzm', 'pos'=>pos_write},
    'uzm' => {'type' => 'sign', 'label'=>'UZM', 'search_in'=>'uk', 'target'=>'uk', 'pos'=>pos_sign},
  }
$fsw_style = '-CG_white_'
