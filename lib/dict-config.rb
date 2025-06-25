pos_sign = %w[subst verb modif pron num konj par taz kat klf spc]
pos_write = %w[subst verb pron num konj par adj adv prep int]
stylpriznak_write = %w[biblicky cirkev odborny hanlivy]
stylpriznak_sign = %w[biblicky cirkev odborny hanlivy sz zc]
$dict_info = {
  'cs' => {'type' => 'write', 'label'=>'čeština', 'target'=>'czj', 'pos'=>pos_write, 'stylpriznak'=>stylpriznak_write},
  'czj' => {'type' => 'sign', 'label'=>'ČZJ', 'search_in'=>'cs', 'target'=>'cs', 'pos'=>pos_sign+['finger'], 'stylpriznak'=>stylpriznak_sign, 'oblast'=>%w[cr cechy morava plzen praha brno vm hk jih zl cb ot ol]},
  'en' => {'type' => 'write', 'label'=>'English', 'target'=>'is', 'pos'=>pos_write, 'stylpriznak'=>stylpriznak_write},
  'asl' => {'type' => 'sign', 'label'=>'ASL', 'search_in'=>'en', 'target'=>'en', 'pos'=>pos_sign, 'stylpriznak'=>stylpriznak_sign},
  'is' => {'type' => 'sign', 'label'=>'IS', 'search_in'=>'en', 'target'=>'en', 'pos'=>pos_sign, 'stylpriznak'=>stylpriznak_sign},
  'sj' => {'type' => 'write', 'label'=>'slovenčina', 'target'=>'spj', 'pos'=>pos_write, 'stylpriznak'=>stylpriznak_write},
  'spj' => {'type' => 'sign', 'label'=>'SPJ', 'search_in'=>'sj', 'target'=>'sj', 'pos'=>pos_sign, 'stylpriznak'=>stylpriznak_sign},
  'de' => {'type' => 'write', 'label'=>'Deutsch', 'target'=>'ogs', 'pos'=>pos_write, 'stylpriznak'=>stylpriznak_write},
  'ogs' => {'type' => 'sign', 'label'=>'OGS', 'search_in'=>'de', 'target'=>'de', 'pos'=>pos_sign, 'stylpriznak'=>stylpriznak_sign},
  'uk' => {'type' => 'write', 'label'=>'українська', 'target'=>'uzm', 'pos'=>pos_write, 'stylpriznak'=>stylpriznak_write},
  'uzm' => {'type' => 'sign', 'label'=>'УЖМ', 'search_in'=>'uk', 'target'=>'uk', 'pos'=>pos_sign, 'stylpriznak'=>stylpriznak_sign},
}
$fsw_style = '-CG_white_'
