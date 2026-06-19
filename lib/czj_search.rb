# Search & translation lookups (text search, sign-writing key search, cross-dictionary translation).
module CzjSearchMethods
  def get_key_search(search, swelement = 'lemma.sw')
      search_ar = search.split('|')
      search_shape = search_ar[0].to_s.split(',') #tvary
      search_jedno = []
      search_obe_ruzne = []
      search_obe_stejne = []
      $stdout.puts search_ar
      $stdout.puts search_shape
      search_shape.each{|e|
        #jednorucni, rotace jen 0-7
        search_jedno << {
          swelement=>{
            '$elemMatch'=>{
              '$and'=>[
                {'@fsw'=>{'$regex'=>e+'[0-5][0-7]'}},
                {'@fsw'=>{'$not'=>{'$regex'=>'S1[0-9a-f][0-9a-f][0-5][89a-f]'}}},
                {'@fsw'=>{'$not'=>{'$regex'=>'S20[0-4][0-5][89a-f]'}}}
              ]
            }
          }
        }
        #dve ruce, stejne rotace 0-7 + 8-f
        search_obe_stejne << {
          swelement=>{
            '$elemMatch'=>{
              '$and'=>[
                {'@fsw'=>{'$regex'=>e+'[0-5][0-7]'}},
                {'@fsw'=>{'$regex'=>e+'[0-5][89a-f]'}},
              ]
            }
          }
        }
        #dve ruce, ruzne, hledana 0-7 a jina 8-f, nebo hledana 8-f a jina 0-7
        search_obe_ruzne << {
          swelement=>{
            '$elemMatch'=>{
              '$and'=>[{
                '$or'=>[
                  {
                    '$and'=>[
                      {'@fsw'=>{'$regex'=>e+'[0-5][0-7]'}},
                      {'@fsw'=>{'$not'=>{'$regex'=>e+'[0-5][89a-f]'}}},
                      {'$or'=>[
                        {'@fsw'=>{'$regex'=>'S1[0-9a-f][0-9a-f][0-5][89a-f]'}},
                        {'@fsw'=>{'$regex'=>'S20[0-4][0-5][89a-f]'}},
                      ]
                      }
                    ]
                  },
                  {
                    '$and'=>[
                      {'@fsw'=>{'$regex'=>e+'[0-5][89a-f]'}},
                      {'@fsw'=>{'$not'=>{'$regex'=>e+'[0-5][0-7]'}}},
                      {'$or'=>[
                        {'@fsw'=>{'$regex'=>'S1[0-9a-f][0-9a-f][0-5][0-7]'}},
                        {'@fsw'=>{'$regex'=>'S20[0-4][0-5][0-7]'}},
                      ]
                      }
                    ]
                  },
                ]
              }]
            }
          }
        }
      }

      if search_ar[1].to_s != ''
        #pridame umisteni
        search_loc = []
        search_ar[1].split(',').each{|l|
          search_loc << {'@misto'=>{'$regex'=>/(^|;)#{l}/}}
        }
        search_loc = {'$or'=>search_loc}
        $stderr.puts search_loc
        search_jedno.map!{|e| 
          e[swelement]['$elemMatch']['$and'] << search_loc
          e
        }
        search_obe_stejne.map!{|e| 
          e[swelement]['$elemMatch']['$and'] << search_loc
          e
        }
        search_obe_ruzne.map!{|e| 
          e[swelement]['$elemMatch']['$and'] << search_loc
          e
        }
        if search_jedno.length == 0
          search_jedno << {swelement=>{'$elemMatch'=>search_loc}}
        end
        if search_obe_ruzne.length == 0
          search_obe_ruzne << {swelement=>{'$elemMatch'=>search_loc}}
        end
        if search_obe_stejne.length == 0
          search_obe_stejne << {swelement=>{'$elemMatch'=>search_loc}}
        end
      end

      # dvourucni volby, vyber dotazu
      if search_ar[2].to_s != '' and search_ar[2].to_s != 'one'
        search_two = search_ar[2].split(',')
        if search_two.include?('sym')
          search_query = search_obe_stejne
        else
          search_query = search_obe_ruzne
        end
        if search_two.include?('act')
          search_query.map!{|e| 
            e[swelement]['$elemMatch']['$and'] = [] if e[swelement]['$elemMatch']['$and'].nil?
            e[swelement]['$elemMatch']['$and'] << {
              '$or'=>[
                {'@fsw'=>{'$regex'=>'S2[2-9a-f][0-9a-f]2'}},
                {'$and'=>[
                  {'@fsw'=>{'$regex'=>'S2[2-9a-f][0-9a-f]0'}},
                  {'@fsw'=>{'$regex'=>'S2[2-9a-f][0-9a-f]1'}},
                ]
                },
                {'$and'=>[
                  {'@fsw'=>{'$not'=>{'$regex'=>'S2[2-9a-f][0-9a-f]'}}},
                  {'$or'=>[
                    {'@fsw'=>{'$regex'=>'S20[567bcd]'}},
                    {'@fsw'=>{'$regex'=>'S21[123]'}},
                  ]}
                ]
                }
              ]
            }
            e
          }
        end
      else 
        search_query = search_jedno
      end
      $stderr.puts search_query
      search_query
  end

  def search(dictcode, search, type, start=0, limit=nil, more_params=[])
    res = []
    resultcount = 0
    case type
    when 'text'
      search = '' if search == '_'
      search_orig = search.clone
      search = search.downcase
      if search =~ /^[0-9]+$/
        @entrydb.find({'dict': dictcode, 'id': search}).each{|re|
          res << full_entry(re)
          resultcount = 1
        }
      else
        if @write_dicts.include?(dictcode)
          fullids = []
          locale = dictcode
          locale = 'sk' if dictcode == 'sj'
          if search != '*' and search != ''
            search_cond = {'dict': dictcode}
            search_cond_title ={'$or': [{'lemma.title': search}, {'lemma.title_var': search}]}
            search_cond_title[:$or] << {'lemma.title_dia': search}
            search_cond_title[:$or] << {'lemma.gram.form._text': search}
            search_cond_title[:$or] << {'lemma.grammar_note.variant._text': {'$regex': /(^| )#{search}/i}}
            search_cond_title[:$or] << {'lemma.style_note.variant._text': {'$regex': /(^| )#{search}/i}}
            search_cond[:$and] = [search_cond_title]
            if more_params['slovni_druh'].to_s != ''
              search_cond[:$and] << {'lemma.grammar_note.@slovni_druh'=> more_params['slovni_druh'].to_s}
            end
            if more_params['oblast'].to_s != ''
              search_cond[:$and] << {'lemma.grammar_note.@region'=> more_params['oblast'].to_s}
            end
            if more_params['stylpriznak'].to_s != ''
              search_cond[:$and] << {'lemma.style_note.@stylpriznak'=> more_params['stylpriznak'].to_s}
            end
            if search_cond_title and more_params['slovni_druh'].to_s == '' and more_params['oblast'].to_s == '' and more_params['stylpriznak'].to_s == ''
              search_cond[:$or] = search_cond_title[:$or]
            end
            $stdout.puts search_cond
            cursor = @entrydb.find(search_cond, :sort => {'lemma.title'=>1})
            fullcount = cursor.count_documents
            cursor.each{|re|
              if more_params['slovni_druh'].to_s == '' and more_params['oblast'].to_s == '' and more_params['stylpriznak'].to_s == ''
                res << re if fullcount > start
                fullids << re['id']
              end
            }
            search_cond = {'dict': dictcode, 'id': {'$nin': fullids}}
            search_cond_title = {'$or': [{'lemma.title': {'$regex': /^#{search}/i}}]}
            search_cond_title[:$or] << {'lemma.title': {'$regex': /(^| )#{search}/i}}
          else
            fullcount = 0
            search_cond = {'dict': dictcode, '$and': [{'lemma.title': {'$exists': true}}, {'lemma.title': {'$ne': ''}}]}
          end

          if more_params['slovni_druh'].to_s != '' or more_params['stylpriznak'].to_s != '' or more_params['oblast'].to_s != ''
            if search != '' and search != '*'
              search_cond[:$and] = [search_cond_title]
            end
            if search_cond[:$and]
              if more_params['slovni_druh'].to_s != ''
                search_cond[:$and] << {'lemma.grammar_note.@slovni_druh'=> more_params['slovni_druh'].to_s}
              end
              if more_params['oblast'].to_s != ''
                search_cond[:$and] << {'lemma.grammar_note.@region'=> more_params['oblast'].to_s}
              end
              if more_params['stylpriznak'].to_s != ''
                search_cond[:$and] << {'lemma.style_note.@stylpriznak'=> more_params['stylpriznak'].to_s}
              end
            end
          end
          if search != '' and search != '*' and more_params['slovni_druh'].to_s == '' and more_params['stylpriznak'].to_s == '' and more_params['oblast'].to_s == ''
            search_cond[:$or] = search_cond_title[:$or]
          end
          $stdout.puts search_cond
          start = start - fullcount if start > 0
          cursor = @entrydb.find(search_cond, {:collation => {'locale'=>locale}, :sort => {'lemma.title'=>1}})
          resultcount = fullcount + cursor.count_documents
          cursor = cursor.skip(start)
          if limit.to_i > 0
            limit = limit - fullcount if fullcount > start
            cursor = cursor.limit(limit)
          end
          $stdout.puts 'START='+start.to_s
          $stdout.puts 'LIMIT='+limit.to_s
          
          cursor.each{|re|
            res << re #full_entry(re)
          }
        else
          if search != '*' and search != '' and search != '_'
            search_in = 'cs'
            search_in = @dict_info[dictcode]['search_in'] unless @dict_info[dictcode]['search_in'].nil?
            csl = [search]
            search_cond = {'source_dict': search_in, 'entry_text': {'$regex': /(^| )#{search}/i}, 'target': dictcode}
            $mongo['relation'].find(search_cond).each{|rl|
              csl << rl['target_id']
            }
            search_cond = {'source_dict': dictcode, 'source_id': {'$in': csl}}
          else
            search_cond = {'source_dict': dictcode}
          end
          if more_params['slovni_druh'].to_s != ''
            search_cond['source_pos'] = more_params['slovni_druh'].to_s
          end
          if more_params['oblast'].to_s != ''
            search_cond['$or'] = CzjSearchQuery.get_search_cond_oblast('source_region', more_params['oblast'])
          end
          if more_params['stylpriznak'].to_s != ''
            search_cond['source_priznak'] = more_params['stylpriznak'].to_s
          end
          pipeline = [
            {'$match': search_cond},
            {'$group': {'_id': '$source_id', 'source_id': {'$first': '$source_id'}, 'source_dict': {'$first': '$source_dict'}, 'source_video': {'$first': '$source_video'}, 'source_sw': {'$first': '$source_sw'}, 'sort_key': {'$first': '$sort_key'}}}
          ]

          collate = {:collation => {'locale' => 'cs', 'numericOrdering'=>true}} 
          $stdout.puts search_cond
          $mongo['relation'].aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
            resultcount = re['total'].to_i
          }
          pipeline << {'$sort': {'sort_key': -1}}
          pipeline << {'$skip' => start.to_i}
          pipeline << {'$limit' => limit.to_i} if limit.to_i > 0
          cursor = $mongo['relation'].aggregate(pipeline, collate)
          cursor.each{|entry|
            entry['dict'] = entry['source_dict']
            entry['id'] = entry['source_id']
            entry['media'] = {}
            entry['lemma'] = {}
            if entry['source_video']
              entry['media']['video_front'] = entry['source_video'] 
              entry['lemma']['video_front'] = entry['source_video']['location']
            end
            if entry['source_sw']
              entry['lemma']['swmix'] = entry['source_sw']
            end
            res << entry
          }
        end
      end
    when 'key'
      search_query = {'dict'=>dictcode, '$and'=> [{'$or'=>get_key_search(search)}]}
      if more_params['slovni_druh'].to_s != ''
        search_query['lemma.grammar_note.@slovni_druh'] = more_params['slovni_druh'].to_s
      end
      if more_params['stylpriznak'].to_s != ''
        search_query['lemma.style_note.@stylpriznak'] = more_params['stylpriznak'].to_s
      end
      if more_params['oblast'].to_s != ''
        search_query['$and'] << {'$or' => CzjSearchQuery.get_search_cond_oblast('lemma.grammar_note.@region', more_params['oblast'])}

      end
      $stdout.puts search_query
      cursor = $mongo['entries'].find(search_query, {:sort => {'sort_key' => -1}})
      resultcount = cursor.count_documents
      cursor = cursor.skip(start)
      cursor = cursor.limit(limit) if limit.to_i > 0
      cursor.each{|e|
        res << add_media(e, true)
      }
    else
      return {'count' => 0, 'entries' => []}
    end
    { 'count'=> resultcount, 'entries'=> res, 'is_edit'=> ($is_edit or $is_admin)}
  end

  def translate2(source, target, search, type, start=0, limit=nil, more_params={})
    res = []
    resultcount = 0
    $stderr.puts more_params
    $stderr.puts type
    case type
    when 'text'
      search = search.downcase
      if search == ''
        search_cond = {'source_dict': source, 'target': target}
      elsif search =~ /^[0-9]+$/
        resultcount = 0
        @entrydb.find({'dict': dictcode, 'id': search, 'meanings.relation.target': target}).each{|re|
          entry = add_rels(re, false, 'translation', target)
          entry = @sw.get_sw(entry)
          if entry['meanings']
            entry['meanings'].each{|mean|
              if mean['relation']
                mean['relation'].each{|rel|
                  if rel['type'] == 'translation' and rel['target'] == target
                    rel['source_dict'] = dictcode
                    rel['source_id'] = entry['id']
                    rel['source_title'] = entry['lemma']['title'] if entry['lemma']['title']
                    rel['source_video'] = get_media_location(entry['lemma']['video_front'], entry['dict']) if entry['lemma']['video_front'].to_s != ''
                    rel['source_sw'] = entry['lemma']['swmix'] if entry['lemma']['swmix']
                    rel['target_id'] = rel['entry']['id']
                    rel['target_title'] = rel['entry']['lemma']['title'] if rel['entry']['lemma']['title']
                    rel['target_sw'] = rel['entry']['lemma']['swmix'] if rel['entry']['lemma']['swmix']
                    rel['target_video'] = get_media_location(rel['entry']['lemma']['video_front'], rel['target']) if rel['entry']['lemma']['video_front'].to_s != ''
                    res << rel
                  end
                }
              end
            }
          end
          resultcount = res.length
        }
        return {'count'=> resultcount, 'relations'=> res}
      else
        if @write_dicts.include?(source)
          locale = source
          locale = 'sk' if source == 'sj'
          collate = {:collation => {'locale' => locale}, :sort => {'sort_title' => 1, 'target_title' => 1, 'sort_key' => -1}}
          search_conds = []
          search_conds << {'source_dict': source, 'entry_text': {'$regex': /(^| )#{search}/i}, 'target': target}
          search_conds << {'source_dict': target, 'meaning_id': {'$regex': /(^| )#{search}/i}, 'target': source}
          search_cond = {'$or': search_conds,}
        else
          search_in = 'cs'
          search_in = @dict_info[dictcode]['search_in'] unless @dict_info[dictcode]['search_in'].nil?
          csl = [search]
          search_cond = {'source_dict': search_in, 'entry_text': {'$regex': /(^| )#{search}/i}, 'target': dictcode}
          $mongo['relation'].find(search_cond).each{|rl|
            csl << rl['target_id']
          }
          search_cond = {'source_dict': dictcode, 'target': target, 'source_id': {'$in': csl}}
          collate = {:collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'sort_key' => -1}}
        end
      end
    when 'key'
      search_cond = {'source_dict': dictcode, 'target': target, 'type': 'translation', '$or': get_key_search(search, 'source_sw')}
      collate = {:collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'sort_key' => -1}}
    end
    if more_params['slovni_druh'].to_s != ''
      search_cond['target_pos'] = more_params['slovni_druh'].to_s
    end
    if more_params['oblast'].to_s != ''
      search_cond['$and'] = [{'$or' => CzjSearchQuery.get_search_cond_oblast('target_region', more_params['oblast'])}]
    end
    if more_params['stylpriznak'].to_s != ''
      search_cond['target_priznak'] = more_params['stylpriznak'].to_s
    end
    if not $is_edit and not $is_admin
      search_cond['status'] = 'published'
    end
    $stderr.puts search_cond
    cursor = $mongo['relation'].find(search_cond, collate)
    resultcount = cursor.count_documents
    cursor = cursor.skip(start)
    cursor = cursor.limit(limit) if limit.to_i > 0
    cursor.each{|entry|
      res << entry
    }
    { 'count'=> resultcount, 'relations'=> res}
  end

end
