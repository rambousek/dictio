class CZJDict < Object
  #attr_accessor :servlet
  attr_accessor :dictcode
  attr_accessor :write_dicts
  attr_accessor :sign_dicts
  attr_accessor :dict_info

  def initialize(dictcode)
    @dictcode = dictcode 
    #@servlet = CZJServlet
    @collection = $mongo[dictcode]
    @entrydb = $mongo['entries']
  end

  def getdoc(id, add_rev=true)
    $stdout.puts id
    $stdout.puts @dictcode
    
    $stdout.puts 'START getdoc '+Time.now.to_s
    data = getone(@dictcode, id)
    $stdout.puts data
    if data != nil
      entry = full_entry(data, add_rev)
      entry = add_rels(entry, add_rev)
      $stdout.puts 'END getdoc '+Time.now.to_s
      return entry
    else
      return {}
    end
  end

  def getone(dict, id)
    $stdout.puts 'START getone '+Time.now.to_s
    data = @entrydb.find({'id': id, 'dict': dict, 'empty': {'$exists': false}}).first
    $stdout.puts 'END getone '+Time.now.to_s
    return data
  end

  def get_comments(id, type, exact=true)
    coms = []
    query = {'dict': @dictcode, 'entry': id}
    if type != ''
      if exact
        query['box'] = type 
      else
        query['box'] = {'$regex':'.*'+type+'.*'}
      end
    end
    $mongo['koment'].find(query, :sort=>{'time'=>-1}).each{|com|
      coms << com
    }
    return {'comments':coms}
  end

  def full_entry(entry, add_rev=true)
    $stdout.puts 'START fullentry '+Time.now.to_s
    entry = add_media(entry)
    entry, cu = add_colloc(entry, add_rev)
    entry = get_sw(entry)
    $stdout.puts 'END fullentry '+Time.now.to_s
    return entry
  end

  def add_colloc(entry, add_rev=true, collocs_used=[])
    if entry['collocations'] and entry['collocations']['colloc']
      entry['collocations']['entries'] = []
      entry['collocations']['colloc'].uniq.each{|coll|
        if coll != entry['id'] and not collocs_used.include?(coll)
          collocs_used << coll
          ce = getone(entry['dict'], coll)
          unless ce.nil?
            ce, collocs_used = add_colloc(ce, add_rev, collocs_used)
            ce = get_sw(ce)
            entry['collocations']['entries'] << ce
          end
        end
      }
    end

    if add_rev
      entry['revcollocations'] = {} if entry['revcollocations'].nil?
      entry['revcollocations']['entries'] = []
      if @write_dicts.include?(entry['dict'])
        locale = entry['dict']
        locale = 'sk' if entry['dict'] == 'sj'
        collate = {:collation => {'locale' => locale}, :sort => {'lemma.title' => 1}}
      else
        collate = { :sort => {'id'=>1}}
      end

      @entrydb.find({'dict': entry['dict'], 'collocations.colloc': entry['id'], 'lemma.lemma_type': 'collocation'}, collate).each{|ce|
        ce = add_media(ce)
        ce = get_sw(ce)
        entry['revcollocations']['entries'] << ce
      }
    end

    return entry, collocs_used
  end

  def get_sw(entry)
    if @write_dicts.include?(entry['dict'])
      return entry
    end
    $stdout.puts 'GETSW, entry ' + entry['id'].to_s
    swdoc = $mongo['sw'].find({'id': entry['id'], 'dict': entry['dict']})
    if swdoc.first and swdoc.first['swmix'] and swdoc.first['swmix'].length > 0
      entry['lemma']['swmix'] = swdoc.first['swmix']
    end
    return entry
  end

  def cache_all_sw(delete_existing=true)
    count = {'single' => 0, 'compos' => 0, 'deleted' => 0}
    swids = []
    if delete_existing
      res = $mongo['sw'].find({'dict': @dictcode}).delete_many
      count['deleted'] = res.deleted_count
    end
    res = $mongo['sw'].find({'dict': @dictcode}).each{|sw|
      swids << sw['id']
    }
    # nejprve jednoduche hesla
    @entrydb.find({'dict': @dictcode, 'id': {'$nin': swids}, 'lemma.lemma_type': 'single'}).each{|entry|
      count['single'] += 1
      cache_sw(entry)
    }

    # slozene hesla, bez casti
    @entrydb.find({'dict': @dictcode, 'id': {'$nin': swids}, 'lemma.lemma_type': {'$ne': 'single'}, 'collocations.colloc': []}).each{|entry|
      count['compos'] += 1
      cache_sw(entry)
    }
    # slozene hesla, s castmi
    @entrydb.find({'dict': @dictcode, 'id': {'$nin': swids}, 'lemma.lemma_type': {'$ne': 'single'}, 'collocations.colloc': {'$exists': true, '$ne': []}}).each{|entry|
      count['compos'] += 1
      cache_sw(entry)
    }
    
    return count
  end

  def cache_sw(entry)
    if @write_dicts.include?(entry['dict'])
      return entry
    end
    $stdout.puts 'CACHE SW, entry ' + @dictcode + ' ' + entry['id'].to_s
    entries_used = [entry['id']]
    entry['lemma']['swmix'] = []
    if ['collocation','derivat','kompozitum','fingerspell'].include?(entry['lemma']['lemma_type'])
      if entry['collocations']
        # pridat colloc
        entry, collocs_used = add_colloc(entry, false)
        if entry['collocations']['entries']
          entry['collocations']['entries'].each{|ce|
            # nejdriv cache SW pro colloc, kdyz nemaji
            if ce['lemma']['swmix'].nil? and not collocs_used.include?(ce['id'])
              collocs_used = cache_sw(ce)
              ce = get_sw(ce)
            end
          }
        end

        # spojeni
        if entry['collocations']['swcompos'].to_s == ''
          # prazdne SW compos
          if entry['lemma']['lemma_type'] == 'derivat' or entry['lemma']['lemma_type'] == 'kompozitum'
            # derivat/komp = zustava hlavni SW
            entry['lemma']['swmix'] = entry['lemma']['sw'].dup
          else
            # spojeni/spell = SW casti
            if entry['collocations']['entries']
              entry['collocations']['entries'].each{|ce|
                entries_used << ce['id']
                if ce['lemma'] and ce['lemma']['swmix']
                  ce['lemma']['swmix'].each{|swc| entry['lemma']['swmix'] << swc.dup}
                end
              }
            end
          end
        else
          #vyplnene SW compos
          entry['collocations']['swcompos'].split(',').each{|swid|
            swid.strip!
            $stdout.puts 'sw part '+swid
            if swid[0,2].upcase == 'SW'
              #copy from this entry
              swn = swid[2..-1].to_i-1
              entry['lemma']['swmix'] << entry['lemma']['sw'][swn].dup unless entry['lemma']['sw'][swn].nil?
            elsif swid.upcase =~ /^[A-Z]$/
              #copy from this entry
              $stdout.puts 'get SW char from this entry ' + swid + ' = ' + (swid[0].ord-65).to_s
              swn = swid[0].ord-65
              entry['lemma']['swmix'] << entry['lemma']['sw'][swn].dup unless entry['lemma']['sw'].nil? or entry['lemma']['sw'][swn].nil?
            else
              # copy from part
              if swid.upcase =~ /[A-Z]/
                # copy one char
                match = /([0-9]+)([A-Z]+)/.match(swid.upcase)
                unless match.nil?
                  $stdout.puts 'copy char '+swid+' ('+(match[1].to_i-1).to_s+':'+(match[2][0].ord-65).to_s+')'
                  if entry['collocations'] and entry['collocations']['entries']
                    unless entry['collocations']['entries'][match[1].to_i-1].nil?
                      unless entry['collocations']['entries'][match[1].to_i-1]['lemma']['sw'].first.nil?
                        entries_used << entry['collocations']['entries'][match[1].to_i-1]['id']
                        entry['lemma']['swmix'] << entry['collocations']['entries'][match[1].to_i-1]['lemma']['sw'][match[2][0].ord-65].dup unless entry['collocations']['entries'][match[1].to_i-1]['lemma']['sw'][match[2][0].ord-65].nil?
                      else
                        entries_used << entry['collocations']['entries'][match[1].to_i-1]['id']
                        entry['lemma']['swmix'] << entry['collocations']['entries'][match[1].to_i-1]['lemma']['swmix'][match[2][0].ord-65].dup unless entry['collocations']['entries'][match[1].to_i-1]['lemma']['swmix'][match[2][0].ord-65].nil?
                      end
                    end
                  end
                end
              else
                # copy full
                $stdout.puts 'copy full '+swid
                if entry['collocations'] and entry['collocations']['entries']
                  unless entry['collocations']['entries'][swid.to_i-1].nil?
                    if entry['collocations']['entries'][swid.to_i-1]['lemma']['swmix'].nil? or entry['collocations']['entries'][swid.to_i-1]['lemma']['swmix'].size == 0
                      entries_used << entry['collocations']['entries'][swid.to_i-1]['id']
                      entry['collocations']['entries'][swid.to_i-1]['lemma']['sw'].each{|swel|
                        entry['lemma']['swmix'] << swel.dup
                      }
                    else
                      entries_used << entry['collocations']['entries'][swid.to_i-1]['id']
                      entry['collocations']['entries'][swid.to_i-1]['lemma']['swmix'].each{|swel|
                        entry['lemma']['swmix'] << swel.dup
                      }
                    end
                  end
                end
              end
            end
          }
        end
      end
    else
      # jednoduche
      if entry['lemma']['sw']
        if entry['lemma']['sw'].find{|sw| sw['@primary'].to_s == 'true'}
          # primary SW
          entry['lemma']['swmix'] = entry['lemma']['sw'].select{|sw| sw['@primary'].to_s == 'true'}
        else
          # no primary SW
          entry['lemma']['swmix'] = entry['lemma']['sw'].dup
        end
      end
    end
    $mongo['sw'].insert_one({'id': entry['id'], 'dict': entry['dict'], 'swmix': entry['lemma']['swmix'], 'entries_used': entries_used})
    return entry
  end

  def get_media(media_id, dict, add_entries=true)
    media = $mongo['media'].find({'id': media_id, 'dict': dict})
    if media.first
      media_info = media.first
      if add_entries
        entries = $mongo['entries'].find({'dict': dict, 'lemma.video_front': media_info['location']})
        if entries.first
          media_info['main_for_entry'] = entries.first
        end
      end
      return media_info
    else
      return {}
    end
  end

  def get_media_location(media_id, dict)
    media = $mongo['media'].find({'location': media_id, 'dict': dict})
    if media.first
      return media.first
    else
      return {}
    end
  end

  def add_media(entry, main_only=false)
    entry['media'] = {}
    if not main_only
      if entry['meanings']
        entry['meanings'].each{|mean|
          entry['media'][mean['text']['file']['@media_id']] = get_media(mean['text']['file']['@media_id'], entry['dict']) if mean['text'] and mean['text']['file']
          if mean['usages']
            mean['usages'].each{|usg|
              if usg['text'] and usg['text']['file'] 
                if usg['text']['file'].is_a?(Hash)
                  entry['media'][usg['text']['file']['@media_id']] = get_media(usg['text']['file']['@media_id'], entry['dict'])
                end
                if usg['text']['file'].is_a?(Array)
                  usg['text']['file'].each{|fm|
                    entry['media'][fm['@media_id']] = get_media(fm['@media_id'], entry['dict'])
                  }
                end
              end
            }
          end
        }
      end
      if entry['lemma']['grammar_note']
        entry['lemma']['grammar_note'].each{|gn|
          if gn['variant']
            gn['variant'].each{|gv|
              entry['media'][gv['_text']] = get_media(gv['_text'], entry['dict']) if gv['_text'] != ''
            }
          end
          if gn['_text'] and gn['_text'] =~ /media_id/
            gn['_text'].scan(/\[media_id=([0-9]+)\]/).each{|gm|
              entry['media'][gm[0]] = get_media(gm[0], entry['dict'])
            }
          end
        }
      end
      if entry['lemma']['style_note']
        entry['lemma']['style_note'].each{|gn|
          if gn['variant']
            gn['variant'].each{|gv|
              entry['media'][gv['_text']] = get_media(gv['_text'], entry['dict']) if gv['_text'] != ''
            }
          end
          if gn['_text'] and gn['_text'] =~ /media_id/
            gn['_text'].scan(/\[media_id=([0-9]+)\]/).each{|gm|
              entry['media'][gm[0]] = get_media(gm[0], entry['dict'])
            }
          end
        }
      end
    end
    if entry['lemma']['video_front'].to_s != ''
      entry['media']['video_front'] = get_media_location(entry['lemma']['video_front'].to_s, entry['dict'])
    end
    if entry['lemma']['video_side'].to_s != ''
      entry['media']['video_side'] = get_media_location(entry['lemma']['video_side'].to_s, entry['dict'])
    end
    return entry
  end

  def add_rels(entry, add_rev=true, type=nil, target=nil)
    return entry if entry['meanings'].nil?
    entry['meanings'].each{|mean|
      if mean['relation']
        mean['relation'].each{|rel|
          next if type != nil and rel['type'] != type
          next if target != nil and rel['target'] != target
          if rel['meaning_id'] =~ /^[0-9]*-[0-9]*$/
            rela = rel['meaning_id'].split('-')
            lemmaid = rela[0]
            rel['meaning_nr'] = rela[1]
            relentry = getone(rel['target'], lemmaid)
            next if relentry.nil?
            relentry, cu = add_colloc(relentry) if add_rev
            relentry = get_sw(relentry)
            relentry = add_media(relentry, true)
            rel['entry'] = relentry
          elsif rel['meaning_id'] =~ /^[0-9]*-[0-9]*_us[0-9]*$/
            rela = rel['meaning_id'].split('-')
            lemmaid = rela[0]
            relentry = getone(rel['target'], lemmaid)
            next if relentry.nil?
            rel['entry'] = relentry
            if rel['entry']
              rel['entry']['meanings'].each{|rm|
                if rm['usages']
                  rm['usages'].each{|ru|
                    if ru['id'] == rel['meaning_id']
                      if ru['text']['file'] != nil and ru['text']['file']['@media_id'] != nil
                        usmedia = get_media(ru['text']['file']['@media_id'], rel['target'])
                        rel['entry']['lemma']['video_front'] = usmedia['location']
                        rel['entry']['media'] = {'video_front'=>usmedia}
                      end
                      if ru['text']['_text'] != nil
                        rel['entry']['lemma']['title'] = ru['text']['_text']
                      end
                    end
                  }
                end
              }
            end
          else
            rel['entry'] = {'lemma'=>{'title'=>rel['meaning_id']}}
            rel['meaning_nr'] = ''
          end
        }
      end
      if mean['text'] and mean['text']['_text']
        mean['text']['_text'].scan(/\[([0-9]+)(-[0-9]+)?\]/).each{|mrel|
          relid = mrel[0]
          mean['def_relations'] = {} if mean['def_relations'].nil?
          mean['def_relations'][relid] = getone(entry['dict'], relid)['lemma']['title']
        }
      end
    }
    return entry
  end

  def get_key_search(search)
      search_ar = search.split('|')
      search_shape = search_ar[0].to_s.split(',') #tvary
      search_jedno = []
      search_obe_ruzne = []
      search_obe_stejne = []
      $stdout.puts search_shape
      search_shape.each{|e|
        #jednorucni, rotace jen 0-7
        search_jedno << {
          'lemma.sw'=>{
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
          'lemma.sw'=>{
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
          'lemma.sw'=>{
            '$elemMatch'=>{
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
            }
          }
        }
      }

      if search_ar[1].to_s != ''
        #pridame umisteni
        search_loc = search_ar[1].split(',')
        search_jedno.map!{|e| 
          e['lemma.sw']['$elemMatch']['@misto'] = {'$in'=>search_loc}
          e
        }
        search_obe_stejne.map!{|e| 
          e['lemma.sw']['$elemMatch']['@misto'] = {'$in'=>search_loc}
          e
        }
        search_obe_ruzne.map!{|e| 
          e['lemma.sw']['$elemMatch']['@misto'] = {'$in'=>search_loc}
          e
        }
        if search_jedno.length == 0
          search_jedno << {'lemma.sw'=>{'$elemMatch'=>{'@misto'=>{'$in'=>search_loc}}}}
        end
        if search_obe_ruzne.length == 0
          search_obe_ruzne << {'lemma.sw'=>{'$elemMatch'=>{'@misto'=>{'$in'=>search_loc}}}}
        end
        if search_obe_stejne.length == 0
          search_obe_stejne << {'lemma.sw'=>{'$elemMatch'=>{'@misto'=>{'$in'=>search_loc}}}}
        end
      end

      # dvourucni volby, vyber dotazu
      if search_ar[2].to_s != ''
        search_two = search_ar[2].split(',')
        if search_two.include?('sym')
          search_query = search_obe_stejne
        else
          search_query = search_obe_ruzne
        end
        if search_two.include?('act')
          search_query.map!{|e| 
            e['lemma.sw']['$elemMatch']['$and'] = [] if e['lemma.sw']['$elemMatch']['$and'].nil?
            e['lemma.sw']['$elemMatch']['$and'] << {
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
      return search_query
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
      elsif search == '*'
        @entrydb.find({'dict': dictcode}).each{|re|
          res << re
        }
      else
        if @write_dicts.include?(dictcode)
          fullids = []
          locale = dictcode
          locale = 'sk' if dictcode == 'sj'
          search_cond = {'dict': dictcode}
          search_cond_title ={'$or': [{'lemma.title': search}, {'lemma.title_var': search}]}
          search_cond_title[:$or] << {'lemma.title_dia': search} 
          search_cond_title[:$or] << {'lemma.gram.form._text': search} 
          if search != '' and more_params['slovni_druh'].to_s != ''
            search_cond[:$and] = [search_cond_title,{'lemma.grammar_note.@slovni_druh'=> more_params['slovni_druh'].to_s}]
          end
          if search == '' and more_params['slovni_druh'].to_s != ''
            search_cond['lemma.grammar_note.@slovni_druh'] = more_params['slovni_druh'].to_s
          end
          if search != '' and more_params['slovni_druh'].to_s == ''
            search_cond[:$or] = search_cond_title[:$or]
          end
          $stdout.puts search_cond
          cursor = @entrydb.find(search_cond, :sort => {'lemma.title'=>1})
          fullcount = 0
          fullcount = cursor.count_documents if search != ''
          cursor.each{|re|
            res << re if fullcount > start and more_params['slovni_druh'].to_s == ''
            fullids << re['id'] if more_params['slovni_druh'].to_s == ''
          }
          search_cond = {'dict': dictcode, 'id': {'$nin': fullids}}
          search_cond_title = {'$or': [{'lemma.title': {'$regex': /^#{search}/i}}]}
          search_cond_title[:$or] << {'lemma.title': {'$regex': /(^| )#{search}/i}}
          if search != '' and more_params['slovni_druh'].to_s != ''
            search_cond[:$and] = [search_cond_title,{'lemma.grammar_note.@slovni_druh'=> more_params['slovni_druh'].to_s}]
          end
          if search == '' and more_params['slovni_druh'].to_s != ''
            search_cond['lemma.grammar_note.@slovni_druh'] = more_params['slovni_druh'].to_s
          end
          if search != '' and more_params['slovni_druh'].to_s == ''
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
          search_in = 'cs'
          search_in = @dict_info[dictcode]['search_in'] unless @dict_info[dictcode]['search_in'].nil?
          csl = [search, search_orig]
          if search != ''
            $mongo['entries'].find({'dict'=>search_in, 'lemma.title'=> {'$regex'=>/^#{search}/i}}, {'projection'=>{'meanings.id'=>1, '_id'=>0}}).each{|re|
              unless re['meanings'].nil?
                re['meanings'].each{|rl| 
                  csl << rl['id']
                }
              end
            }
          end
          search_cond = {'dict'=>dictcode}
          search_cond_title = {'$or'=>[
            {'meanings.relation'=>{'$elemMatch'=>{'target'=>search_in,'meaning_id'=>{'$in'=>csl}}}},
            {'meanings.relation'=>{'$elemMatch'=>{'target'=>search_in,'meaning_id'=>{'$regex'=>/^#{search}$/i}}}}
          ]}
          if search != '' and more_params['slovni_druh'].to_s != ''
            search_cond[:$and] = [search_cond_title,{'lemma.grammar_note.@slovni_druh'=> more_params['slovni_druh'].to_s}]
          end
          if search == '' and more_params['slovni_druh'].to_s != ''
            search_cond['lemma.grammar_note.@slovni_druh'] = more_params['slovni_druh'].to_s
          end
          if search != '' and more_params['slovni_druh'].to_s == ''
            search_cond[:$or] = search_cond_title['$or']
          end
          $stdout.puts search_cond
          cursor = $mongo['entries'].find(search_cond)
          resultcount = cursor.count_documents
          cursor = cursor.skip(start)
          cursor = cursor.limit(limit) if limit.to_i > 0
          cursor.each{|e|
            res << full_entry(e, false)
          }
        end
      end
    when 'key'
      search_query = {'dict'=>dictcode, '$or'=>get_key_search(search)}
      $stdout.puts search_query
      cursor = $mongo['entries'].find(search_query)
      resultcount = cursor.count_documents
      cursor = cursor.skip(start)
      cursor = cursor.limit(limit) if limit.to_i > 0
      cursor.each{|e|
        res << add_media(e, true)
      }
    end
    return {'count'=> resultcount, 'entries'=> res}
  end

  def translate2(source, target, search, type, start=0, limit=nil)
    res = []
    resultcount = 0
    case type
    when 'text'
      search = search.downcase
      if search =~ /^[0-9]*$/
        resultcount = 0
        @entrydb.find({'dict': dictcode, 'id': search, 'meanings.relation.target': target}).each{|re|
          entry = add_rels(re, true, 'translation', target)
          entry = get_sw(entry)
          res << entry
          resultcount = 1
        }
      else
        if @write_dicts.include?(source)
          locale = source
          locale = 'sk' if source == 'sj'
          search_cond_text = {'$or': []}
          search_cond_text[:$or] << {'lemma.title': search} 
          search_cond_text[:$or] << {'lemma.title_var': search} 
          search_cond_text[:$or] << {'lemma.title_dia': search} 
          search_cond_text[:$or] << {'lemma.gram.form._text': search} 
          search_cond_text[:$or] << {'lemma.title': {'$regex': /^#{search}/i}}
          search_cond_text[:$or] << {'lemma.title': {'$regex': /(^| )#{search}/i}}
          search_cond_rel = {'meanings.relation':{'$elemMatch': {'target': target, 'type': 'translation', 'status': 'published'}}}
          search_cond = {'dict': dictcode, '$and': [search_cond_text, search_cond_rel]}
          search_cond2 = {'dict': target, 'meanings.relation': {'$elemMatch': {'target': dictcode, 'meaning_id': {'$regex': /(^| )#{search}/i}, 'status': 'published'}}}
          $stdout.puts search_cond
          $stdout.puts search_cond2
          ## > db.entries.aggregate([{'$match':{dict:"cs", '$and':[{'$or':[{"lemma.title":"bratranec"},{"lemma.title":"bratr"}]}, {"meanings.relation":{'$elemMatch':{target:"czj", type:"translation"}}}]}}, {'$unwind':'$meanings'}, {'$unwind':'$meanings.relation'},{'$match':{'meanings.relation.target':'czj'}},{'$project':{'meanings.relation':1, 'id':1}},{'$limit':2}])
          ## > db.entries.aggregate([{'$match':{"$or":[{dict:"czj","meanings.relation":{"$elemMatch":{"target":"cs","meaning_id":{"$regex":"dům"}}}},{dict:"cs", '$and':[{'$or':[{"lemma.title":"bratranec"},{"lemma.title":"bratr"}]}, {"meanings.relation":{'$elemMatch':{target:"czj", type:"translation"}}}]}]}}, {'$unwind':'$meanings'}, {'$unwind':'$meanings.relation'},{'$match':{"$or":[{'meanings.relation.target':'czj'},{'meanings.relation.target':'cs'}]}},{'$project':{'meanings.relation':1, 'id':1,'dict':1}},{'$limit':5}])
          pipeline = [
            {'$match' => {'$or':[search_cond,search_cond2]}},
            {'$unwind' => '$meanings'},
            {'$unwind' => '$meanings.relation'},
            {'$match' => {'meanings.relation.type'=>'translation', '$and'=>[{'$or'=>[{'meanings.relation.target'=>target}, {'meanings.relation.target'=>dictcode}]}, {'$or'=>[{'meanings.relation.meaning_id'=>{'$regex'=>/(^| )#{search}/i}}, {'meanings.relation.meaning_id'=>{'$regex'=>/^[0-9]+-[0-9]+(_us[0-9]+)?/}}]}]}},
            #{'$group' => {'_id' => {'_id'=>'$_id', 'dict'=> '$dict', 'id'=> '$id', 'meanings'=>'$meanings'}}},
            #{'$project' => {'dict'=>'$_id.dict','id'=>'$_id.id','meanings'=>'$_id.meanings'}},
            {'$sort' => {'lemma.title'=>1}}
          ]
          @entrydb.aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
            resultcount = re['total'].to_i
          }
          pipeline << {'$skip' => start.to_i}
          pipeline << {'$limit' => limit.to_i} if limit.to_i > 0
          cursor = @entrydb.aggregate(pipeline, :allow_disk_use => true)
          cursor.each{|re|
            re['meanings']['relation'] = [re['meanings']['relation']]
            re['meanings'] = [re['meanings']]
            $stdout.puts 'start res<e '+re['dict']+re['id']+' '+Time.now.to_s
            $stdout.puts 'start addrels '+re['id']+' '+Time.now.to_s
            entry = add_rels(re, true, 'translation', target)
            $stdout.puts 'start addrels2 '+re['id']+' '+Time.now.to_s
            entry = add_rels(entry, true, 'translation', dictcode)
            $stdout.puts 'start getsw '+re['id']+' '+Time.now.to_s
            entry = get_sw(entry)
            entry['meanings'].each{|m|
              oldrels = m['relation']
              m['relation'] = []
              next if m['is_translation_unknown'].to_s == '1'
              oldrels.each{|r|
                if r['target'] == target 
                  m['relation'] << r
                elsif r['target'] == source and r['entry'] and r['entry']['lemma'] and r['entry']['lemma']['title'].to_s =~ /#{search}/i
                  m['relation'] << r
                end
              }
            }
            if re['dict'] == target
              $stdout.puts 'start addmedia '+re['id']+' '+Time.now.to_s
              entry = add_media(entry, true)
            end
            $stdout.puts 'end '+re['id']+' '+Time.now.to_s
            res << entry
          }
        else
          search_in = 'cs'
          search_in = @dict_info[dictcode]['search_in'] unless @dict_info[dictcode]['search_in'].nil?
          csl = [search]
          $mongo['entries'].find({'dict'=>search_in, 'lemma.title'=> {'$regex': /^#{search}/i}}, {'projection'=>{'meanings.id'=>1, '_id'=>0}}).each{|re|
            unless re['meanings'].nil?
              re['meanings'].each{|rl| 
                csl << rl['id']
              }
            end
          }
          cursor = $mongo['entries'].find({'dict'=>dictcode, 'meanings.relation'=>{'$elemMatch'=>{'target'=>search_in,'status'=>'published','meaning_id'=>{'$in'=>csl}}}})
          resultcount = cursor.count_documents
          cursor = cursor.skip(start)
          cursor = cursor.limit(limit) if limit.to_i > 0
          cursor.each{|e|
            entry = add_rels(e, true, 'translation', target)
            entry = add_media(entry)
            entry = get_sw(entry)
            res << entry
          }
        end
      end
    when 'key'
      search_cond_text = {'$or': get_key_search(search)}
      search_cond_rel = {'meanings.relation':{'$elemMatch': {'target': target, 'type': 'translation', 'status': 'published'}}}
      search_cond = {'dict': dictcode, '$and': [search_cond_text, search_cond_rel]}
      $stdout.puts search_cond
          pipeline = [
            {'$match' => search_cond},
            {'$unwind' => '$meanings'},
            {'$unwind' => '$meanings.relation'},
            {'$match' => {'meanings.relation.target'=>target}},
          ]
          @entrydb.aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
            resultcount = re['total'].to_i
          }
          pipeline << {'$skip' => start.to_i}
          pipeline << {'$limit' => limit.to_i} if limit.to_i > 0
          cursor = @entrydb.aggregate(pipeline, :allow_disk_use => true)
          cursor.each{|re|
            re['meanings']['relation'] = [re['meanings']['relation']]
            re['meanings'] = [re['meanings']]
            entry = add_rels(re, true, 'translation', target)
            entry = get_sw(entry)
            res << entry
          }
    end
    return {'count'=> resultcount, 'entries'=> res}
  end

  def save_doc(data)
    entryid = data['id']
    dict = data['dict']

    #check relations
    olddata = getone(dict, entryid)
    if olddata != nil
      oldrels = {}
      oldmeans = []
      if olddata['meanings']
        olddata['meanings'].each{|m|
          oldmeans << m['id']
          oldrels[m['id']] = []
          if m['relation']
            m['relation'].each{|r|
              oldrels[m['id']] << r
            }
          end
          if m['usages']
            m['usages'].each{|u|
              if u['relation']
                oldrels[u['id']] = []
                u['relation'].each{|ur|
                  oldrels[u['id']] << ur
                }
              end
            }
          end
        }
      end
      $stdout.puts oldrels
      #removed meanings?
      oldmeans.each{|mi|
        if data['meanings'].nil? or data['meanings'].select{|m| m['id']==mi}.length == 0
          $stdout.puts 'REMOVED meaning'+mi
          oldrels[mi].each{|olr|
            $stdout.puts 'smazat relation '+olr['meaning_id']
            if olr['type'] == 'translation'
              target = olr['target'].to_s
            else
              target = dict
            end
            remove_relation(target, mi, olr['meaning_id'], olr['type'], dict)
          }
        end
      }
      data['meanings'].each{|m|
        #remove relations
        if oldrels[m['id']]
          oldrels[m['id']].each{|olr|
            if m['relation'] and m['relation'].select{|r| r['meaning_id']==olr['meaning_id'] and r['type']==olr['type']}.length == 0
              $stdout.puts 'smazat relation '+olr['meaning_id']
              if olr['type'] == 'translation'
                target = olr['target'].to_s
              else
                target = dict
              end
              remove_relation(target, m['id'], olr['meaning_id'], olr['type'], dict)
            end
          }
        end
        #add relations
        if m['relation']
          m['relation'].each{|rel|
            $stdout.puts 'pridat relation '+rel['meaning_id']
            if rel['type'] == 'translation'
              target = rel['target'].to_s
            else
              target = dict
            end
            add_relation(target, m['id'], rel['meaning_id'], rel['type'], rel['status'], dict) 
            if rel['meaning_id'].include?('_us') and rel['status'] == 'published' and /^([0-9]*)-.*/.match(rel['meaning_id']) != nil
              publish_usage_relation(target, rel['meaning_id'])
            end
          }
        end
        if m['usages']
          m['usages'].each{|usg|
            #remove relations in usages
            if oldrels[usg['id']]
              oldrels[usg['id']].each{|olr|
                if usg['relation'].nil? or usg['relation'].select{|r| r['meaning_id']==olr['meaning_id'] and r['type']==olr['type']}.length == 0
                  $stdout.puts 'smazat relation '+olr['meaning_id']
                  if olr['type'] == 'translation'
                    target = olr['target'].to_s
                  else
                    target = dictcode
                  end
                  remove_relation(target, usg['id'], olr['meaning_id'], olr['type'], dict)
                end
              }
            end
            #add relations in usages
            if usg['relation']
              usg['relation'].each{|rel|
                $stdout.puts 'pridat relation '+rel['meaning_id']
                if rel['type'] == 'translation'
                  target = rel['target'].to_s
                else
                  target = dictcode
                end
                add_relation(target, usg['id'], rel['meaning_id'], rel['type'], usg['status'], dict) 
                if rel['meaning_id'].include?('_us') and usg['status'] == 'published' and /^([0-9]*)-.*/.match(rel['meaning_id']) != nil
                  publish_usage_relation(target, rel['meaning_id'])
                end
              }
            end
          }
        end
      }
    end

    #add fsw
    if data['lemma']['sw']
      data['lemma']['sw'].each{|sw|
        sw['@fsw'] = get_fsw(sw['_text']) if sw['@fsw'] == ''
      }
    end

    #save media info
    if data['update_video']
      data['update_video'].each{|uv|
        save_media(uv)
      }
      data.delete('update_video')
    end

    data.delete('track_changes')
    $stdout.puts data

    @entrydb.find({'dict':dict, 'id': entryid}).delete_many
    @entrydb.insert_one(data)

    # update SW cache
    $mongo['sw'].find({'dict': dict, 'entries_used': entryid}).delete_many
    cache_all_sw(false)

    return true
  end

  def remove_relation(dict, rel_meaning, rel_target_id, rel_type, rel_dict)
    rel_type = 'synonym' if rel_type == 'synonym_strategie'
    query = {'dict'=>dict, '$or'=>[{'meanings.id'=>rel_target_id}, {'meanings.usages.id'=>rel_target_id}]}
    @entrydb.find(query).each{|doc|
      doc['meanings'].each{|mean|
        if mean['id'] == rel_target_id
          mean['relation'].reject!{|rel| rel['target'] == rel_dict and rel['meaning_id'] == rel_meaning}
        end

        if mean['usages']
          mean['usages'].select{|usg| usg['id'] == rel_target_id}.each{|usg|
            if usg['relation']
              usg['relation'].reject!{|rel| rel['target'] == rel_dict and rel['meaning_id'] == rel_meaning}
              if usg['relation'].length == 0
                usg['type'] = 'sentence'
              end
            end
          }
        end
      }
      $stdout.puts 'update doc remove relations '+doc['dict']+doc['id']
      @entrydb.find({'dict'=>doc['dict'], 'id'=>doc['id']}).delete_many
      @entrydb.insert_one(doc)
    }
  end

  def add_relation(dict, rel_meaning, rel_target_id, rel_type, rel_status, rel_dict)
    rel_type = 'synonym' if rel_type == 'synonym_strategie'
    query = {'dict'=>dict, '$or'=>[{'meanings.id'=>rel_target_id}, {'meanings.usages.id'=>rel_target_id}]}
    @entrydb.find(query).each{|doc|
      changed = false
      doc['meanings'].each{|mean|
        if mean['id'] == rel_target_id
          mean['relation'] = [] if mean['relation'].nil?
          if not mean['relation'].find{|rel| rel['target'] == rel_dict and rel['type'] == rel_type and rel['meaning_id'] == rel_meaning}
            mean['relation'] << {'target'=>rel_dict, 'type'=>rel_type, 'meaning_id'=>rel_meaning, 'status'=>rel_status}
            changed = true
          else
            mean['relation'].select{|rel| rel['target'] == rel_dict and rel['type'] == rel_type and rel['meaning_id'] == rel_meaning}.each{|rel|
              rel['status'] = rel_status
              changed = true
            }
          end
        end

        if mean['usages']
          mean['usages'].select{|usg| usg['id'] == rel_target_id}.each{|usg|
            usg['relation'] = [] if usg['relation'].nil?
            if not usg['relation'].find{|rel| rel['target'] == rel_dict and rel['type'] == rel_type and rel['meaning_id'] == rel_meaning}
              usg['relation'] << {'target'=>rel_dict, 'type'=>rel_type, 'meaning_id'=>rel_meaning, 'status'=>rel_status}
              usg['type'] = 'colloc'
              changed = true
            else
              usg['relation'].select{|rel| rel['target'] == rel_dict and rel['type'] == rel_type and rel['meaning_id'] == rel_meaning}.each{|rel|
                rel['status'] = rel_status
                changed = true
              }
            end
          }
        end
      }
      if changed
        $stdout.puts 'update doc add relations '+doc['dict']+doc['id']
        @entrydb.find({'dict'=>doc['dict'], 'id'=>doc['id']}).delete_many
        @entrydb.insert_one(doc)
      end
    }
  end

  def publish_usage_relation(dict, rel_usage)
    query = {'dict'=>dict, 'meanings.usages.id'=>rel_usage}
    @entrydb.find(query).each{|doc|
      changed = false
      doc['meanings'].each{|mean|
        if mean['usages'] and mean['usages'].find{|usg| usg['id'] == rel_usage}
          mean['usages'].select{|usg| usg['id'] == rel_usage}.each{|usg|
            if usg['status'] != 'published'
              usg['status'] = 'published'
              changed = true
            end
          }
        end
      }
      if changed
        $stdout.puts 'update doc publish relations '+doc['dict']+doc['id']
        @entrydb.find({'dict'=>doc['dict'], 'id'=>doc['id']}).delete_many
        @entrydb.insert_one(doc)
      end
    }
  end

  def get_fsw(swstring)
    fsw = 'M500x500'
    swa = []
    swstring.split('_').each{|e|
      match = /([0-9]*)(\(.*\))?/.match(e)
      unless match[1].nil?
        info = {'id'=>match[1], 'x'=>0, 'y'=>0}
        unless match[2].nil?
          if match[2].include?('x') and match[2].include?('y')
            match2 = /\(x([\-0-9]*)y([\-0-9]*)\)/.match(match[2])
            info['x'] = match2[1].to_i
            info['y'] = match2[2].to_i
          elsif match[2].include?('x')
            info['x'] = match[2].gsub(/[^0-9^-]/,'').to_i
          else
            info['y'] = match[2].gsub(/[^0-9^-]/,'').to_i
          end
        end
        swa << info
      end
    }
    swa.each{|info|
      doc = $mongo['symbol'].find({'id': info['id']}).first
      fsw += 'S' + doc['bs_code'].to_i.to_s(16) + (doc['fill'].to_i-1).to_s(16) + (doc['rot'].to_i-1).to_s(16) + (info['x']+500).to_s + 'x' + (info['y']+500).to_s
    }
    return fsw
  end

  def comment_add(user, entry, box, text)
    comment_data = {
      'dict' => @dictcode,
      'entry' => entry,
      'box' => box,
      'text' => text,
      'user' => user,
      'time' => Time.new.strftime('%Y-%m-%d %H:%M')
    }
    $stdout.puts comment_data
    $mongo['koment'].insert_one(comment_data)
  end

  def comment_del(cid)
    $mongo['koment'].find({'_id' => BSON::ObjectId.from_string(cid)}).delete_many
  end

  def get_entry_files(entry_id)
    list = []
    entry = getone(@dictcode, entry_id)

    query = {'dict'=> @dictcode}
    query[:$or] = [{'entry_folder' => entry_id}]

    if entry != nil
      query[:$or] << {'media_folder_id' => entry['lemma']['media_folder_id']} if entry['lemma']['media_folder_id'].to_s != ''
      files = []
      if entry['meanings']
        entry['meanings'].each{|me|
          if me['usages']
            me['usages'].each{|us|
              files << us['text']['file']['@media_id'] if us['text'] and us['text']['file'] and us['text']['file']['@media_id']
            }
          end
          files << me['text']['file']['@media_id'] if me['text'] and me['text']['file'] and me['text']['file']['@media_id']
        }
      end
      if entry['lemma']['grammar_note'] and entry['lemma']['grammar_note'][0] and entry['lemma']['grammar_note'][0]['variant']
        entry['lemma']['grammar_note'][0]['variant'].each{|va|
          files << va['_text']
        }
      end
      if entry['lemma']['style_note'] and entry['lemma']['style_note'][0] and entry['lemma']['style_note'][0]['variant']
        entry['lemma']['style_note'][0]['variant'].each{|va|
          files << va['_text']
        }
      end
      files.uniq.each{|fi|
        query[:$or] << {'id' => fi}
      }
      if entry['lemma']['video_front'] and entry['lemma']['video_front'].to_s != ''
        query[:$or] << {'location' => entry['lemma']['video_front'].to_s}
      end
      if entry['lemma']['video_side'] and entry['lemma']['video_side'].to_s != ''
        query[:$or] << {'location' => entry['lemma']['video_side'].to_s}
      end
    end

    $mongo['media'].find(query).each{|re| list << re}

    return list
  end

  def find_files(search, type)
    list = []
    if search.length > 1
      query = {'dict' => @dictcode, :$or => [{'location' => /#{search}/}, {'original_file_name' => /#{search}/}]}
      case type
      when 'AB'
        query['type'] = {'$in' => ['sign_front', 'sign_side']}
      when 'A'
        query['type'] = 'sign_front'
      when 'K'
        query['type'] = 'sign_usage_example'
      when 'D'
        query['type'] = 'sign_definition'
      end

      $mongo['media'].find(query).each{|re| list << re}
    end
    return list
  end

  def getfsw(swstring)
    fsw = 'M500x500'
    swa = []
    swstring.split('_').each{|e|
      match = /([0-9]*)(\(.*\))?/.match(e)
      unless match[1].nil?
        info = {'id'=>match[1], 'x'=>0, 'y'=>0}
        unless match[2].nil?
          if match[2].include?('x') and match[2].include?('y')
            match2 = /\(x([\-0-9]*)y([\-0-9]*)\)/.match(match[2])
            info['x'] = match2[1].to_i
            info['y'] = match2[2].to_i
          elsif match[2].include?('x')
            info['x'] = match[2].gsub(/[^0-9^-]/,'').to_i
          else
            info['y'] = match[2].gsub(/[^0-9^-]/,'').to_i
          end
        end
        swa << info
      end
    }
    swa.each{|info|
      doc = $mongo['symbol'].find({'id'=>info['id']}).first
      fsw += 'S' + doc['bs_code'].to_i.to_s(16) + (doc['fill'].to_i-1).to_s(16) + (doc['rot'].to_i-1).to_s(16) + (info['x']+500).to_s + 'x' + (info['y']+500).to_s
    }
    return fsw
  end

  def fromfsw(fswstring)
        swa = []
    maxx = 0
    maxy = 0
    match = /M([0-9]*)x([0-9]*)(S.*)/.match(fswstring)
    unless (match.nil? or match[1].nil? or match[2].nil? or match[3].nil?)
      maxx = match[1].to_i
      maxy = match[2].to_i
      match[3].split('S').each{|fs|
        next if fs == ''
        bs = fs[0..2].to_i(16)
        fil = fs[3..3].to_i(16)+1
        rot = fs[4..4].to_i(16)+1
        res = $mongo['symbol'].find({'bs_code'=>bs.to_s, 'fill'=>fil.to_s, 'rot'=>rot.to_s})
        next if res.first.nil?
        doc = res.first
        match2 = /([0-9]*)x([0-9]*)/.match(fs[5..-1])
        x = match2[1].to_i - 500
        y = match2[2].to_i - 500
        swpos = ''
        if x != 0 or y != 0
          swpos = '('
          swpos += 'x'+x.to_s if x != 0
          swpos += 'y'+y.to_s if y != 0
          swpos += ')'
        end
        swa << doc['id'] + swpos
      }
    end
    swstring = swa.join('_')
    return swstring
  end

  def find_relation(search)
    target = @dictcode
    list = []
    if search != '' and target != ''
      if @write_dicts.include?(target)
        query = {
          'dict'=>target,
          'lemma.completeness'=>{'$ne'=>'1'},
          '$or'=>[
            {'lemma.title'=>{'$regex'=>/^#{search.downcase}/i}},
            {'lemma.title_dia'=>{'$regex'=>/^#{search.downcase}/i}},
            {'meanings.id'=>search},
            {'id'=>search}
          ]
        }
        @entrydb.find(query).each{|rel|
          title = rel['lemma']['title'].to_s
          if rel['meanings']
            rel['meanings'].each{|relm|
              hash = {'title'=>title, 'number'=>relm['number'].to_s, 'id'=>relm['id']}
              hash['def'] = relm['text']['_text'] if relm['text'] and relm['text']['_text'].to_s != ''
              list << hash
            }
          end
        }
      else
        # find media with label
        querym = {
          'dict'=>target,
          '$or'=>[
            {'label'=>{'$regex'=>/#{search.downcase}/i}},
            {'label'=>search}
          ],
          'type'=>{'$in' => ['sign_front', 'sign_side', 'sign_definition']}
        }
        mids = []
        mlocs = []
        $mongo['media'].find(querym).each{|med|
          mids << med['id']
          mlocs << med['location']
        }
        # find relations with title
        queryr = {
          'dict'=>{'$in'=>@write_dicts},
          'meanings.relation.target'=>target,
          '$or'=>[
            {'lemma.title'=>{'$regex'=>/^#{search.downcase}/i}},
            {'lemma.title_dia'=>{'$regex'=>/^#{search.downcase}/i}},
          ]
        }
        trans = []
        @entrydb.find(queryr).each{|entry|
          entry['meanings'].each{|mean|
            mean['relation'].each{|rel|
              if rel['type'] == 'translation' and rel['target'] == target
                trans << rel['meaning_id']
              end
            }
          }
        }

        # combine media, relation
        query = {
          'dict'=>target,
          'lemma.completeness'=>{'$ne'=>'1'},
          '$or'=>[
            {'id'=>search},
            {'lemma.video_front'=>{'$in'=>mlocs}},
            {'meanings.usages.text.file.@media_id'=>{'$in'=>mids}},
            {'meanings.text.file.@media_id'=>{'$in'=>mids}},
            {'lemma.grammar_note.variant._text'=>{'$in'=>mids}},
            {'lemma.style_note.variant._text'=>{'$in'=>mids}},
            {'meanings.id'=>{'$in'=>trans}}
          ]
        }
        $stdout.puts query
        @entrydb.find(query).each{|rel|
          hash = {'title'=>rel['id'], 'target'=>target, 'front'=>'', 'def'=>''}
          if rel['lemma']['video_front'].to_s != '' 
            hash['title'] = get_media_location(rel['lemma']['video_front'].to_s, target)['label'].to_s + ' (' + rel['id'].to_s + ')'
            hash['front'] = rel['lemma']['video_front'].to_s
          end
          rel['meanings'].each{|mean|
            hash2 = hash.clone
            hash2['number'] = mean['number'].to_s
            hash2['id'] = mean['id'].to_s
            if mean['text'] and mean['text']['file'] and mean['text']['file']['@media_id']
              hash2['def'] = mean['text']['file']['@media_id'].to_s
              hash2['loc'] = get_media(mean['text']['file']['@media_id'].to_s, target)['location']
            end
            list << hash2
          }
        }
      end
    end
    return list.uniq.sort_by{|x| [x['title'], x['number'].to_i]}
  end

  def find_link(search)
    target = @dictcode
    list = []
    if search != '' and target != ''
      if @write_dicts.include?(target)
        query = {
          'dict'=>target,
          'lemma.completeness'=>{'$ne'=>'1'},
          '$or'=>[
            {'lemma.title'=>{'$regex'=>/^#{search.downcase}/i}},
            {'lemma.title_dia'=>{'$regex'=>/^#{search.downcase}/i}},
          ]
        }
        @entrydb.find(query).each{|entry|
          title = entry['lemma']['title'].to_s
          list << {'title'=>title, 'id'=>entry['id']}
        }
      else
        # find media with label
        querym = {
          'dict'=>target,
          '$or'=>[
            {'label'=>{'$regex'=>/#{search.downcase}/i}},
            {'label'=>search}
          ],
          'type'=>{'$in' => ['sign_front', 'sign_side', 'sign_definition']}
        }
        mids = []
        mlocs = []
        $mongo['media'].find(querym).each{|med|
          mids << med['id']
          mlocs << med['location']
        }
        # find relations with title
        queryr = {
          'dict'=>{'$in'=>@write_dicts},
          'meanings.relation.target'=>target,
          '$or'=>[
            {'lemma.title'=>{'$regex'=>/^#{search.downcase}/i}},
            {'lemma.title_dia'=>{'$regex'=>/^#{search.downcase}/i}},
          ]
        }
        trans = []
        @entrydb.find(queryr).each{|entry|
          entry['meanings'].each{|mean|
            mean['relation'].each{|rel|
              if rel['type'] == 'translation' and rel['target'] == target
                trans << rel['meaning_id']
              end
            }
          }
        }

        # combine media, relation
        query = {
          'dict'=>target,
          'lemma.completeness'=>{'$ne'=>'1'},
          '$or'=>[
            {'id'=>search},
            {'lemma.video_front'=>{'$in'=>mlocs}},
            {'meanings.usages.text.file.@media_id'=>{'$in'=>mids}},
            {'meanings.text.file.@media_id'=>{'$in'=>mids}},
            {'lemma.grammar_note.variant._text'=>{'$in'=>mids}},
            {'lemma.style_note.variant._text'=>{'$in'=>mids}},
            {'meanings.id'=>{'$in'=>trans}}
          ]
        }
        $stdout.puts query
        @entrydb.find(query).each{|rel|
          hash = {'id'=>rel['id'], 'title'=>'', 'label'=>'', 'loc'=>''}
          if rel['lemma']['video_front'].to_s != '' 
            hash['label'] = get_media_location(rel['lemma']['video_front'].to_s, target)['label'].to_s + ' (' + rel['id'].to_s + ')'
            hash['loc'] = rel['lemma']['video_front'].to_s
          end
          list << hash
        }
      end
    end
    return list.sort_by{|x| [x['title'], x['label'].to_i]}
  end

  def get_relation_info(meaning_id)
    data = @entrydb.find({'meanings.id': meaning_id, 'dict': @dictcode}).first
    if data != nil
      if @write_dicts.include?(@dictcode)
        return 'T:'+data['lemma']['title'].to_s
      else
        return 'V:'+data['lemma']['video_front'].to_s
      end
    end
    return ''
  end

  def get_relations(meaning_id, type)
    list = []
    entry = getdoc(meaning_id.split('-')[0].to_s)
    if entry['meanings']
      entry['meanings'].each{|mean|
        if mean['id'] == meaning_id
          mean['relation'].each{|rel|
            next if type != '' and rel['type'] != type
            hash = {'type'=>rel['type'], 'target'=>rel['target'], 'meaning_id'=>rel['meaning_id']}
            if rel['entry'] and rel['entry']['lemma'] and rel['entry']['lemma']['title']
              hash['title'] = rel['entry']['lemma']['title']
            end
            if rel['entry'] and rel['entry']['media'] and rel['entry']['media']['video_front']
              hash['title'] = rel['entry']['media']['video_front']['label']
            end
            list << hash
          }
        end
      }
    end
    return list
  end

  def delete_doc(entry_id)
    @entrydb.find({'dict'=>@dictcode, 'id'=>entry_id}).delete_many
  end

  # remove all relations to entry
  def remove_all_relations(entry_id)
    query = {'$or'=>[
      'meanings.relation'=>{'$elemMatch'=>{'target'=>@dictcode,'meaning_id'=>{'$regex'=>/^#{entry_id}-/}}},
      'meanings.usages.relation'=>{'$elemMatch'=>{'target'=>@dictcode,'meaning_id'=>{'$regex'=>/^#{entry_id}-/}}}
    ]}
    @entrydb.find(query).each{|doc|
      doc['meanings'].each{|mean|
        if mean['relation']
          mean['relation'].reject!{|rel| rel['target'] == @dictcode and rel['meaning_id'].start_with?(entry_id+'-')}
        end
        if mean['usages']
          mean['usages'].each{|usg|
            if usg['relation']
              usg['relation'].reject!{|rel| rel['target'] == @dictcode and rel['meaning_id'].start_with?(entry_id+'-')}
            end
          }
        end
      }
      @entrydb.find({'dict'=>doc['dict'], 'id'=>doc['id']}).delete_many
      @entrydb.insert_one(doc)
    }
  end

  # remove entry as collocation part
  def remove_colloc(entry_id)
    query = {'dict'=>@dictcode, 'collocations.colloc'=>entry_id}
    @entrydb.find(query).each{|doc|
      doc['collocations']['colloc'].delete(entry_id)
      $stdout.puts doc['collocations']
      @entrydb.find({'dict'=>doc['dict'], 'id'=>doc['id']}).delete_many
      @entrydb.insert_one(doc)
    }
  end

  #get new max id
  def get_new_id
    cursor = @entrydb.find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
    cursor = cursor.limit(1)
    newid = 1
    cursor.each{|r|
      newid = r['id'].to_i + 1
    }
    doc = {'dict' => @dictcode, 'id' => newid.to_s, 'empty' => true}
    @entrydb.insert_one(doc)
    return newid
  end

  def norm_name(name)
    name = name.sub('.flv','')
    name = name.sub('.mp4','')
    sense = ''
    name.sub!(/^[ABDKabdk][-_]/,'')
    var = ''
    var = 'A' if name.include?('_1_FLV_HQ')
    var = 'B' if name.include?('_2_FLV_HQ')
    var = 'C' if name.include?('_3_FLV_HQ')
    var = 'D' if name.include?('_4_FLV_HQ')
    var = 'E' if name.include?('_5_FLV_HQ')
    var = 'F' if name.include?('_6_FLV_HQ')
    name.sub!('_1_FLV_HQ','')
    name.sub!('_2_FLV_HQ','')
    name.sub!('_3_FLV_HQ','')
    name.sub!('_4_FLV_HQ','')
    name.sub!('_5_FLV_HQ','')
    name.sub!('_6_FLV_HQ','')
    name.gsub!('FLV_HQ','')
    if name =~ /_[1-9]$/
      var += name[/_([1-9])$/,1]
      name.sub!(/_[1-9]$/,'')
    end
    var = 'A' if name =~ /_I$/
    var = 'B' if name =~ /_II$/
    var = 'C' if name =~ /_III$/
    var = 'D' if name =~ /_IV$/
    name.sub!(/_I$/,'')
    name.sub!(/_II$/,'')
    name.sub!(/_III$/,'')
    name.sub!(/_IV$/,'')
    name.sub!('A-C1','A1')
    name.sub!('A-C-D','A1d')
    if name =~ /[A-Z]$/ and not name =~ /[A-Z][A-Z]$/
      var = name[-1,1]
      name = name[0..-2]
    end
    if name =~ /[A-Z][1-9]$/
      var = name[-2,1]
      sense = name[-1,1]
      name = name[0..-3]
    end
    if name =~ /[A-Z][1-9][a-z]$/
      var = name[-3,3]
      name = name[0..-4]
    end
    if name =~ /[0-9][a-z]$/
      var = (name[/([0-9])[a-z]$/,1].to_i+64).chr + (name[/[0-9]([a-z])$/,1][0].ord-96).to_s
      name = name[0..-3]
    end
    if name =~ /[a-z][0-9]$/
      var = (name[/([0-9])$/,1].to_i+64).chr
      name = name[0..-2]
    end
    var = name.gsub(/.*[a-z0-9]([A-Z])[A-Z]+[0-9]+([0-9])$/,'\1\2')
    var = 'A' if var == ''
    name.gsub!(/[A-Z]+[0-9]+$/,'')
    name.gsub!(/([a-z])([A-Z])/, '\1-\2')
    name.gsub!(/_$/,'')
    name.gsub!('_','-')
    name.gsub!('(','')
    name.gsub!(')','')
    name.downcase!
    return name+'=='+var, sense
  end

  # upload file, store metadata
  def save_uploaded_file(filedata, metadata, entry_id)
    filename = filedata['filename'].gsub(/[^\w^\.^_^-]/, '')
    filename = filename[0,2]+filename[2..-1].gsub('_','')
    $stdout.puts filename
    media = get_media_location(filename, @dictcode)
    if media == {}
      cursor = $mongo['media'].find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
      cursor = cursor.limit(1)
      mediaid = 1
      cursor.each{|r|
        mediaid = r['id'].to_i + 1
      }
    else
      mediaid = media['id']
      $mongo['media'].find({'dict'=> @dictcode, 'id'=> mediaid}).delete_many
    end
    data = {
      'id' => mediaid.to_s,
      'dict' => @dictcode,
      'location' => filename,
      'original_file_name' => filename,
      'label' => norm_name(filename)[0],
      'id_meta_copyright' => metadata['id_meta_copyright'],
      'id_meta_author' => metadata['id_meta_author'],
      'id_meta_source' => metadata['id_meta_source'],
      'admin_comment' => metadata['admin_comment'],
      'type' => metadata['type'],
      'status' => metadata['status'],
      'orient' => metadata['orient'],
      'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S")
    }
    data['entry_folder'] = entry_id if entry_id.to_s != ''
    $mongo['media'].insert_one(data)

    Net::SSH.start("files.dictio.info", $files_user, :key_data=>$files_keys){|ssh|
      ssh.scp.upload!(filedata['tempfile'].path, '/home/adam/upload/'+@dictcode+'/'+filename)
      command = '/home/adam/mkthumb.sh "'+filename+'" "'+@dictcode+'"'
      $stdout.puts command
      ssh.exec(command)
    }
    return filename, mediaid.to_s
  end

  def attach_file(location, entry_id, metadata)
    media = get_media_location(location, @dictcode)
    if media == {}
      cursor = $mongo['media'].find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
      cursor = cursor.limit(1)
      mediaid = 1
      cursor.each{|r|
        mediaid = r['id'].to_i + 1
      }
      media = {
        'id' => mediaid.to_s,
        'dict' => @dictcode,
        'location' => location,
        'original_file_name' => location,
        'label' => norm_name(location)[0],
        'id_meta_copyright' => metadata['id_meta_copyright'],
        'id_meta_author' => metadata['id_meta_author'],
        'id_meta_source' => metadata['id_meta_source'],
        'admin_comment' => metadata['admin_comment'],
        'type' => metadata['type'],
        'status' => metadata['status'],
        'orient' => metadata['orient'],
        'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S")
      }
    else
      mediaid = media['id']
      $mongo['media'].find({'dict'=> @dictcode, 'id'=> mediaid}).delete_many
    end
    media['entry_folder'] = entry_id if entry_id.to_s != ''
    $mongo['media'].insert_one(media)
    return mediaid
  end

  def save_media(data)
    if data['id'].to_s != ''
      media = get_media(data['id'].to_s, @dictcode)
      media['id'] = data['id'].to_s
      media['dict'] = @dictcode
      media['location'] = data['location'].to_s
      media['original_file_name'] = data['original_file_name'].to_s
      media['label'] = data['label'].to_s
      media['id_meta_copyright'] = data['id_meta_copyright'].to_s
      media['id_meta_author'] = data['id_meta_author'].to_s
      media['id_meta_source'] = data['id_meta_source'].to_s
      media['admin_comment'] = data['admin_comment'].to_s
      media['type'] = data['type'].to_s
      media['status'] = data['status'].to_s
      media['orient'] = data['orient'].to_s
      media['created_at'] = data['created_at'].to_s
      media['updated_at'] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      $mongo['media'].find({'dict'=> @dictcode, 'id'=> data['id']}).delete_many
      $mongo['media'].insert_one(media)
    end
    return data['id'].to_s
  end

  def remove_video(entryid, mediaid)
    media = get_media(mediaid, @dictcode, false)
    if media != {}
      media.delete('entry_folder')
      media.delete('media_folder_id')
      $mongo['media'].find({'dict'=> @dictcode, 'id'=> media['id']}).delete_many
      $mongo['media'].insert_one(media)
    end
  end

  def get_gram(entryid)
    data = getone(@dictcode, entryid)
    if data and data['lemma'] and data['lemma']['gram'] and data['lemma']['gram']['form']
      return data['lemma']['gram']
    else
      return {'form'=>[]}
    end
  end

  def trans_cond(pubtrans, trans, target)
    trans_cond = nil
    # jen pubtrans, schvaleny preklad
    if pubtrans != '' and trans == ''
      if pubtrans == 'ano'
        trans_cond = {'$or': [
          {'meanings.relation': {'$elemMatch': {'type': 'translation', 'target': target, 'status': 'published'}}},
          {'meanings.usages.relation': {'$elemMatch': {'type': 'translation', 'target': target, 'status': 'published'}}}
        ]}
      else
        trans_cond = {'meanings': {'$elemMatch': {'is_translation_unknown': {'$ne': '1'}, '$or': [
          {'meanings.relation': {'$not': {'$elemMatch': {'type': 'translation', 'target': target}}}},
          {'meanings.relation': {'$elemMatch': {'type': 'translation', 'target': target, 'status': 'hidden'}}},
          {'meanings.usages.relation': {'$elemMatch': {'type': 'translation', 'target': target, 'status': 'hidden'}}}
        ]}}}
      end
    end

    # jen trans, zadany preklad
    if pubtrans == '' and trans != ''
      if trans == 'ano'
        trans_cond = {'meanings': {'$elemMatch': {'$or': [
          {'relation': {'$elemMatch': {'type': 'translation', 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
          {'usages.relation': {'$elemMatch': {'type': 'translation', 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}
        ]}}}
      else
        trans_cond = {'meanings': {'$not': {'$elemMatch': {'$or': [
          {'relation': {'$elemMatch': {'type': 'translation', 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
          {'usages.relation': {'$elemMatch': {'type': 'translation', 'target': target, 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}
        ]}}}}
      end
    end

    # kombinace schvaleny a zadany
    # zadane+neschvalene = alespon jeden vyznam ma ciselny neschvaleny preklad
    if pubtrans == 'ne' and trans == 'ano'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': {'$ne': 'published'}, 'target': target, 'type': 'translation', 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
        {'usages.relation': {'$elemMatch': {'status': {'$ne': 'published'}, 'target': target, 'type': 'translation', 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}
      ]}}}
    end

    # nezadane+neschvalene = alespon jeden vyznam ma neciselny neschvaleny preklad, nebo nema zadny preklad
    if pubtrans == 'ne' and trans == 'ne'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': {'$ne': 'published'}, 'target': target, 'type': 'translation', 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}},
        {'usages.relation': {'$elemMatch': {'status': {'$ne': 'published'}, 'target': target, 'type': 'translation', 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}},
        {'$and': [
          {'relation': {'$not': {'$elemMatch': {'type': 'translation', 'target': target}}}},
          {'usages.relation': {'$not': {'$elemMatch': {'type': 'translation', 'target': target}}}}
        ]}
      ]}}}
    end

    #zadane+schvalene = alespon jeden vyznam ma ciselny schvaleny preklad
    if pubtrans == 'ano' and trans == 'ano'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': 'published', 'target': target, 'type': 'translation', 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}},
        {'usages.relation': {'$elemMatch': {'status': 'published', 'target': target, 'type': 'translation', 'meaning_id': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}
      ]}}}
    end

    # nezadane+schvalene = alespon jeden vyznam ma neciselny schvaleny preklad
    if pubtrans == 'ano' and trans == 'ne'
      trans_cond = {'meanings': {'$elemMatch': {'$or': [
        {'relation': {'$elemMatch': {'status': 'published', 'target': target, 'type': 'translation', 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}},
        {'usages.relation': {'$elemMatch': {'status': 'published', 'target': target, 'type': 'translation', 'meaning_id': {'$not': {'$regex': /^[-0-9]*(_us[0-9]*)?$/}}}}}
      ]}}}
    end

    $stdout.puts trans_cond
    return trans_cond
  end

  def get_report(params, user_info)
    report = {'query'=>{},'entries'=>[]}
    search_cond, trans_used = get_search_cond(params, user_info)
    entry_ids = []
    @entrydb.find({'$and': search_cond}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => 1}).each{|res|
      report['entries'] << res
      entry_ids << res['id']
    }
    $stdout.puts search_cond
    report['query'] = search_cond
    if params['koment'].to_s != ''
      report['koment'] = {}
      $mongo['koment'].find({'dict': @dictcode, 'entry': {'$in': entry_ids}}).each{|kom|
        report['koment'][kom['entry']] = [] if report['koment'][kom['entry']].nil?
        report['koment'][kom['entry']] << kom
      }
    end
    return report
  end

  def get_search_cond(params, user_info)
    search_cond = []
    trans_used = []

    search_cond << {'dict': @dictcode}

    # celni video schvalene
    if params['schvcelni'].to_s != ''
      vids = []
      $mongo['media'].find({'dict': @dictcode, 'status': 'published'}).each{|m| vids << m['location']}
      if params['schvcelni'].to_s == 'ano'
        search_cond << {'lemma.video_front': {'$in': vids}}
      else
        search_cond << {'lemma.video_front': {'$nin': vids}}
      end
    end

    # bocni video schvalene
    if params['schvbocni'].to_s != ''
      vids = []
      $mongo['media'].find({'dict': @dictcode, 'status': 'published'}).each{|m| vids << m['location']}
      if params['schvbocni'].to_s == 'ano'
        search_cond << {'lemma.video_side': {'$in': vids}}
      else
        search_cond << {'lemma.video_side': {'$nin': vids}}
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
    $dict_info.each{|code,hash| 
      if params['pubtrans'+code].to_s != '' or params['translation'+code].to_s != ''
        trans_cond = trans_cond(params['pubtrans'+code].to_s, params['translation'+code].to_s, code)
        search_cond << trans_cond if trans_cond != nil
      end
    }

    # komentare
    if params['koment'].to_s != '' and params['komentbox'].to_s != ''
      koment_ids = []
      koment_user = params['koment_user'].to_s
      komentbox = params['komentbox'].to_s
      koment_moje = params['koment_moje'].to_s
      koment_cond = {}

      if params['koment'].to_s == 'ano'
        if komentbox == ''
          if koment_user != ''
            koment_cond = {'user': {'$ne': koment_user}}
          else
            if koment_moje == 'on'
              koment_cond = {'user': {'$ne': user_info['login']}}
            end
          end
        else
          if komentbox == 'video'
            if koment_user != ''
              koment_cond = {'user': {'$ne': koment_user}, 'box': {'$not': {'$regex': /^video/}}}
            else
              if koment_moje == 'on'
                koment_cond = {'user': {'$ne': user_info['login']}, 'box': {'$not': {'$regex': /^video/}}}
              else
                koment_cond = {'box': {'$not': {'$regex': /^video/}}}
              end
            end
          elsif komentbox == 'vyznam'
            if koment_user != ''
              koment_cond = {'user': {'$ne': koment_user}, 'box': {'$not': {'$regex': /^vyznam/}}}
            else
              if koment_moje == 'on'
                koment_cond = {'user': {'$ne': user_info['login']}, 'box': {'$not': {'$regex': /^vyznam/}}}
              else
                koment_cond = {'box': {'$not': {'$regex': /^vyznam/}}}
              end
            end
          else
            if koment_user != ''
              koment_cond = {'user': {'$ne': koment_user}, 'box': {'$not': {'$regex': /#{komentbox}/}}}
            else
              if koment_moje == 'on'
                koment_cond = {'user': {'$ne': user_info['login']}, 'box': {'$not': {'$regex': /#{komentbox}/}}}
              else
                koment_cond = {'box': {'$not': {'$regex': /#{komentbox}/}}}
              end
            end
          end
        end
      else
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
              koment_cond = {'user': koment_user, '$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}
            else
              if koment_moje == 'on'
                koment_cond = {'user': user_info['login'], '$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}
              else
                koment_cond = {'$and': [{'box': {'$regex': /^vyznam/}}, {'box': {'$not': {'$regex': /vazby/}}}]}
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
      end
      koment_cond['dict'] = @dictcode
      $mongo['koment'].find(koment_cond).each{|kom|
        koment_ids << kom['entry']
      }
      search_cond << {'id': {'$in': koment_ids}}
    end

    # zadany SW
    if params['bez_sw'].to_s != ''
      if params['bez_sw'].to_s == 'ano' # zadany SW
        search_cond << {'$or': [
          {'lemma.lemma_type': {'$in': ['single','derivat','kompozitum']}, '$and': [{'lemma.sw': {'$exists': true}}, {'lemma.sw': {'$not': {'$size': 0}}}]},
          {'lemma.lemma_type': {'$in': ['fingerspell','collocation']}, '$and': [{'collocations.swcompos': {'$exists': true}}, {'collocations.swcompos': {'$ne': ''}}]}
        ]}
      else # nezadany SW
        search_cond << {'$or': [
          {'lemma.lemma_type': {'$in': ['single','derivat','kompozitum']},'$or': [{'lemma.sw': {'$exists': false}}, {'lemma.sw': {'$size': 0}}]},
          {'lemma.lemma_type': {'$in': ['fingerspell','collocation']},'$or': [{'collocations.swcompos': {'$exists': false}}, {'collocations.swcompos': ''}]}
        ]}
      end
    end

    # schvaleny SW
    if params['nes_sw'].to_s != ''
      if params['nes_sw'].to_s == 'ano' # schvaleny SW
        search_cond << {'$or': [
          {'lemma.lemma_type': {'$in': ['single','derivat','kompozitum']}, 'lemma.@swstatus': 'published'},
          {'lemma.lemma_type': {'$in': ['fingerspell','collocation']}, '$and': [{'collocations.swcompos': {'$exists': true}}, {'collocations.swcompos': {'$ne': ''}}]}
        ]}
      else # neschvaleny SW
        search_cond << {'$or': [
          {'lemma.lemma_type': {'$in': ['single','derivat','kompozitum']},'$or': [{'lemma.@swstatus': {'$exists': false}}, {'lemma.@swstatus': {'$ne': 'published'}}]},
          {'lemma.lemma_type': {'$in': ['fingerspell','collocation']},'$or': [{'collocations.swcompos': {'$exists': false}}, {'collocations.swcompos': ''}]}
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
      else
      end
    end

    # write, schvaleny priklad
    if params['usagecs'].to_s != ''
      if params['usagecs'].to_s == 'ano'
      else
      end
    end

    # write, zadany priklad
    if params['usagecszad'].to_s != ''
      if params['usagecszad'].to_s == 'ano'
      else
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
    #'vyznamcs',
    #'vyznamcszad',
    #'coll',
    #'autocomp',
    #'autocompbox',
    #'relpub',
    #'texttranslationen',
    #'trpriklad'


    return search_cond, trans_used
  end
end

