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

  def getdoc(id)
    $stderr.puts id
    $stderr.puts @dictcode

    data = @entrydb.find({'id': id, 'dict': @dictcode}).first
    $stderr.puts data
    entry = full_entry(data)
    entry = add_rels(entry)
    return entry
  end

  def full_entry(entry, getsw=true)
    entry = add_media(entry)
    entry = add_colloc(entry) if getsw
    entry = get_sw(entry) if getsw
    return entry
  end

  def add_colloc(entry)
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

    if entry['collocations'] and entry['collocations']['colloc']
      entry['collocations']['entries'] = []
      entry['collocations']['colloc'].uniq.each{|coll|
        ce = @entrydb.find({'dict': entry['dict'], 'id': coll}).first
        unless ce.nil?
          ce = add_colloc(ce)
          ce = get_sw(ce)
          entry['collocations']['entries'] << ce
        end
      }
    end
    return entry
  end

  def get_sw(entry)
    entry['lemma']['swmix'] = []
    if ['collocation','derivat','kompozitum','fingerspell'].include?(entry['lemma']['lemma_type'])
      if entry['collocations']
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
            $stderr.puts 'sw part '+swid
            if swid[0,2].upcase == 'SW'
              #copy from this entry
              swn = swid[2..-1].to_i-1
              entry['lemma']['swmix'] << entry['lemma']['sw'][swn].dup unless entry['lemma']['sw'][swn].nil?
            elsif swid.upcase =~ /^[A-Z]$/
              #copy from this entry
              $stderr.puts 'get SW char from this entry ' + swid + ' = ' + (swid[0].ord-65).to_s
              swn = swid[0].ord-65
              entry['lemma']['swmix'] << entry['lemma']['sw'][swn].dup unless entry['lemma']['sw'][swn].nil?
            else
              # copy from part
              if swid.upcase =~ /[A-Z]/
                # copy one char
                match = /([0-9]+)([A-Z]+)/.match(swid.upcase)
                unless match.nil?
                  $stderr.puts 'copy char '+swid+' ('+(match[1].to_i-1).to_s+':'+(match[2][0].ord-65).to_s+')'
                  if entry['collocations'] and entry['collocations']['entries']
                    unless entry['collocations']['entries'][match[1].to_i-1].nil?
                      unless entry['collocations']['entries'][match[1].to_i-1]['lemma']['sw'].first.nil?
                        entry['lemma']['swmix'] << entry['collocations']['entries'][match[1].to_i-1]['lemma']['sw'][match[2][0].ord-65].dup unless entry['collocations']['entries'][match[1].to_i-1]['lemma']['sw'][match[2][0].ord-65].nil?
                      else
                        entry['lemma']['swmix'] << entry['collocations']['entries'][match[1].to_i-1]['lemma']['swmix'][match[2][0].ord-65].dup unless entry['collocations']['entries'][match[1].to_i-1]['lemma']['swmix'][match[2][0].ord-65].nil?
                      end
                    end
                  end
                end
              else
                # copy full
                $stderr.puts 'copy full '+swid
                if entry['collocations'] and entry['collocations']['entries']
                  unless entry['collocations']['entries'][swid.to_i-1].nil?
                    if entry['collocations']['entries'][swid.to_i-1]['lemma']['swmix'].nil? or entry['collocations']['entries'][swid.to_i-1]['lemma']['swmix'].size == 0
                      entry['collocations']['entries'][swid.to_i-1]['lemma']['sw'].each{|swel|
                        entry['lemma']['swmix'] << swel.dup
                      }
                    else
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
        if entry['lemma']['sw'].find{|sw| sw['@primary'] == 'true'}
          # primary SW
          entry['lemma']['swmix'] = entry['lemma']['sw'].select{|sw| sw['@primary'] == 'true'}
        else
          # no primary SW
         entry['lemma']['swmix'] = entry['lemma']['sw'].dup
        end
      end
    end
    return entry
  end

  def get_media(media_id, dict)
    media = $mongo['media'].find({'id': media_id, 'dict': dict})
    if media.first
      media_info = media.first
      entries = $mongo['entries'].find({'dict': dict, 'lemma.video_front': media_info['location']})
      if entries.first
        media_info['main_for_entry'] = entries.first
      end
      return media_info
    else
      return {}
    end
  end

  def add_media(entry)
    entry['media'] = {}
    if entry['meanings']
      entry['meanings'].each{|mean|
        entry['media'][mean['text']['file']['@media_id']] = get_media(mean['text']['file']['@media_id'], entry['dict']) if mean['text'] and mean['text']['file']
        mean['usages'].each{|usg|
          entry['media'][usg['text']['file']['@media_id']] = get_media(usg['text']['file']['@media_id'], entry['dict']) if usg['text'] and usg['text']['file']
        }
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
    return entry
  end

  def add_rels(entry, getsw=true, type=nil, target=nil)
    entry['meanings'].each{|mean|
      if mean['relation']
        mean['relation'].each{|rel|
          next if type != nil and rel['type'] != type
          next if target != nil and rel['target'] != target
          if rel['meaning_id'] =~ /^[0-9]*-[0-9]*$/
            rela = rel['meaning_id'].split('-')
            lemmaid = rela[0]
            rel['meaning_nr'] = rela[1]
            relentry = @entrydb.find({'dict': rel['target'], 'id': lemmaid}).first
            next if relentry.nil?
            relentry = add_colloc(relentry) if getsw
            relentry = get_sw(relentry) if getsw
            rel['entry'] = relentry
          elsif rel['meaning_id'] =~ /^[0-9]*-[0-9]*_us[0-9]*$/
            rela = rel['meaning_id'].split('-')
            lemmaid = rela[0]
            relentry = @entrydb.find({'dict': rel['target'], 'id': lemmaid}).first
            next if relentry.nil?
            rel['entry'] = relentry
            if rel['entry']
              rel['entry']['meanings'].each{|rm|
                if rm['usages']
                  rm['usages'].each{|ru|
                    if ru['id'] == rel['meaning_id']
                      rel['entry']['lemma']['title'] = ru['text']['_text']
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
          mean['def_relations'][relid] = @entrydb.find({'dict': entry['dict'], 'id': relid}).first['lemma']['title']
        }
      end
    }
    return entry
  end

  def search(dictcode, search, type, params=nil)
    res = []
    search = search.downcase
    if search =~ /^[0-9]*$/
      @entrydb.find({'dict': dictcode, 'id': search}).each{|re|
        res << full_entry(re)
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
          search_cond = {'dict': dictcode, '$or': [{'lemma.title': search}, {'lemma.title_var': search}]}
          search_cond[:$or] << {'lemma.title_dia': search} 
          search_cond[:$or] << {'lemma.gram.form._text': search} 
          @entrydb.find(search_cond, :sort => {'lemma.title'=>1}).each{|re|
            res << re #full_entry(re)
            fullids << re['id']
          }
          search_cond = {'dict': dictcode, 'id': {'$nin': fullids}, '$or': [{'lemma.title': {'$regex': /^#{search}/}}]}
          search_cond[:$or] << {'lemma.title': {'$regex': /(^| )#{search}/}} 
          @entrydb.find(search_cond, {:collation => {'locale'=>locale}, :sort => {'lemma.title'=>1}}).each{|re|
            res << re #full_entry(re)
          }
      else
        search_in = 'cs'
        search_in = @dict_info[dictcode]['search_in'] unless @dict_info[dictcode]['search_in'].nil?
        csl = [search]
        $mongo['entries'].find({'dict'=>search_in, 'lemma.title'=> search}, {'projection'=>{'meanings.id'=>1, '_id'=>0}}).each{|re|
          unless re['meanings'].nil?
            re['meanings'].each{|rl| 
              csl << rl['id']
            }
          end
        }
        #$stderr.puts csl
        #@collection.find({'meanings'=>{'relation'=>{"$expr"=>{"$and"=>['target'=>'cs','meaning_id'=>{"$in"=>csl}]}}}}).each{|e|
        #@collection.find({'dict':@dictcode, 'relations.lemma.title':search}).each{|e|
        $mongo['entries'].find({'dict'=>dictcode, 'meanings.relation'=>{'$elemMatch'=>{'target'=>search_in,'meaning_id'=>{'$in'=>csl}}}}).each{|e|
          res << full_entry(e, false)
        }
      end
    end
    return res
  end

  def translate(source, target, search, type, params=nil)
    search_res = search(source, search, type, params)
    res = []
    search_res.select{|entry| 
      if entry['meanings']
        entry['meanings'].find{|mean| 
          mean['relation'].find{|rel| rel['target'] == target}
        }
      end
    }.each{|entry| 
      $stderr.puts entry['id']
      $stderr.puts 'add translation'
      entry = add_rels(entry, false, 'translation', target)
      $stderr.puts 'add syno'
      entry = add_rels(entry, false, 'synonym', source)
      $stderr.puts 'add anto'
      entry = add_rels(entry, false, 'antonym', source)
      #entry = get_sw(entry)
      res << entry
    }

    #pridat textove preklady, vcetne prekladu v prikladech
    search_cond = {'dict'=>target, '$or'=>[]}
    search_cond['$or'] << {'meanings.relation'=>{'$elemMatch'=>{'target'=>source,'meaning_id'=>{'$regex'=>/(^| )#{search}/}}}}
    search_cond['$or'] << {'meanings.usages.relation'=>{'$elemMatch'=>{'target'=>source,'meaning_id'=>{'$regex'=>/(^| )#{search}/}}}}
    $mongo['entries'].find(search_cond).each{|e|
      e['meanings'].each{|mean|
        next if mean['is_translation_unknown'].to_s == '1'
        mean['relation'].each{|rel|
          if rel['target'] == source and rel['meaning_id'].match(/(^| )#{search}/)
            newdoc = {'id'=>nil,'dict'=>source, 'lemma'=>{'title'=>rel['meaning_id']}, 'meanings'=>[{'relation'=>[{'target'=>target, 'meaning_id'=>mean['id'], 'lemma_id'=>e['id'], 'type'=>'translation', 'entry'=>e}]}]}
            res << newdoc
          end
        }
        if mean['usages']
          mean['usages'].each{|usg|
            if usg['relation']
              usg['relation'].each{|rel|
                if rel['target'] == source and rel['meaning_id'].match(/(^| )#{search}/)
                  newdoc = {'id'=>nil,'dict'=>source, 'lemma'=>{'title'=>rel['meaning_id']}, 'meanings'=>[{'relation'=>[{'target'=>target, 'meaning_id'=>usg['id'], 'lemma_id'=>e['id'], 'type'=>'translation', 'entry'=>e}]}]}
                  newdoc['meanings'][0]['relation'][0]['entry']['lemma']['video_front'] = get_media(usg['text']['file']['@media_id'], target)['location']
                  res << newdoc
                end
              }
            end
          }
        end
      }
    }
    return res
  end
end

