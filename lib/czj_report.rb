## Generate admin reports
class CzjReport
  attr_accessor :sign_dicts

  # find not solved comments by dictionary
  # @param [CZJDict] dict Dictionary object
  # @param [Hash] params
  def get_comment_report(dict, params)
    report = {'comments' => [], 'resultcount' => 0}
    query = {'$and' => [
      {'dict' => dict.dictcode},
      {'$or' => [
        {'solved' => ''},
        {'solved' => {'$exists' => false}}
      ]}
    ]}

    if params.include?('assign')
      case params['assign']
      when '_ass'
        query['$and'] << {'assign' => {'$exists'=>true, '$ne' => ''}}
      when '_not'
        query['$and'] << {'$or' => [
          {'assign' => ''},
          {'assign' => {'$exists' => false}}
        ]}
      when ''
      else
        query['$and'] << {'assign' => params['assign']}
      end
    end
    $stdout.puts query
    if params.include?('entry') and params['entry'] != ''
      query['entry'] = params['entry']
    end
    report['query'] = query
    cursor = $mongo['koment'].find(
      query,
      :collation => {'locale' => 'cs', 'numericOrdering'=>true},
      :sort => {'entry' => 1, 'assign' => 1}
    )
    report['resultcount'] = cursor.count_documents

    cursor.each{|kom|
      entry = dict.getone(kom['dict'], kom['entry'])
      {'video' => 'video ', 'vyznam' => 'význam '}.map{|k,v| kom['box'].sub!(k, v)}
      unless entry.nil?
        if @sign_dicts.include?(kom['dict'])
          kom['video'] = ''
          if entry['lemma'] and entry['lemma']['video_front']
            kom['video'] = entry['lemma']['video_front']
          end
        else
          kom['lemma'] = ''
          if entry['lemma'] and entry['lemma']['title']
            kom['lemma'] = entry['lemma']['title']
          end
        end
      end
      report['comments'] << kom
    }
    report
  end

  # @param [CZJDict] dict
  # @param [Hash] params
  # @param [Hash] user_info
  # @param [Integer] start
  # @param [Integer] limit
  # @return [Hash]
  def get_report(dict, params, user_info, start=0, limit=nil)
    report = {'query'=>{},'entries'=>[], 'resultcount'=>0}
    search_cond, _ = get_search_cond(dict, params, user_info)
    $stdout.puts search_cond
    entry_ids = []
    cursor = $mongo['entries'].find(
      {'$and': search_cond},
      :collation => {'locale' => 'cs', 'numericOrdering'=>true},
      :sort => {'id' => 1}
    )
    report['resultcount'] = cursor.count_documents
    cursor = cursor.skip(start)
    cursor = cursor.limit(limit) if limit.to_i > 0
    cursor.each{|res|
      entry = res
      if params['nes_sw'].to_s != '' or params['bez_sw'].to_s != ''
        entry = dict.sw.get_sw(entry)
      end
      if params['koment'].to_s != ''
        entry = dict.add_media(entry)
      end
      entry = dict.add_rels(entry, false, "translation")
      report['entries'] << entry
      entry_ids << res['id']
    }
    report['query'] = search_cond
    if params['koment'].to_s != ''
      report['koment'] = {}
      $mongo['koment'].find({'dict': dict.dictcode, 'entry': {'$in': entry_ids}}).each{|kom|
        report['koment'][kom['entry']] = [] if report['koment'][kom['entry']].nil?
        report['koment'][kom['entry']] << kom
      }
    end
    report
  end

  # build search query
  # @param [CZJDict] dict
  # @param [Hash] params
  # @param [Hash] user_info
  # @return [Array, Array]
  def get_search_cond(dict, params, user_info)
    search_cond = []
    trans_used = []

    search_cond << {'dict': dict.dictcode, 'empty': {'$exists': false}}
    $stderr.puts params

    # zadane ID
    if params['idsf'].to_s != ''
      idfa = params['idsf'].to_s.strip.split(/[,;\s]/)
      idfa.reject!(&:empty?)
      search_cond << {'id': {'$in': idfa}}
    end

    # celni video schvalene
    if params['schvcelni'].to_s != ''
      search_cond << cond_schvcelnibocni(dict, params, 'lemma.video_front', 'schvcelni')
    end

    # bocni video schvalene
    if params['schvbocni'].to_s != ''
      search_cond << cond_schvcelnibocni(dict, params, 'lemma.video_side', 'schvbocni')
    end

    # celni video zadane
    if params['celni'].to_s != ''
      search_cond << cond_celnibocni(params, 'lemma.video_front', 'celni')
    end

    # bocni video zadane
    if params['bocni'].to_s != ''
      search_cond << cond_celnibocni(params, 'lemma.video_side', 'bocni')
    end

    # schvalena definice
    if params['vyznam'].to_s != ''
      if params['vyznam'].to_s == 'ano'
        search_cond << {'$and':[{'meanings.status':{'$ne':'hidden'}},{'meanings.text.file':{'$not':{'$exists':false}}}]}
      else
        search_cond << {'$or':[{'meanings.status':{'$ne':'published'}},{'meanings.text.file':{'$exists':false}}]}
      end
    end

    # zadana definice
    if params['vyznamvid'].to_s != ''
      if params['vyznamvid'].to_s == 'ano'
        search_cond << {'meanings': {'$not':{'$elemMatch': {'text.file': {'$exists': false}}}}}
      else
        search_cond << {'meanings': {'$elemMatch': {'text.file': {'$exists': false}}}}
      end
    end

    # write, schvalena definice
    if params['vyznamcs'].to_s != ''
      search_cond << cond_vyznamcs(params)
    end

    # write, zadana definice
    if params['vyznamcszad'].to_s != ''
      search_cond << cond_vyznamcszad(params)
    end

    # pracovni skupina
    if params['skup'].to_s != '' and params['def_skup'].length > 0
      search_cond << cond_skup(params)
    end

    # zverejnovani
    if params['completeness'].to_s != '' and params['completenessbox'].to_s != ''
      search_cond << cond_completeness(params)
    end

    # schvaleny preklad
    $dict_info.each{|code, _|
      if params['pubtrans'+code].to_s != '' or params['translation'+code].to_s != ''
        trans_cond = cond_trans(params['pubtrans'+code].to_s, params['translation'+code].to_s, code)
        search_cond << trans_cond if trans_cond != nil
      end
    }

    # synonym
    if params['pubsynonym'].to_s != '' or params['synonym'].to_s != ''
      trans_cond = cond_trans(params['pubsynonym'].to_s, params['synonym'].to_s, dict.dictcode, 'synonym')
      search_cond << trans_cond if trans_cond != nil
    end

    # komentare
    if params['koment'].to_s != '' and params['komentbox'].to_s != ''
      search_cond << cond_koment(dict, params, user_info)
    end

    # zadany SW
    if params['bez_sw'].to_s != ''
      search_cond << cond_bezsw(params)
    end

    # schvaleny SW
    if params['nes_sw'].to_s != ''
      search_cond << cond_nessw(params)
    end

    # typ hesla
    if params['typhesla'].to_s != '' and params['seltyphesla'].to_s != ''
      search_cond << cond_typhesla(params)
    end

    # slovni druh
    if params['sldruh'].to_s != '' and params['slovni_druh'].to_s != ''
      search_cond << cond_sldruh(params)
    end

    # mluv komp
    if params['mluvkomp'].to_s != ''
      search_cond << cond_mluvkomp(params)
    end

    # oral komp
    if params['oralkomp'].to_s != ''
      search_cond << cond_oralkomp(params)
    end

    # MK/OK
    if params['mkok'].to_s != ''
      search_cond << cond_mkok(params)
    end

    # sign, schvaleny priklad
    if params['usage'].to_s != ''
      search_cond << cond_usage(params)
    end

    # sign, zadany priklad
    if params['usagevid'].to_s != ''
      search_cond << cond_usagevid(params)
    end

    # write, schvaleny priklad
    if params['usagecs'].to_s != ''
      search_cond << cond_usagecs(params)
    end

    # write, zadany priklad
    if params['usagecszad'].to_s != ''
      search_cond << cond_usagecszad(params)
    end

    # homonym, ma/nema
    if params['homonym'].to_s != ''
      if params['homonym'].to_s == 'ano'
        search_cond << {'lemma.homonym': {'$exists': true, '$ne': []}}
        search_cond << {'lemma.homonym': {'$ne': ''}}
      else
        search_cond << {'$or': [
          {'lemma.homonym': {'$exists': false}},
          {'lemma.homonym': []},
          {'lemma.homonym': ''}
        ]}
      end
    end

    [search_cond, trans_used]
  end

  private

  # build translation query
  # @param [String] pubtrans
  # @param [String] trans
  # @param [String] target
  # @param [String] type
  # @return [Hash, nil]
  def cond_trans(pubtrans, trans, target, type="translation")
    trans_cond = nil
    # jen pubtrans, schvaleny preklad
    if pubtrans != '' and trans == ''
      if pubtrans == 'ano'
        trans_cond = {'$or': [
          {'meanings.relation': {'$elemMatch': {'type': type, 'target': target, 'status': 'published'}}},
          {'meanings.usages': {'$elemMatch': {'status':'published', 'relation': {'$elemMatch': {'type': type, 'target': target}}}}}
        ]}
      else
        trans_cond = {'meanings': {'$elemMatch': {'is_translation_unknown': {'$ne': '1'}, '$or': [
          {'meanings.relation': {'$not': {'$elemMatch': {'type': type, 'target': target}}}},
          {'meanings.relation': {'$elemMatch': {'type': type, 'target': target, 'status': 'hidden'}}},
          {'meanings.usages': {'$elemMatch': {'status':'hidden', 'relation': {'$elemMatch': {'type': type, 'target': target}}}}}
        ]}}}
      end
    end

    # jen trans, zadany preklad
    if pubtrans == '' and trans != ''
      if trans == 'ano'
        trans_cond = {'meanings': {'$elemMatch': {'$or': [
          {'relation': {'$elemMatch': {'type': type, 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
          {'usages.relation': {'$elemMatch': {'type': type, 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}
        ]}}}
      else
        trans_cond = {'meanings': {'$not': {'$elemMatch': {'$or': [
          {'relation': {'$elemMatch': {'type': type, 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
          {'usages.relation': {'$elemMatch': {'type': type, 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}
        ]}}}}
      end
    end

    # kombinace schvaleny a zadany
    # zadane+neschvalene = alespon jeden vyznam ma ciselny neschvaleny preklad
    if pubtrans == 'ne' and trans == 'ano'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': {'$ne': 'published'}, 'target': target, 'type': type, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
        {'usages': {'$elemMatch':{'status': {'$ne': 'published'}, 'relation.0':{'$exists':true}, 'relation': {'$elemMatch': {'target': target, 'type': type, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}}}
      ]}}}
    end

    # nezadane+neschvalene = alespon jeden vyznam ma neciselny neschvaleny preklad, nebo nema zadny preklad
    if pubtrans == 'ne' and trans == 'ne'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': {'$ne': 'published'}, 'target': target, 'type': type, 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}},
        {'usages': {'$elemMatch': {'status': {'$ne': 'published'}, 'relation': {'$elemMatch': {'target': target, 'type': type, 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}}}},
        {'$and': [
          {'relation': {'$not': {'$elemMatch': {'type': type, 'target': target}}}},
          {'usages.relation': {'$not': {'$elemMatch': {'type': type, 'target': target}}}}
        ]}
      ]}}}
    end

    #zadane+schvalene = alespon jeden vyznam ma ciselny schvaleny preklad
    if pubtrans == 'ano' and trans == 'ano'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': 'published', 'target': target, 'type': type, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
        {'usages': {'$elemMatch': {'status': 'published', 'relation': {'$elemMatch': {'target': target, 'type': type, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}}}
      ]}}}
    end

    # nezadane+schvalene = alespon jeden vyznam ma neciselny schvaleny preklad
    if pubtrans == 'ano' and trans == 'ne'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': 'published', 'target': target, 'type': type, 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}},
        {'usages': {'$elemMatch': {'status': 'published', 'relation': {'$elemMatch': {'target': target, 'type': type, 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}}}}
      ]}}}
    end

    $stdout.puts trans_cond
    trans_cond
  end

  # build koment query
  # @param [CZJDict] dict
  # @param [Hash] params
  # @param [Hash] user_info
  # @return [Hash]
  def cond_koment(dict, params, user_info)
    koment_ids = []
    koment_user = params['koment_user'].to_s
    komentbox = params['komentbox'].to_s
    koment_moje = params['koment_moje'].to_s
    koment_cond = {}

    if komentbox == ''
      if koment_user != ''
        koment_cond = {'user': koment_user}
      else
        if koment_moje == 'on'
          koment_cond = {'user': user_info['login']}
        end
      end
    else
      case komentbox
      when 'video'
        if koment_user != ''
          koment_cond = {'user': koment_user, 'box': {'$regex': /^video/}}
        else
          if koment_moje == 'on'
            koment_cond = {'user': user_info['login'], 'box': {'$regex': /^video/}}
          else
            koment_cond = {'box': {'$regex': /^video/}}
          end
        end
      when 'videoAB'
        if koment_user != ''
          koment_cond = {'user': koment_user, 'box': {'$regex': /^video[AB]/}}
        else
          if koment_moje == 'on'
            koment_cond = {'user': user_info['login'], 'box': {'$regex': /^video[AB]/}}
          else
            koment_cond = {'box': {'$regex': /^video[AB]/}}
          end
        end
      when 'videoK'
        if koment_user != ''
          koment_cond = {'user': koment_user, '$or': [{'box': {'$regex': /^videoK/}}, {'$and': [{'box': {'$regex': /_us[0-9]/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}
        else
          if koment_moje == 'on'
            koment_cond = {'user': user_info['login'], '$or': [{'box': {'$regex': /^videoK/}}, {'$and': [{'box': {'$regex': /_us[0-9]/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}
          else
            koment_cond = {'$and': [{'$or': [{'box': {'$regex': /^videoK/}}, {'$and': [{'box': {'$regex': /_us[0-9]/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}]}
          end
        end
      when 'vyznam'
        if koment_user != ''
          koment_cond = {'user': koment_user, '$or': [{'box': {'$regex': /^videoD/}}, {'$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}
        else
          if koment_moje == 'on'
            koment_cond = {'user': user_info['login'], '$or': [{'box': {'$regex': /^videoD/}}, {'$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}
          else
            koment_cond = {'$and': [{'$or': [{'box': {'$regex': /^videoD/}}, {'$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}]}
          end
        end
      else
        if koment_user != ''
          koment_cond = {'user': koment_user, 'box': {'$regex': /#{komentbox}/}}
        else
          if koment_moje == 'on'
            koment_cond = {'user': user_info['login'], 'box': {'$regex': /#{komentbox}/}}
          else
            koment_cond = {'box': {'$regex': /#{komentbox}/}}
          end
        end
      end
    end
    koment_cond['$or'] = [{'solved': ''}, {'solved': {'$exists': false}}]
    koment_cond['dict'] = dict.dictcode
    $mongo['koment'].find(koment_cond).each{|kom|
      koment_ids << kom['entry']
    }

    if params['koment'].to_s == 'ano'
      {'id': {'$nin': koment_ids}}
    else
      {'id': {'$in': koment_ids}}
    end
  end

  # query for usagecs
  # @param [Hash] params
  # @return [Hash]
  def cond_usagecs(params)
    if params['usagecs'].to_s == 'ano'
      {'meanings': {'$not': {'$elemMatch': {'$or': [
        {'usages': {'$size': 0}},
        {'usages': {'$exists': false}},
        {'usages': {'$elemMatch': {'$or': [
          {'status': {'$ne': 'published'}},
          {'text._text': ''}
        ]}}}
      ]}}}}
    else
      {'$or': [
        {'meanings.usages': {'$elemMatch': {'$or': [
          {'status': {'$ne': 'published'}},
          {'text._text': ''}
        ]}}},
        {'meanings': {'$elemMatch': {'$or': [
          {'usages': {'$exists': false}},
          {'usages': {'$size': 0}}
        ]}}}
      ]}
    end
  end

  # query for usagecszad
  # @param [Hash] params
  # @return [Hash]
  def cond_usagecszad(params)
    if params['usagecszad'].to_s == 'ano'
      {'meanings': {'$not': {'$elemMatch': {'$or': [
        {'usages': {'$size': 0}},
        {'usages': {'$exists': false}},
        {'usages.text._text': {'$exists': false}},
        {'usages.text._text': ''}
      ]}}}}
    else
      {'meanings': {'$elemMatch': {'$or': [
        {'usages': {'$size': 0}},
        {'usages': {'$exists': false}},
        {'usages.text._text': {'$exists': false}},
        {'usages.text._text': ''}
      ]}}}
    end
  end

  # query for usagevid
  # @param [Hash] params
  # @return [Hash]
  def cond_usagevid(params)
    if params['usagevid'].to_s == 'ano'
      {'meanings': {'$not': {'$elemMatch': {'$or': [
        {'usages': {'$size': 0}},
        {'usages': {'$exists': false}},
        {'usages.text.file.@media_id': {'$exists': false}},
        {'usages.text.file.@media_id': ''}
      ]}}}}
    else
      {'meanings': {'$elemMatch': {'$or': [
        {'usages': {'$size': 0}},
        {'usages': {'$exists': false}},
        {'usages.text.file.@media_id': {'$exists': false}},
        {'usages.text.file.@media_id': ''}
      ]}}}
    end
  end

  # query for usage
  # @param [Hash] params
  # @return [Hash]
  def cond_usage(params)
    if params['usage'].to_s == 'ano'
      {'meanings': {'$not': {'$elemMatch': {'$or': [
        {'usages': {'$size': 0}},
        {'usages': {'$exists': false}},
        {'usages': {'$elemMatch': {'$or': [
          {'status': {'$ne': 'published'}},
          {'text.file.@media_id': ''}
        ]}}}
      ]}}}}
    else
      {'$or': [
        {'meanings.usages': {'$elemMatch': {'$or': [
          {'status': {'$ne': 'published'}},
          {'text.file.@media_id': ''}
        ]}}},
        {'meanings': {'$elemMatch': {'$or': [
          {'usages': {'$exists': false}},
          {'usages': {'$size': 0}}
        ]}}}
      ]}
    end
  end

  # query for MK/OK
  # @param [Hash] params
  # @return [Hash]
  def cond_mkok(params)
    if params['mkok'].to_s == 'ano'
      {'$or': [
        {'lemma.grammar_note.0.@mluv_komp': {'$exists': true, '$ne': ''}},
        {'lemma.grammar_note.0.@oral_komp': {'$exists': true, '$ne': ''}}
      ]}
    else
      {'$and': [
        {'$or': [
          {'lemma.grammar_note.0.@mluv_komp': {'$exists': false}},
          {'lemma.grammar_note.0.@mluv_komp': ''}
        ]},
        {'$or': [
          {'lemma.grammar_note.0.@oral_komp': {'$exists': false}},
          {'lemma.grammar_note.0.@oral_komp': ''}
        ]}
      ]}
    end
  end

  # query for mluv.komp
  # @param [Hash] params
  # @return [Hash]
  def cond_mluvkomp(params)
    if params['mluvkomp'].to_s == 'ano'
      {'lemma.grammar_note.0.@mluv_komp': {'$exists': true, '$ne': ''}}
    else
      {'$or': [
        {'lemma.grammar_note.0.@mluv_komp': {'$exists': false}},
        {'lemma.grammar_note.0.@mluv_komp': ''}
      ]}
    end
  end

  # query for oral.komp
  # @param [Hash] params
  # @return [Hash]
  def cond_oralkomp(params)
    if params['oralkomp'].to_s == 'ano'
      {'lemma.grammar_note.0.@oral_komp': {'$exists': true, '$ne': ''}}
    else
      {'$or': [
        {'lemma.grammar_note.0.@oral_komp': {'$exists': false}},
        {'lemma.grammar_note.0.@oral_komp': ''}
      ]}
    end
  end

  # query for bez SSW
  # @param [Hash] params
  # @return [Hash]
  def cond_bezsw(params)
    if params['bez_sw'].to_s == 'ano' # zadany SW
      {'$or': [
        { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, 'lemma.sw': { '$exists': true, '$not': { '$size': 0}}},
        { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, 'collocations.swcompos': { '$exists': true, '$ne': ''}}
      ]}
    else # nezadany SW
      {'$or': [
        { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, '$or': [{ 'lemma.sw': { '$exists': false}}, { 'lemma.sw': { '$size': 0}}]},
        { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, '$or': [{ 'collocations.swcompos': { '$exists': false}}, { 'collocations.swcompos': ''}], 'collocations.colloc': { '$exists': false}}
      ]}
    end
  end

  # query for neschv. SW
  # @param [Hash] params
  # @return [Hash]
  def cond_nessw(params)
    if params['nes_sw'].to_s == 'ano' # schvaleny SW
      {'$or': [
        { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, 'lemma.@swstatus': 'published'},
        { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, 'collocations.swcompos': { '$exists': true, '$ne': ''}}
      ]}
    else # neschvaleny SW
      {'$or': [
        { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, '$or': [{ 'lemma.@swstatus': { '$exists': false}}, { 'lemma.@swstatus': { '$ne': 'published'}}]},
        { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, '$or': [{ 'collocations.swcompos': { '$exists': false}}, { 'collocations.swcompos': ''}], 'collocations.colloc': { '$exists': false}}
      ]}
    end
  end

  # query for typ hesla
  # @param [Hash] params
  # @return [Hash]
  def cond_typhesla(params)
    if params['typhesla'].to_s == 'ne'
      {'lemma.lemma_type': params['seltyphesla'].to_s}
    else
      {'lemma.lemma_type': {'$ne': params['seltyphesla'].to_s}}
    end
  end

  # query for slov.druh
  # @param [Hash] params
  # @return [Hash]
  def cond_sldruh(params)
    if params['sldruh'].to_s == 'ne'
      {'lemma.grammar_note.0.@slovni_druh': params['slovni_druh'].to_s}
    else
      {'lemma.grammar_note.0.@slovni_druh': {'$ne': params['slovni_druh'].to_s}}
    end
  end

  # query for celni/bocni
  # @param [Hash] params
  # @return [Hash]
  def cond_celnibocni(params, field, param)
    if params[param].to_s == 'ano'
      Hash[field, {'$exists': true, '$ne': ''}]
    else
      {'$or': [
        Hash[field, {'$exists': false}],
        Hash[field, '']
      ]}
    end
  end

  # query for schval. celni/bocni
  # @param [Hash] params
  # @return [Hash]
  def cond_schvcelnibocni(dict, params, field, param)
    vids = []
    $mongo['media'].find({ 'dict': dict.dictcode, 'status': 'published' }).each { |m| vids << m['location'] }
    if params[param].to_s == 'ano'
      Hash[field, {'$in': vids}]
    else
      Hash[field, {'$nin': vids}]
    end
  end

  # query for vyznam write
  # @param [Hash] params
  # @return [Hash]
  def cond_vyznamcs(params)
    if params['vyznamcs'].to_s == 'ano'
      {'$and': [
        {'meanings.status': {'$ne': 'hidden'}},
        {'meanings.text._text': {'$not': {'$exists': false}}}
      ]}
    else
      {'$or': [
        {'meanings.status': {'$ne': 'published'}},
        {'meanings.text._text': {'$exists': false}}
      ]}
    end
  end

  # query for vyznam write
  # @param [Hash] params
  # @return [Hash]
  def cond_vyznamcszad(params)
    if params['vyznamcszad'].to_s == 'ano'
      {'meanings': {'$not': {'$elemMatch': {'$or': [
        {'text._text': {'$exists': false}},
        {'text._text': ''}
      ]}}}}
    else
      {'meanings': {'$elemMatch': {'$or': [
        {'text._text': {'$exists': false}},
        {'text._text': '' }
      ]}}}
    end
  end

  # query for prac.skupina
  # @param [Hash] params
  # @return [Hash]
  def cond_skup(params)
    if params['skup'].to_s == 'ano'
      {'lemma.pracskupina': {'$nin': params['def_skup']}}
    else
      {'lemma.pracskupina': {'$in': params['def_skup']}}
    end
  end

  # query for stav
  # @param [Hash] params
  # @return [Hash]
  def cond_completeness(params)
    if params['completeness'].to_s == 'ano'
      {'lemma.completeness': {'$ne': params['completenessbox']}}
    else
      {'lemma.completeness': params['completenessbox']}
    end
  end
end
