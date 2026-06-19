# Core entry retrieval & composition: fetching, assembling full entries, homonyms, collocations, relations resolution.
module CzjEntry
  def getdoc(id, add_rev=true)
    $stdout.puts id
    $stdout.puts @dictcode
    
    $stdout.puts 'START getdoc '+Time.now.to_s
    data = getone(@dictcode, id)
    $stdout.puts data
    if data != nil
      entry = full_entry(data, add_rev)
      entry = add_rels(entry, add_rev)
      if entry['lemma']['homonym'].to_s != ''
        entry = add_homonym(entry)
      end
      $stdout.puts 'END getdoc '+Time.now.to_s
      entry
    else
      {}
    end
  end

  def getone(dict, id)
    $stdout.puts 'START getone '+Time.now.to_s
    data = @entrydb.find({'id': id, 'dict': dict, 'empty': {'$exists': false}}).first
    # homonym +
    if data != nil and data['lemma']['homonym'] != nil and not data['lemma']['homonym'].is_a?(Array)
      if data['lemma']['homonym'].to_s == ''
        data['lemma']['homonym'] = []
      else
        data['lemma']['homonym'] = [data['lemma']['homonym'].to_s]
      end
    end
    $stdout.puts 'END getone '+Time.now.to_s
    data
  end

  def full_entry(entry, add_rev=true)
    $stdout.puts 'START fullentry '+Time.now.to_s
    entry = add_media(entry)
    entry, _ = add_colloc(entry, add_rev)
    entry = @sw.get_sw(entry)
    $stdout.puts 'END fullentry '+Time.now.to_s
    entry
  end

  def add_homonym(entry)
    if entry['lemma']['homonym'] and entry['lemma']['homonym'].is_a?(Array)
      entry['lemma']['homonym'].each{|hom|
        if hom != ''
          homent = getone(entry['dict'], hom)
          if homent != nil
            homent = full_entry(homent)
            entry['homonym'] = [] if entry['homonym'].nil?
            entry['homonym'] << add_rels(homent)
          end
        end
      }
    end
    entry
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
            ce = @sw.get_sw(ce)
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
          ce = @sw.get_sw(ce)
        end
        entry['revcollocation']['entries'] << ce
      }
    end

    [entry, collocs_used]
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
          ce = @sw.get_sw(ce)
        end
        entry['rev'+type]['entries'] << ce
      }
      entry
    else
      {'rev'+type=>{}}
    end
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
            relentry, _ = add_colloc(relentry) if add_rev
            relentry = @sw.get_sw(relentry)
            relentry = add_media(relentry, true)
            if relentry['meanings'] and relentry['meanings'].select{|m| m['id'] == rel['meaning_id']}.size > 0
              relmean = relentry['meanings'].select{|m| m['id'] == rel['meaning_id']}[0]
              if relmean['number'].to_s != ''
                rel['meaning_nr'] = relmean['number']
              end
            end
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
      if mean['text'] and mean['text'].is_a?(Hash) and mean['text']['_text']
        mean['text']['_text'].scan(/\[([0-9]+)(-[0-9]+)?\]/).each{|mrel|
          relid = mrel[0]
          mean['def_relations'] = {} if mean['def_relations'].nil?
          relentry = getone(entry['dict'], relid)
          if relentry and relentry != ""
            mean['def_relations'][relid] = relentry['lemma']['title']
          end
        }
      end
    }
    if entry['lemma']['grammar_note'] and entry['lemma']['grammar_note'][0] and entry['lemma']['grammar_note'][0]['_text']
      entry['lemma']['grammar_note'][0]['_text'].scan(/\[([0-9]+)(-[0-9]+)?\]/).each{|mrel|
        relid = mrel[0]
        entry['def_relations'] = {} if entry['def_relations'].nil?
        reldoc = getone(entry['dict'], relid)
        if reldoc and reldoc['lemma']
          entry['def_relations'][relid] = reldoc['lemma']['title']
        end
      }
    end
    if entry['lemma']['style_note'] and entry['lemma']['style_note'][0] and entry['lemma']['style_note'][0]['_text']
      entry['lemma']['style_note'][0]['_text'].scan(/\[([0-9]+)(-[0-9]+)?\]/).each{|mrel|
        relid = mrel[0]
        entry['def_relations'] = {} if entry['def_relations'].nil?
        entry['def_relations'][relid] = getone(entry['dict'], relid)['lemma']['title']
      }
    end
    entry
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
    regionkey.to_s
  end

  def get_gram(entryid)
    data = getone(@dictcode, entryid)
    if data and data['lemma'] and data['lemma']['gram'] and data['lemma']['gram']['form']
      data['lemma']['gram']
    else
      {'form'=>[]}
    end
  end

  def remove_diacritics(word)
    require "i18n"
    begin
      return I18n.transliterate(word, :locale => :en)
    rescue
      return word
    end
  end

end
