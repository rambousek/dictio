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
      vids = []
      $mongo['media'].find({'dict': dict.dictcode, 'status': 'published'}).each{|m| vids << m['location']}
      if params['schvcelni'].to_s == 'ano'
        search_cond << {'lemma.video_front': {'$in': vids}}
      else
        search_cond << {'lemma.video_front': {'$nin': vids}}
      end
    end

    # bocni video schvalene
    if params['schvbocni'].to_s != ''
      vids = []
      $mongo['media'].find({'dict': dict.dictcode, 'status': 'published'}).each{|m| vids << m['location']}
      if params['schvbocni'].to_s == 'ano'
        search_cond << {'lemma.video_side': {'$in': vids}}
      else
        search_cond << {'lemma.video_side': {'$nin': vids}}
      end
    end

    # celni video zadane
    if params['celni'].to_s != ''
      if params['celni'].to_s == 'ano'
        search_cond << {'lemma.video_front': {'$exists': true, '$ne': ''}}
      else
        search_cond << {'$or': [{'lemma.video_front': {'$exists': false}}, {'lemma.video_front': ''}]}
      end
    end

    # bocni video zadane
    if params['bocni'].to_s != ''
      if params['bocni'].to_s == 'ano'
        search_cond << {'lemma.video_side': {'$exists': true, '$ne': ''}}
      else
        search_cond << {'$or': [{'lemma.video_side': {'$exists': false}}, {'lemma.video_front': ''}]}
      end
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
      if params['vyznamcs'].to_s == 'ano'
        search_cond << {'$and':[{'meanings.status':{'$ne':'hidden'}},{'meanings.text._text':{'$not':{'$exists':false}}}]}
      else
        search_cond << {'$or':[{'meanings.status':{'$ne':'published'}},{'meanings.text._text':{'$exists':false}}]}
      end
    end

    # write, zadana definice
    if params['vyznamcszad'].to_s != ''
      if params['vyznamcszad'].to_s == 'ano'
        search_cond << {'meanings': {'$not': {'$elemMatch': {'$or': [
          {'text._text': {'$exists': false}},
          {'text._text': ''}
        ]}}}}
      else
        search_cond << {'meanings': {'$elemMatch': {'$or': [
          {'text._text': {'$exists': false}},
          {'text._text': ''}
        ]}}}
      end
    end

    # pracovni skupina
    if params['skup'].to_s != '' and params['def_skup'].length > 0
      if params['skup'].to_s == 'ano'
        search_cond << {'lemma.pracskupina': {'$nin': params['def_skup']}}
      else
        search_cond << {'lemma.pracskupina': {'$in': params['def_skup']}}
      end
    end

    # zverejnovani
    if params['completeness'].to_s != '' and params['completenessbox'].to_s != ''
      if params['completeness'].to_s == 'ano'
        search_cond << {'lemma.completeness': {'$ne': params['completenessbox']}}
      else
        search_cond << {'lemma.completeness': params['completenessbox']}
      end
    end

    # schvaleny preklad
    $dict_info.each{|code, _|
      if params['pubtrans'+code].to_s != '' or params['translation'+code].to_s != ''
        trans_cond = trans_cond(params['pubtrans'+code].to_s, params['translation'+code].to_s, code)
        search_cond << trans_cond if trans_cond != nil
      end
    }

    # synonym
    if params['pubsynonym'].to_s != '' or params['synonym'].to_s != ''
      trans_cond = trans_cond(params['pubsynonym'].to_s, params['synonym'].to_s, dict.dictcode, 'synonym')
      search_cond << trans_cond if trans_cond != nil
    end

    # komentare
    if params['koment'].to_s != '' and params['komentbox'].to_s != ''
      koment_ids = []
      koment_user = params['koment_user'].to_s
      komentbox = params['komentbox'].to_s
      koment_moje = params['koment_moje'].to_s
      koment_cond = {}
      koment_aggr = false

      if komentbox == ''
        if koment_user != ''
          koment_cond = {'user': koment_user}
        else
          if koment_moje == 'on'
            koment_cond = {'user': user_info['login']}
          end
        end
      else
        if komentbox == 'video'
          if koment_user != ''
            koment_cond = {'user': koment_user, 'box': {'$regex': /^video/}}
          else
            if koment_moje == 'on'
              koment_cond = {'user': user_info['login'], 'box': {'$regex': /^video/}}
            else
              koment_cond = {'box': {'$regex': /^video/}}
            end
          end
        elsif komentbox == 'vyznam'
          if koment_user != ''
            koment_cond = {'user': koment_user, '$or': [{'box': {'$regex': /^videoD/}}, {'$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}
          else
            if koment_moje == 'on'
              koment_cond = {'user': user_info['login'], '$or': [{'box': {'$regex': /^videoD/}}, {'$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}
            else
              koment_cond = {'$or': [{'box': {'$regex': /^videoD/}}, {'$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}]}
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
      if koment_aggr
        $mongo['koment'].aggregate(koment_cond).each{|kom|
          koment_ids << kom['_id']['entry']
        }
      else
        koment_cond['dict'] = dict.dictcode
        $mongo['koment'].find(koment_cond).each{|kom|
          koment_ids << kom['entry']
        }
      end
      if params['koment'].to_s == 'ano'
        search_cond << {'id': {'$nin': koment_ids}}
      else
        search_cond << {'id': {'$in': koment_ids}}
      end
    end

    # zadany SW
    if params['bez_sw'].to_s != ''
      if params['bez_sw'].to_s == 'ano' # zadany SW
        search_cond << {'$or': [
          { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, 'lemma.sw': { '$exists': true, '$not': { '$size': 0}}},
          { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, 'collocations.swcompos': { '$exists': true, '$ne': ''}}
        ]}
      else # nezadany SW
        search_cond << {'$or': [
          { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, '$or': [{ 'lemma.sw': { '$exists': false}}, { 'lemma.sw': { '$size': 0}}]},
          { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, '$or': [{ 'collocations.swcompos': { '$exists': false}}, { 'collocations.swcompos': ''}], 'collocations.colloc': { '$exists': false}}
        ]}
      end
    end

    # schvaleny SW
    if params['nes_sw'].to_s != ''
      if params['nes_sw'].to_s == 'ano' # schvaleny SW
        search_cond << {'$or': [
          { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, 'lemma.@swstatus': 'published'},
          { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, 'collocations.swcompos': { '$exists': true, '$ne': ''}}
        ]}
      else # neschvaleny SW
        search_cond << {'$or': [
          { 'lemma.lemma_type': {'$in': %w[single derivat kompozitum] }, '$or': [{ 'lemma.@swstatus': { '$exists': false}}, { 'lemma.@swstatus': { '$ne': 'published'}}]},
          { 'lemma.lemma_type': {'$in': %w[fingerspell collocation] }, '$or': [{ 'collocations.swcompos': { '$exists': false}}, { 'collocations.swcompos': ''}], 'collocations.colloc': { '$exists': false}}
        ]}
      end
    end

    # typ hesla
    if params['typhesla'].to_s != '' and params['seltyphesla'].to_s != ''
      if params['typhesla'].to_s == 'ne'
        search_cond << {'lemma.lemma_type': params['seltyphesla'].to_s}
      else
        search_cond << {'lemma.lemma_type': {'$ne': params['seltyphesla'].to_s}}
      end
    end

    # slovni druh
    if params['sldruh'].to_s != '' and params['slovni_druh'].to_s != ''
      if params['sldruh'].to_s == 'ne'
        search_cond << {'lemma.grammar_note.0.@slovni_druh': params['slovni_druh'].to_s}
      else
        search_cond << {'lemma.grammar_note.0.@slovni_druh': {'$ne': params['slovni_druh'].to_s}}
      end
    end

    # mluv komp
    if params['mluvkomp'].to_s != ''
      if params['mluvkomp'].to_s == 'ano'
        search_cond << {'lemma.grammar_note.0.@mluv_komp': {'$exists': true, '$ne': ''}}
      else
        search_cond << {'$or': [
          {'lemma.grammar_note.0.@mluv_komp': {'$exists': false}},
          {'lemma.grammar_note.0.@mluv_komp': ''}
        ]}
      end
    end

    # oral komp
    if params['oralkomp'].to_s != ''
      if params['oralkomp'].to_s == 'ano'
        search_cond << {'lemma.grammar_note.0.@oral_komp': {'$exists': true, '$ne': ''}}
      else
        search_cond << {'$or': [
          {'lemma.grammar_note.0.@oral_komp': {'$exists': false}},
          {'lemma.grammar_note.0.@oral_komp': ''}
        ]}
      end
    end

    # MK/OK
    if params['mkok'].to_s != ''
      if params['mkok'].to_s == 'ano'
        search_cond << {'$or': [
          {'lemma.grammar_note.0.@mluv_komp': {'$exists': true, '$ne': ''}},
          {'lemma.grammar_note.0.@oral_komp': {'$exists': true, '$ne': ''}}
        ]}
      else
        search_cond << {'$and': [
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

    # sign, schvaleny priklad
    if params['usage'].to_s != ''
      if params['usage'].to_s == 'ano'
        search_cond << {'meanings': {'$not': {'$elemMatch': {'$or': [
          {'usages': {'$size': 0}},
          {'usages': {'$exists': false}},
          {'usages': {'$elemMatch': {'$or': [
            {'status': {'$ne': 'published'}},
            {'text.file.@media_id': ''}
          ]}}}
        ]}}}}
      else
        search_cond << {'$or': [
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

    # sign, zadany priklad
    if params['usagevid'].to_s != ''
      if params['usagevid'].to_s == 'ano'
        search_cond << {'meanings': {'$not': {'$elemMatch': {'$or': [
          {'usages': {'$size': 0}},
          {'usages': {'$exists': false}},
          {'usages.text.file.@media_id': {'$exists': false}},
          {'usages.text.file.@media_id': ''}
        ]}}}}
      else
        search_cond << {'meanings': {'$elemMatch': {'$or': [
          {'usages': {'$size': 0}},
          {'usages': {'$exists': false}},
          {'usages.text.file.@media_id': {'$exists': false}},
          {'usages.text.file.@media_id': ''}
        ]}}}
      end
    end

    # write, schvaleny priklad
    if params['usagecs'].to_s != ''
      if params['usagecs'].to_s == 'ano'
        search_cond << {'meanings': {'$not': {'$elemMatch': {'$or': [
          {'usages': {'$size': 0}},
          {'usages': {'$exists': false}},
          {'usages': {'$elemMatch': {'$or': [
            {'status': {'$ne': 'published'}},
            {'text._text': ''}
          ]}}}
        ]}}}}
      else
        search_cond << {'$or': [
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

    # write, zadany priklad
    if params['usagecszad'].to_s != ''
      if params['usagecszad'].to_s == 'ano'
        search_cond << {'meanings': {'$not': {'$elemMatch': {'$or': [
          {'usages': {'$size': 0}},
          {'usages': {'$exists': false}},
          {'usages.text._text': {'$exists': false}},
          {'usages.text._text': ''}
        ]}}}}
      else
        search_cond << {'meanings': {'$elemMatch': {'$or': [
          {'usages': {'$size': 0}},
          {'usages': {'$exists': false}},
          {'usages.text._text': {'$exists': false}},
          {'usages.text._text': ''}
        ]}}}
      end
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

    #'region',
    #'bez_hns',
    #'nes_hns',
    #'rucne',
    #'vztahy',
    #'videa',
    #'noupdate',
    #'videa2',
    #'artik',
    #'coll',
    #'autocomp',
    #'autocompbox',
    #'relpub',
    #'texttranslationen',
    #'trpriklad'


    return search_cond, trans_used
  end

  def trans_cond(pubtrans, trans, target, type="translation")
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

end
