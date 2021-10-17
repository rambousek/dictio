class CZJDict < Object
  attr_accessor :dictcode
  attr_accessor :write_dicts
  attr_accessor :sign_dicts
  attr_accessor :dict_info

  def initialize(dictcode)
    @dictcode = dictcode 
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

  def get_comments(dict, id, type, exact=true)
    coms = []
    query = {'dict': dict, 'entry': id}
    if @sign_dicts.include?(dict) and type.start_with?('vyznam') and not type.include?('vazby')
      entrydata = getone(dict, id)
      if entrydata and entrydata['meanings']
        entrydata['meanings'].select{|m| m['id'] == type[6..-1]}.each{|m|
          if m['text'] and m['text']['file'] and m['text']['file']['@media_id']
            video = get_media(m['text']['file']['@media_id'], dict, false)
            if video
              type = 'video' + video['location']
            end
          end
        }
      end
    end

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

    # count revcolloc
    revcount = @entrydb.find({'dict': entry['dict'], 'collocations.colloc': entry['id'], 'lemma.lemma_type': 'collocation'}).count_documents
    if revcount > 0
      entry['revcollocation'] = {} if entry['revcollocation'].nil?
      entry['revcollocation']['count'] = revcount
    end
    revcount = @entrydb.find({'dict': entry['dict'], 'collocations.colloc': entry['id'], 'lemma.lemma_type': 'derivat'}).count_documents
    if revcount > 0
      entry['revderivat'] = {} if entry['revderivat'].nil?
      entry['revderivat']['count'] = revcount
    end
    revcount = @entrydb.find({'dict': entry['dict'], 'collocations.colloc': entry['id'], 'lemma.lemma_type': 'kompozitum'}).count_documents
    if revcount > 0
      entry['revkompozitum'] = {} if entry['revkompozitum'].nil?
      entry['revkompozitum']['count'] = revcount
    end

    if add_rev
      entry['revcollocation'] = {} if entry['revcollocation'].nil?
      entry['revcollocation']['entries'] = []
      if @write_dicts.include?(entry['dict'])
        locale = entry['dict']
        locale = 'sk' if entry['dict'] == 'sj'
        collate = {:collation => {'locale' => locale}, :sort => {'lemma.title' => 1}}
      else
        collate = { :sort => {'id'=>1}}
      end

      @entrydb.find({'dict': entry['dict'], 'collocations.colloc': entry['id'], 'lemma.lemma_type': 'collocation'}, collate).each{|ce|
        if @sign_dicts.include?(entry['dict'])
          ce = add_media(ce)
          ce = get_sw(ce)
        end
        entry['revcollocation']['entries'] << ce
      }
    end

    return entry, collocs_used
  end

  def get_revcolloc(entry_id, type)
    entry = getone(@dictcode, entry_id)
    if entry != nil
      entry['rev'+type] = {} if entry['rev'+type].nil?
      entry['rev'+type]['entries'] = []
      if @write_dicts.include?(entry['dict'])
        locale = entry['dict']
        locale = 'sk' if entry['dict'] == 'sj'
        collate = {:collation => {'locale' => locale}, :sort => {'lemma.title' => 1}}
      else
        collate = { :sort => {'id'=>1}}
      end

      @entrydb.find({'dict': entry['dict'], 'collocations.colloc': entry['id'], 'lemma.lemma_type': type}, collate).each{|ce|
        if @sign_dicts.include?(entry['dict'])
          ce = add_media(ce)
          ce = get_sw(ce)
        end
        entry['rev'+type]['entries'] << ce
      }
      return entry
    else
      return {'rev'+type=>{}}
    end
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
            if entry['lemma']['sw'] and entry['lemma']['sw'].find{|sw| sw['@primary'].to_s == 'true'}
              # primary SW
              entry['lemma']['swmix'] = entry['lemma']['sw'].select{|sw| sw['@primary'].to_s == 'true'}
            else
              # no primary SW
              entry['lemma']['swmix'] = entry['lemma']['sw'].dup
            end
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
    if entry['lemma']['grammar_note'] and entry['lemma']['grammar_note'][0] and entry['lemma']['grammar_note'][0]['_text']
      entry['lemma']['grammar_note'][0]['_text'].scan(/\[([0-9]+)(-[0-9]+)?\]/).each{|mrel|
        relid = mrel[0]
        entry['def_relations'] = {} if entry['def_relations'].nil?
        entry['def_relations'][relid] = getone(entry['dict'], relid)['lemma']['title']
      }
    end
    if entry['lemma']['style_note'] and entry['lemma']['style_note'][0] and entry['lemma']['style_note'][0]['_text']
      entry['lemma']['style_note'][0]['_text'].scan(/\[([0-9]+)(-[0-9]+)?\]/).each{|mrel|
        relid = mrel[0]
        entry['def_relations'] = {} if entry['def_relations'].nil?
        entry['def_relations'][relid] = getone(entry['dict'], relid)['lemma']['title']
      }
    end
    return entry
  end

  def get_key_search(search, swelement = 'lemma.sw')
      search_ar = search.split('|')
      search_shape = search_ar[0].to_s.split(',') #tvary
      search_jedno = []
      search_obe_ruzne = []
      search_obe_stejne = []
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
          e[swelement]['$elemMatch']['@misto'] = {'$in'=>search_loc}
          e
        }
        search_obe_stejne.map!{|e| 
          e[swelement]['$elemMatch']['@misto'] = {'$in'=>search_loc}
          e
        }
        search_obe_ruzne.map!{|e| 
          e[swelement]['$elemMatch']['@misto'] = {'$in'=>search_loc}
          e
        }
        if search_jedno.length == 0
          search_jedno << {swelement=>{'$elemMatch'=>{'@misto'=>{'$in'=>search_loc}}}}
        end
        if search_obe_ruzne.length == 0
          search_obe_ruzne << {swelement=>{'$elemMatch'=>{'@misto'=>{'$in'=>search_loc}}}}
        end
        if search_obe_stejne.length == 0
          search_obe_stejne << {swelement=>{'$elemMatch'=>{'@misto'=>{'$in'=>search_loc}}}}
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
          search_cond_title[:$or] << {'lemma.grammar_note.variant._text': {'$regex': /(^| )#{search}/i}}
          search_cond_title[:$or] << {'lemma.style_note.variant._text': {'$regex': /(^| )#{search}/i}}
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
          csl = [search]
          search_cond = {'source_dict': search_in, 'entry_text': {'$regex': /(^| )#{search}/i}, 'target': dictcode}
          $mongo['relation'].find(search_cond).each{|rl|
            csl << rl['target_id']
          }
          search_cond = {'source_dict': dictcode, 'source_id': {'$in': csl}}
          pipeline = [
            {'$match': search_cond},
            {'$group': {'_id': '$source_id', 'source_id': {'$first': '$source_id'}, 'source_dict': {'$first': '$source_dict'}, 'source_video': {'$first': '$source_video'}, 'source_sw': {'$first': '$source_sw'}, 'sort_key': {'$first': '$sort_key'}}}
          ]

          collate = {:collation => {'locale' => 'cs', 'numericOrdering'=>true}} 
          $stderr.puts search_cond
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
      search_query = {'dict'=>dictcode, '$or'=>get_key_search(search)}
      $stdout.puts search_query
      cursor = $mongo['entries'].find(search_query, {:sort => {'sort_key' => -1}})
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
          entry = add_rels(re, false, 'translation', target)
          entry = get_sw(entry)
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
      else
        if @write_dicts.include?(source)
          locale = source
          locale = 'sk' if source == 'sj'
          collate = {:collation => {'locale' => locale}, :sort => {'sort_title' => 1, 'sort_key' => -1}}
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
    return {'count'=> resultcount, 'relations'=> res}
  end

  def translate0(source, target, search, type, start=0, limit=nil)
    res = []
    resultcount = 0
    case type
    when 'text'
      search = search.downcase
      if search =~ /^[0-9]*$/
        resultcount = 0
        @entrydb.find({'dict': dictcode, 'id': search, 'meanings.relation.target': target}).each{|re|
          entry = add_rels(re, false, 'translation', target)
          entry = get_sw(entry)
          res << entry
          resultcount = 1
        }
      else
        if @write_dicts.include?(source)
          locale = source
          locale = 'sk' if source == 'sj'
          search_cond_text = []
          search_cond_text << {'lemma.title': search}
          search_cond_text << {'lemma.title_var': search}
          search_cond_text << {'lemma.title_dia': search}
          search_cond_text << {'lemma.gram.form._text': search}
          search_cond_text << {'lemma.title': {'$regex': /^#{search}/i}}
          search_cond_text << {'lemma.title': {'$regex': /(^| )#{search}/i}}
          search_cond_text << {'lemma.grammar_note.variant._text': {'$regex': /(^| )#{search}/i}}
          search_cond_text << {'lemma.style_note.variant._text': {'$regex': /(^| )#{search}/i}}
          search_cond1 = {'dict': dictcode, '$or': search_cond_text}
          search_cond2 = {'dict': target, 'meanings.relation': {'$elemMatch': {'target': dictcode, 'type': 'translation', 'meaning_id': {'$regex': /(^| )#{search}/i}, 'status': 'published'}}}
          search_cond3 = {'dict': target, 'meanings.usages': {'$elemMatch': {'status': 'published', 'relation': {'$elemMatch': {'target': dictcode, 'type': 'translation', 'meaning_id': {'$regex': /(^| )#{search}/i}}}}}}
          search_cond_rel1 = {'meanings.relation.target': target, 'meanings.relation.type': 'translation', 'meanings.relation.status': 'published', 'meanings.relation.meaning_id': {'$regex': /^[0-9]+-[0-9]+(_us[0-9]+)?/}}
          search_cond_rel2 = {'meanings.relation.target': dictcode, 'meanings.relation.type': 'translation', 'meanings.relation.status': 'published', 'meanings.relation.meaning_id': {'$regex': /(^| )#{search}/i}}
          search_cond_rel3 = {'meanings.usages.relation.target': dictcode, 'meanings.usages.relation.type': 'translation', 'meanings.usages.relation.meaning_id': {'$regex': /(^| )#{search}/i}}
          $stdout.puts search_cond1
          $stdout.puts search_cond2
          $stdout.puts search_cond3
          pipeline = [
            {'$match': search_cond1},
            {'$unwind': '$meanings'},
            {'$unwind': '$meanings.relation'},
            {'$match': search_cond_rel1},
            {'$project': {'dict': 1, 'id': 1, 'meanings': 1, 'lemma': 1, 'title': '$lemma.title'}},
            {'$unionWith': {
              'coll': 'entries',
              'pipeline': [
                {'$match': search_cond2},
                {'$unwind': '$meanings'},
                {'$unwind': '$meanings.relation'},
                {'$match': search_cond_rel2},
                {'$project': {'dict': 1, 'id': 1, 'meanings': 1, 'lemma': 1, 'title': '$meanings.relation.meaning_id'}}
              ]
            }},
            {'$unionWith': {
              'coll': 'entries',
              'pipeline': [
                {'$match': {'dict': dictcode, 'meanings.usages.text._text': {'$regex': /(^| )#{search}/i}}},
                {'$unwind': '$meanings'},
                {'$unwind': '$meanings.usages'},
                {'$match': {"meanings.usages.text._text": {'$regex':/(^| )#{search}/i}}},
                {'$unwind': '$meanings.usages.relation'},
                {'$match': {'meanings.usages.relation.type': 'translation', 'meanings.usages.relation.target': target, 'meanings.usages.relation.meaning_id': {'$regex':/^[0-9]+-[0-9]+(_us[0-9]+)?/}}},
                {'$group': {'_id': '$_id', 'dict': {'$first': '$dict'}, 'id': {'$first': '$id'}, 'lemma': {'$first': '$lemma'}, 'title': {'$first': '$meanings.usages.text._text'}, 'relation': {'$first': '$meanings.usages.relation'}, 'usagestatus': {'$first': '$meanings.usages.status'}}},
                {'$project': {'dict': 1, 'id': 1, 'title': 1, 'meanings.relation': '$relation', 'lemma.title': '$title', 'usagestatus': '$usagestatus'}}
              ]
            }},
            {'$unionWith': {
              'coll': 'entries',
              'pipeline': [
                {'$match': search_cond3},
                {'$unwind': '$meanings'},
                {'$unwind': '$meanings.usages'},
                {'$match': {'meanings.usages.status': 'published'}},
                {'$unwind': '$meanings.usages.relation'},
                {'$match': search_cond_rel3},
                {'$group': {'_id': '$_id', 'dict': {'$first': '$dict'}, 'id': {'$first': '$id'}, 'lemma': {'$first': '$lemma'}, 'title': {'$first': '$meanings.usages.relation.meaning_id'}, 'relation': {'$first': '$meanings.usages.relation'}, 'usagestatus': {'$first': '$meanings.usages.status'}, 'usagemedia': {'$first': '$meanings.usages.text.file.@media_id'}}},
                {'$project': {'dict': 1, 'id': 1, 'title': 1, 'meanings.relation': '$relation', 'lemma.title': '$title', 'usagestatus': '$usagestatus', 'usagemedia': 1}}
              ]
            }},
            {'$sort': {'title'=>1}}
          ]
          @entrydb.aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
            resultcount = re['total'].to_i
          }
          pipeline << {'$skip' => start.to_i}
          pipeline << {'$limit' => limit.to_i} if limit.to_i > 0
          cursor = @entrydb.aggregate(pipeline, {:allow_disk_use => true, :collation => {'locale' => locale}})
          cursor.each{|re|
            if re['usagestatus'].to_s != '' and re['meanings']['relation']['status'].to_s == ''
              re['meanings']['relation']['status'] = re['usagestatus'].to_s
            end
            if re['usagemedia'].to_s != ''
              re['lemma']['video_front'] = get_media(re['usagemedia'].to_s, re['dict'])['location']
            end
            re['meanings']['relation'] = [re['meanings']['relation']]
            re['meanings'] = [re['meanings']]
            $stdout.puts 'start res<e '+re['dict']+re['id']+' '+Time.now.to_s
            if re['dict'] == dictcode
              $stdout.puts 'start addrels '+re['id']+' '+Time.now.to_s
              entry = add_rels(re, false, 'translation', target)
            end
            if re['dict'] == target
              $stdout.puts 'start addrels2 '+re['id']+' '+Time.now.to_s
              entry = add_rels(re, false, 'translation', dictcode)
              $stdout.puts 'start addmedia '+re['id']+' '+Time.now.to_s
              entry = add_media(entry, true)
            end
            $stdout.puts 'start getsw '+re['id']+' '+Time.now.to_s
            entry = get_sw(entry)
            $stdout.puts 'end '+re['id']+' '+Time.now.to_s
            res << entry
          }
        else
          search_in = 'cs'
          search_in = @dict_info[dictcode]['search_in'] unless @dict_info[dictcode]['search_in'].nil?
          csl = [search]
          search_cond_text = []
          search_cond_text << {'lemma.title': search}
          search_cond_text << {'lemma.title_var': search}
          search_cond_text << {'lemma.title_dia': search}
          search_cond_text << {'lemma.gram.form._text': search}
          search_cond_text << {'lemma.title': {'$regex': /^#{search}/i}}
          search_cond_text << {'lemma.title': {'$regex': /(^| )#{search}/i}}
          search_cond_text << {'lemma.grammar_note.variant._text': {'$regex': /(^| )#{search}/i}}
          search_cond_text << {'lemma.style_note.variant._text': {'$regex': /(^| )#{search}/i}}
          $mongo['entries'].find({'dict'=>search_in, '$or'=>search_cond_text}, {'projection'=>{'meanings.id'=>1, '_id'=>0}}).each{|re|
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
      $stdout.puts "update sw"
      data['lemma']['sw'].each{|sw|
        sw['@fsw'] = get_fsw(sw['_text']) if sw['@fsw'] == ''
      }
    end

    #add homonym
    if data['lemma']['homonym'] and data['lemma']['homonym'].to_s != ''
      add_homonym_target(data['lemma']['homonym'], entryid)
    end

    #add variants 
    fmedia = get_media_location(data['lemma']['video_front'].to_s, @dictcode)
    if fmedia['id'].to_s 
      if data['lemma']['grammar_note']
        data['lemma']['grammar_note'].each{|grn|
          if grn['variant']
            grn['variant'].each{|var|
              if var['_text'].to_s != ''
                add_variant_target('grammar', var['_text'].to_s, fmedia['id'])
              end
            }
          end
        }
      end
      if data['lemma']['style_note']
        data['lemma']['style_note'].each{|grn|
          if grn['variant']
            grn['variant'].each{|var|
              if var['_text'].to_s != ''
                add_variant_target('style', var['_text'].to_s, fmedia['id'])
              end
            }
          end
        }
      end
    end

    #sortkey
    data['sort_key'] = get_sortkey(data)

    #save media info
    if data['update_video']
      $stdout.puts "update video"
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
    if @sign_dicts.include?(dict)
      $stdout.puts "update sw cache"
      $mongo['sw'].find({'dict': dict, 'entries_used': entryid}).delete_many
      cache_all_sw(false)
    end

    #update relations cache
    Thread.new{ cache_relations(data, true) }

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

  def add_homonym_target(entryid, homonym)
    doc = getone(@dictcode, entryid)
    if doc
      if doc['lemma']['homonym'].nil? or doc['lemma']['homonym'].to_s != homonym
        doc['lemma']['homonym'] = homonym
        $stdout.puts 'add homonym to target '+entryid + ':' + homonym
        @entrydb.find({'dict'=>doc['dict'], 'id'=>doc['id']}).delete_many
        @entrydb.insert_one(doc)
      end
    end
  end

  def add_variant_target(type, variant_media, origin_media)
    vmedia = get_media(variant_media, @dictcode)
    if vmedia['location'].to_s != ''
      query = {'dict' => @dictcode, 'lemma.video_front' => vmedia['location'].to_s}
      @entrydb.find(query).each{|doc|
        if doc['lemma'][type+'_note'].nil? or doc['lemma'][type+'_note'][0].nil?
          doc['lemma'][type+'_note'] = [{'variant' => []}]
        end
        if doc['lemma'][type+'_note'][0]['variant'].nil?
          doc['lemma'][type+'_note'][0]['variant'] = []
        end
        if not doc['lemma'][type+'_note'][0]['variant'].any?{|var| var['_text'] == origin_media}
          doc['lemma'][type+'_note'][0]['variant'] << {'_text' => origin_media}
          $stdout.puts 'add variant to entry '+ doc['id']+ ':' + origin_media + ' ' + type
          @entrydb.find({'dict'=>doc['dict'], 'id'=>doc['id']}).delete_many
          @entrydb.insert_one(doc)
        end
      }
    end
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
    if @sign_dicts.include?(@dictcode) and box.start_with?('vyznam') and not box.include?('vazby')
      entrydata = getone(@dictcode, entry)
      if entrydata and entrydata['meanings']
        entrydata['meanings'].select{|m| m['id'] == box[6..-1]}.each{|m|
          if m['text'] and m['text']['file'] and m['text']['file']['@media_id']
            video = get_media(m['text']['file']['@media_id'], @dictcode, false)
            if video
              box = 'video' + video['location']
            end
          end
        }
      end
    end
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
              files << us['text']['file']['@media_id'] if us['text'] and us['text']['file'] and us['text']['file'].is_a?(Hash) and us['text']['file']['@media_id']
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
    $mongo['relation'].find({'source_dict': @dictcode, 'source_id': entry_id}).delete_many
    $mongo['relation'].find({'target': @dictcode, 'target_id': entry_id}).delete_many
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
    filename = filename[0,2]+filename[2..-1].gsub('_','-')
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
    $stdout.puts data
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
    if data['id'].to_s == ''
      cursor = $mongo['media'].find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
      cursor = cursor.limit(1)
      mediaid = 1
      cursor.each{|r|
        mediaid = r['id'].to_i + 1
      }
      media = {'id' => mediaid}
    else
      media = get_media(data['id'].to_s, @dictcode)
    end

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
    media.delete('main_for_entry')
    $mongo['media'].find({'dict'=> @dictcode, 'id'=> data['id']}).delete_many
    $mongo['media'].insert_one(media)
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

  def get_report(params, user_info, start=0, limit=nil)
    report = {'query'=>{},'entries'=>[], 'resultcount'=>0}
    search_cond, trans_used = get_search_cond(params, user_info)
    $stdout.puts search_cond
    entry_ids = []
    cursor = @entrydb.find({'$and': search_cond}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => 1})
    report['resultcount'] = cursor.count_documents
    cursor = cursor.skip(start)
    cursor = cursor.limit(limit) if limit.to_i > 0
    cursor.each{|res|
      entry = res
      if params['nes_sw'].to_s != '' or params['bez_sw'].to_s != ''
        entry = get_sw(entry)
      end
      report['entries'] << entry
      entry_ids << res['id']
    }
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

    search_cond << {'dict': @dictcode, 'empty': {'$exists': false}}

    # zadane ID
    if params['idsf'].to_s != ''
      idfa = params['idsf'].to_s.strip.split(/[,;\s]/)
      idfa.reject!(&:empty?)
      search_cond << {'id': {'$in': idfa}}
    end

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

  def get_videoreport(params, start=0, limit=nil)
    report = {'entries'=>[], 'resultcount'=>0, 'query'=>{}}
    search_cond = {'dict': @dictcode}
    if params['type_a'].to_s == '1' or params['type_b'].to_s == '1' or params['type_d'].to_s == '1' or params['type_k'].to_s == '1'
      types = []
      types << 'sign_front' if params['type_a'].to_s == '1'
      types << 'sign_side' if params['type_b'].to_s == '1'
      types << 'sign_definition' if params['type_d'].to_s == '1'
      types << 'sign_usage_example' if params['type_k'].to_s == '1'
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
        {'meanings.usages.text.file.@media_id': res['id']}
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
    if params['type_a'].to_s == '1' or params['type_b'].to_s == '1' or params['type_d'].to_s == '1' or params['type_k'].to_s == '1'
      types = []
      types << 'sign_front' if params['type_a'].to_s == '1'
      types << 'sign_side' if params['type_b'].to_s == '1'
      types << 'sign_definition' if params['type_d'].to_s == '1'
      types << 'sign_usage_example' if params['type_k'].to_s == '1'
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
      ri = [res['location']]
      entries_used = []
      ri << res['entryDocs'].select{|e| e['dict'] == res['dict']}.collect{|e| e['id']}.join(', ')
      ri << entries_used.join(', ')
      ri << res['id_meta_author']
      ri << res['id_meta_source']
      ri << res['id_meta_copyright']
      report['entries'] << ri.join(';')
    }
    return report['entries']
  end

  def get_users
    res = []
    $mongo['users'].find({}, :sort => {'login' => 1}).each{|us|
      res << us
    }
    return res
  end

  def save_user(data)
    if data['login'].to_s != ''
      user = $mongo['users'].find({'login': data['login']}).first
      if data['password'].to_s == '' and user != nil
        data['password'] = user['password']
      elsif data['password'].to_s != ''
        data['password'] = data['password'].crypt((Random.rand(1900)+100).to_s(16)[0,2])
      else
        data['password'] = (Random.rand(19000000)+200000000).to_s(16).crypt((Random.rand(1900)+100).to_s(16)[0,2])
      end
      $mongo['users'].find({'login': data['login']}).delete_many
      $mongo['users'].insert_one(data)
      return true
    else
      return 'chybí login'
    end
  end
  def delete_user(login)
    if login.to_s != ''
      $mongo['users'].find({'login': login.to_s}).delete_many
      return true
    else
      return 'chybí login'
    end
  end

  def get_duplicate_pipeline(dict, remove_syno=true, second=false)
    if @dict_info[dict]['type'] == 'write'
      group = {'lemma': '$lemma.title'}
      sort = {'_id.lemma': 1}
    else
      if not second
        group = {'front': '$lemma.video_front', 'side': '$lemma.video_side'}
      else
        group = {'trans': '$meanings.relation'}
      end
      sort = {'_id.front': 1, '_id.trans': 1, '_id.ids': 1}
    end

    pipeline = []
    if not second
      if @dict_info[dict]['type'] == 'write'
        match = {'dict': dict, 'empty': {'$exists': false}}
      else
        match = {'dict': dict, 'empty': {'$exists': false}, '$and': [{'$or': [{'lemma.grammar_note.variant':{'$size': 0}}, {'lemma.grammar_note.variant': {'$exists': false}}]}, {'$or': [{'lemma.style_note.variant':{'$size': 0}}, {'lemma.style_note.variant': {'$exists': false}}]}]}
      end
    else
      match = {'dict': dict, 'empty': {'$exists': false}, '$and': [{'meanings.relation': {'$elemMatch': {'type': 'translation'}}}, {'$or': [{'lemma.grammar_note.variant':{'$size': 0}}, {'lemma.grammar_note.variant': {'$exists': false}}]}, {'$or': [{'lemma.style_note.variant':{'$size': 0}}, {'lemma.style_note.variant': {'$exists': false}}]}]}
      match[:$and] << {'meanings.relation': {'$not': {'$elemMatch': {'type': 'synonym'}}}} if remove_syno
    end
    pipeline << {'$match': match}
    if second
      pipeline << {'$unwind': '$meanings'}
      pipeline << {'$unwind': '$meanings.relation'}
    end
    pipeline << {'$group': {
      '_id': group,
      'ids': {'$addToSet': '$id'}, 
      'pos': {'$addToSet': '$lemma.grammar_note.@slovni_druh'}, 
      'count': {'$sum': 1}
    }}
    if @dict_info[dict]['type'] == 'sign' and not second
      pipeline << {'$unionWith': {
        'coll': 'entries',
        'pipeline': get_duplicate_pipeline(dict, remove_syno, true)
      }}
    end
    pipeline << {'$match': { 
      'count': {'$gt': 1},
      '_id': {'$ne': {}},
      'ids': {'$not': {'$size': 1}},
      '$or':[
        {'pos':{'$size':1}},
        {'pos': {'$in':[[]]}},
        {'pos': {'$in':[['']]}}
      ]
    }}
    if not second
    pipeline << {'$group': {
      '_id': {'ids':'$ids'},
      'lemma': {'$first': '$_id.lemma'},
      'front': {'$first': '$_id.front'},
      'trans': {'$addToSet': '$_id.trans'}
    }}
    end
    pipeline << {'$sort': sort}
    $stdout.puts pipeline
    return pipeline
  end

  def get_duplicate(start=0, limit=nil)
    pipeline = get_duplicate_pipeline(@dictcode)
    if @dict_info[@dictcode]['type'] == 'write'
      locale = @dictcode
      locale = 'sk' if @dictcode == 'sj'
    else
      locale = 'cs'
    end
    pipeline << {'$skip' => start.to_i}
    pipeline << {'$limit' => limit.to_i} if limit.to_i > 0

    res = {'count'=> 0, 'duplicate'=> []}
    @entrydb.aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
      res['count'] = re['total'].to_i
    }
    cursor = @entrydb.aggregate(pipeline, {:allow_disk_use => true, :collation => {'locale' => locale}})
    cursor.each{|re|
      if re['_id']['ids'] and not re['front']
        doc = getone(@dictcode, re['_id']['ids'][0])
        re['front'] = doc['lemma']['video_front'].to_s if doc['lemma']
      end
      res['duplicate'] << re
    }
    return res
  end

  def get_duplicate_syno(start=0, limit=nil)
    pipeline = get_duplicate_pipeline(@dictcode, false)
    if @dict_info[@dictcode]['type'] == 'write'
      locale = @dictcode
      locale = 'sk' if @dictcode == 'sj'
    else
      locale = 'cs'
    end
    pipeline << {'$skip' => start.to_i}
    pipeline << {'$limit' => limit.to_i} if limit.to_i > 0

    res = {'count'=> 0, 'duplicate'=> []}
    cursor = @entrydb.aggregate(pipeline, {:allow_disk_use => true, :collation => {'locale' => locale}})
    cursor.each{|re|
      if re['_id']['ids'] and not re['front']
        doc = getone(@dictcode, re['_id']['ids'][0])
        re['front'] = doc['lemma']['video_front'].to_s if doc['lemma']
      end
      add_re = true
      if re['_id']['ids']
        syno_num = 0
        re['_id']['ids'].each{|id|
          doc = getone(@dictcode, id)
          if doc['meanings']
            doc['meanings'].each{|me|
              if me['relation']
                me['relation'].select{|rel| rel['type'] == 'synonym'}.each{|rel|
                  start = rel['meaning_id'].split('-')[0]
                  syno_num += 1 if re['_id']['ids'].include?(start)
                }
              end
            }
          end
        }
        add_re = false if syno_num >= re['_id']['ids'].size
      end
      res['duplicate'] << re if add_re
    }
    res['count'] = res['duplicate'].size
    return res
  end

  def get_duplicate_counts
    res = {'duplicate' => []}
    @dict_info.each{|code,hash|
      pipeline = get_duplicate_pipeline(code)
      @entrydb.aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
        count = re['total'].to_i
        res['duplicate'] << {'code'=>code, 'count'=>count}
      }
    }
    return res
  end

  def get_relation_notrans(user = '')
    res = {'notrans' => [], 'count'=>0}
    @entrydb.find({'meanings.relation': {'$elemMatch': {'notrans': true, 'target': @dictcode}}}).each{|re|
      re['meanings'].each{|rm|
        if rm['relation']
          rm['relation'].each{|rr|
            if rr['notrans'] and rr['notrans'] == true and rr['target'] == @dictcode and (user == '' or rr['notransuser'].start_with?(user+' '))
              ren = {'id' => re['id'], 'dict' => re['dict']}
              ren['relation'] = {'meaning' => rm['id'], 'target' => rr['target'], 'trans' => rr['meaning_id'], 'notransuser' => rr['notransuser']}
              comm = get_comments(re['dict'], re['id'], 'meaning'+rm['id']+'rel'+rr['target']+rr['meaning_id'])[:comments]
              ren['comment'] = comm[0] if comm.size > 0
              res['notrans'] << ren
            end
          }
        end
      }
    }
    return res
  end
  def get_relation_notrans2(user = '')
    res = {'notrans' => [], 'count'=>0}
    @entrydb.find({'dict': @dictcode, 'meanings.relation.notrans': true}).each{|re|
      re['meanings'].each{|rm|
        if rm['relation']
          rm['relation'].each{|rr|
            if rr['notrans'] and rr['notrans'] == true and (user == '' or rr['notransuser'].start_with?(user+' '))
              ren = {'id' => re['id'], 'dict' => re['dict']}
              ren['relation'] = {'meaning' => rm['id'], 'target' => rr['target'], 'trans' => rr['meaning_id'], 'notransuser' => rr['notransuser']}
              comm = get_comments(re['dict'], re['id'], 'meaning'+rm['id']+'rel'+rr['target']+rr['meaning_id'])[:comments]
              ren['comment'] = comm[0] if comm.size > 0
              res['notrans'] << ren
            end
          }
        end
      }
    }
    return res
  end

  def save_user_settting(user_info, new_info)
    user_data = $mongo['users'].find({'login': user_info['login']}).first
    if user_data.nil?
      return false
    else
      if new_info['password'].to_s != ''
        user_data['password'] = new_info['password'].crypt((Random.rand(1900)+100).to_s(16)[0,2])
      end
      user_data['default_lang'] = new_info['default_lang'].to_s
      user_data['default_dict'] = new_info['default_dict'].to_s
      user_data['email'] = new_info['email'].to_s
      user_data['name'] = new_info['name'].to_s
      $mongo['users'].find({'login': user_info['login']}).delete_many
      $mongo['users'].insert_one(user_data)
      return true
    end
  end

  def cache_all_relations(delete_existing=true)
    count = {'inserted' => 0, 'deleted' => 0}
    if delete_existing
      res = $mongo['relation'].find({'source_dict': @dictcode}).delete_many
      count['deleted'] = res.deleted_count
    end
    @entrydb.find({'dict': @dictcode, '$or': [{'meanings.relation': {'$exists': true}}, {'meanings.usages.relation': {'$exists': true}}]}).each{|entry|
      count['inserted'] += cache_relations(entry)
    }
    return count
  end

  def cache_relations_entry(dict, entry_id)
    entry = getone(dict, entry_id)
    count = cache_relations(entry, true)
    return count
  end

  def cache_relations(entry, cache_related=false)
    count = 0
    $mongo['relation'].find({'source_dict': entry['dict'], 'source_id': entry['id']}).delete_many
    rels = []
    to_check = []
    entry = get_sw(entry)
    if entry['meanings']
      entry['meanings'].each{|mean|
        if mean['relation']
          mean['relation'].each{|rel|
            rel['source_dict'] = entry['dict']
            rel['source_id'] = entry['id']
            rel['source_meaning_id'] = mean['id']
            texts = []
            if entry['lemma']['title']
              texts << entry['lemma']['title'] 
              rel['source_title'] = entry['lemma']['title']
            end
            texts << entry['lemma']['title_var'] if entry['lemma']['title_var']
            texts << entry['lemma']['title_dia'] if entry['lemma']['title_dia']
            if entry['lemma']['gram'] and entry['lemma']['gram']['form'] and entry['lemma']['gram']['form'].is_a?(Array)
              entry['lemma']['gram']['form'].each{|gr|
                texts << gr['_text'] if gr['_text']
              }
            end
            if entry['lemma']['grammar_note'] and entry['lemma']['grammar_note'][0]['variant']
              entry['lemma']['grammar_note'][0]['variant'].each{|var|
                texts << var['_text'] if var['_text']
              }
            end
            if entry['lemma']['style_note'] and entry['lemma']['style_note'][0]['variant']
              entry['lemma']['style_note'][0]['variant'].each{|var|
                texts << var['_text'] if var['_text']
              }
            end
            rel['entry_text'] = texts.uniq
            rel['source_video'] = get_media_location(entry['lemma']['video_front'], entry['dict']) if entry['lemma']['video_front']
            rel['source_sw'] = entry['lemma']['swmix'] if entry['lemma']['swmix']

            if rel['meaning_id'] =~ /^[0-9]+-.*/
              rela = rel['meaning_id'].split('-')
              rel['target_id'] = rela[0]
              rel['meaning_nr'] = rela[1].to_s
              to_check << {'dict' => rel['target'], 'id' => rel['target_id']}
              targetentry = getone(rel['target'], rel['target_id'])
              if targetentry
                targetentry = get_sw(targetentry)
                if rel['meaning_nr'].include?('_us')
                  if $dict_info[targetentry['dict']]['type'] == 'write'
                    rel['target_title'] = get_usage_target(targetentry, rel['meaning_id'])
                  else
                    rel['target_video'] = get_usage_target(targetentry, rel['meaning_id'])
                  end
                else
                  rel['target_title'] = targetentry['lemma']['title'] if targetentry['lemma']['title']
                  rel['target_video'] = get_media_location(targetentry['lemma']['video_front'], rel['target']) if targetentry['lemma']['video_front']
                  rel['target_sw'] = targetentry['lemma']['swmix'] if targetentry['lemma']['swmix']
                end
              end
              if $dict_info[entry['dict']]['type'] == 'write'
                rel['sort_title'] = entry['lemma']['title']
                rel['sort_key'] = get_sortkey(targetentry)
              else
                rel['sort_key'] = get_sortkey(entry)
              end
            else
              rel['target_title'] = rel['meaning_id']
              rel['sort_title'] = rel['meaning_id']
              rel['sort_key'] = get_sortkey(entry)
            end
            rels << rel
          }
        end
        if mean['usages']
          mean['usages'].each{|usg|
            if usg['relation']
              usg['relation'].each{|rel|
                rel['source_dict'] = entry['dict']
                rel['source_id'] = entry['id']
                rel['source_meaning_id'] = mean['id']
                rel['source_usage_id'] = usg['id']
                rel['status'] = usg['status']
                texts = []
                if usg['text'] and usg['text']['_text']
                  texts << usg['text']['_text'] 
                  rel['usage_text'] = usg['text']['_text']
                  rel['source_title'] = usg['text']['_text']
                end
                rel['source_video'] = get_media(usg['text']['file']['@media_id'], entry['dict'], false) if usg['text']['file'] and usg['text']['file']['@media_id']
                rel['source_sw'] = entry['lemma']['swmix'] if entry['lemma']['swmix']
                rel['entry_text'] = texts.uniq
                if rel['meaning_id'] =~ /^[0-9]+-.*/
                  rela = rel['meaning_id'].split('-')
                  rel['target_id'] = rela[0]
                  rel['meaning_nr'] = rela[1]
                  to_check << {'dict' => rel['target'], 'id'=> rel['target_id']}
                  targetentry = getone(rel['target'], rel['target_id'])
                  if targetentry
                    targetentry = get_sw(targetentry)
                    if rel['meaning_nr'].include?('_us')
                      if $dict_info[targetentry['dict']]['type'] == 'write'
                        rel['target_title'] = get_usage_target(targetentry, rel['meaning_id'])
                      else
                        rel['target_video'] = get_usage_target(targetentry, rel['meaning_id'])
                      end
                    else
                      rel['target_title'] = targetentry['lemma']['title'] if targetentry['lemma']['title']
                      rel['target_video'] = get_media_location(targetentry['lemma']['video_front'], targetentry['dict']) if targetentry['lemma']['video_front']
                      rel['target_sw'] = targetentry['lemma']['swmix'] if targetentry['lemma']['swmix']
                    end
                  end
                  if $dict_info[entry['dict']]['type'] == 'write'
                    rel['sort_title'] = rel['source_title']
                    rel['sort_key'] = get_sortkey(targetentry)
                  else
                    rel['sort_key'] = get_sortkey(entry)
                  end
                else
                  rel['target_title'] = rel['meaning_id']
                  rel['sort_title'] = rel['meaning_id']
                  rel['sort_key'] = get_sortkey(entry)
                end
                rels << rel
              }
            end
          }
        end
      }
      if rels.length > 0
        res = $mongo['relation'].insert_many(rels)
        count += res.inserted_count
      end
    end

    if cache_related
      $mongo['relation'].find({'target': entry['dict'], 'meaning_id': {'$regex': /^#{entry['id']}-.*/}}).delete_many
      to_check.uniq.each{|rel|
        entry = getone(rel['dict'], rel['id'])
        if entry
          count += cache_relations(entry, false)
        end
      }
    end

    return count
  end

  def get_usage_target(entry, usage_id)
    if entry['meanings']
      entry['meanings'].each{|mean|
        if mean['usages']
          mean['usages'].select{|u| u['id'] == usage_id}.each{|usg|
            if $dict_info[entry['dict']]['type'] == 'write'
              if usg['text']['_text']
                return usg['text']['_text']
              else
                return ''
              end
            else
              if usg['text']['file'] and usg['text']['file']['@media_id']
                return get_media(usg['text']['file']['@media_id'], entry['dict'], false)
              else
                return {}
              end
            end
          }
        end
      }
    end
  end

  def get_sortkey(entry)
    regionkey = 0
    if entry
      if entry['lemma']['grammar_note'] and entry['lemma']['grammar_note'][0] and entry['lemma']['grammar_note'][0]['@region']
        region = entry['lemma']['grammar_note'][0]['@region'] 
        regionkey = (region=='cr'?7:0) + (region=='cechy'?6:0) + (region=='praha'?5:0) + (region=='morava'?4:0) + (region=='brno'?3:0)
      end
      regionkey = 2 if regionkey == 0
      regionkey = 1 if entry['lemma']['style_note'] and entry['lemma']['style_note'][0] and entry['lemma']['style_note'][0]['@kategorie'].to_s == 'arch'
      regionkey = regionkey*10000000 + entry['id'].to_i
    end
    return regionkey.to_s
  end
end

