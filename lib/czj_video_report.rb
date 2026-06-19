# Video report listing & CSV export.
module CzjVideoReport
  def get_videoreport(params, start=0, limit=nil)
    report = {'entries'=>[], 'resultcount'=>0, 'query'=>{}}
    search_cond = {'dict': @dictcode}
    if params['type_a'].to_s == '1' or params['type_b'].to_s == '1' or params['type_d'].to_s == '1' or params['type_k'].to_s == '1' or params['type_g'].to_s == '1' or params['type_s'].to_s == '1'
      types = []
      types << 'sign_front' if params['type_a'].to_s == '1'
      types << 'sign_side' if params['type_b'].to_s == '1'
      types << 'sign_definition' if params['type_d'].to_s == '1'
      types << 'sign_usage_example' if params['type_k'].to_s == '1'
      types << 'sign_grammar' if params['type_g'].to_s == '1'
      types << 'sign_style' if params['type_s'].to_s == '1'
      search_cond['type'] = {'$in': types}
    end
    search_cond['id_meta_author'] = params['author'] if params['author'].to_s != ''
    search_cond['id_meta_source'] = params['source'] if params['source'].to_s != ''
    search_cond['id_meta_copyright'] = params['copy'] if params['copy'].to_s != ''
    search_cond['status'] = 'published' if params['status'].to_s == 'published'
    search_cond['status'] = {'$ne': 'published'} if params['status'].to_s == 'hidden'
    if params['def_skup'].to_s != ''
      skup_vid = []
      @entrydb.find({'dict': @dictcode, 'lemma.pracskupina': params['def_skup']}).each{|res|
        skup_vid << res['lemma']['video_front'] if res['lemma']['video_front']
        skup_vid << res['lemma']['video_side'] if res['lemma']['video_side']
      }
      search_cond['location'] = {'$in': skup_vid}
    end
    $stdout.puts search_cond
    cursor = $mongo['media'].find(search_cond, :collation => {'locale' => 'cs'}, :sort => {'location' => 1})
    report['resultcount'] = cursor.count_documents
    cursor = cursor.skip(start)
    cursor = cursor.limit(limit) if limit.to_i > 0
    cursor.each{|res|
      res['entries_used'] = []
      @entrydb.find({'dict': @dictcode, '$or': [
        {'lemma.video_front': res['location']},
        {'lemma.video_side': res['location']},
        {'meanings.text.file.@media_id': res['id']},
        {'meanings.usages.text.file.@media_id': res['id']},
        {'lemma.grammar_note._text': {'$regex': '\[media_id=' + res['id'] + '\]'}},
        {'lemma.style_note._text': {'$regex': '\[media_id=' + res['id'] + '\]'}}
      ]}, {'id': 1}).each{|entry|
        res['entries_used'] << entry['id']
      }
      report['entries'] << res
    }
    report['query'] = search_cond
    return report
  end

  def export_videoreport(params)
    report = {'entries'=>[], 'resultcount'=>0, 'query'=>{}}
    search_cond = {'dict': @dictcode}
    if params['type_a'].to_s == '1' or params['type_b'].to_s == '1' or params['type_d'].to_s == '1' or params['type_k'].to_s == '1' or params['type_g'].to_s == '1' or params['type_s'].to_s == '1'
      types = []
      types << 'sign_front' if params['type_a'].to_s == '1'
      types << 'sign_side' if params['type_b'].to_s == '1'
      types << 'sign_definition' if params['type_d'].to_s == '1'
      types << 'sign_usage_example' if params['type_k'].to_s == '1'
      types << 'sign_grammar' if params['type_g'].to_s == '1'
      types << 'sign_style' if params['type_s'].to_s == '1'
      search_cond['type'] = {'$in': types}
    end
    search_cond['id_meta_author'] = params['author'] if params['author'].to_s != ''
    search_cond['id_meta_source'] = params['source'] if params['source'].to_s != ''
    search_cond['id_meta_copyright'] = params['copy'] if params['copy'].to_s != ''
    search_cond['status'] = 'published' if params['status'].to_s == 'published'
    search_cond['status'] = {'$ne': 'published'} if params['status'].to_s == 'hidden'
    if params['def_skup'].to_s != ''
      skup_vid = []
      @entrydb.find({'dict': @dictcode, 'lemma.pracskupina': params['def_skup']}).each{|res|
        skup_vid << res['lemma']['video_front'] if res['lemma']['video_front']
        skup_vid << res['lemma']['video_side'] if res['lemma']['video_side']
      }
      search_cond['location'] = {'$in': skup_vid}
    end
    $stdout.puts search_cond

    cursor = $mongo['mediaExport'].find(search_cond)
    cursor.each{|res|
      $stderr.puts 'res'
    $stderr.puts Time.now.to_s
      $stderr.puts res['location']
      res2 = get_media_location(res['location'], res['dict'])
      ri = [res['location']]
      entries_used = []
      ri << res['entryDocs'].select{|e| e['dict'] == res['dict']}.collect{|e| e['id']}.join(', ')
      ri << entries_used.join(', ')
      ri << res['id_meta_author']
      ri << res['id_meta_source']
      ri << res['id_meta_copyright']
      if res2 and res2['created_at']
        ri << res2['created_at'][0..10]
      end
      report['entries'] << ri.join(';')
    }
    return report['entries']
  end

end
