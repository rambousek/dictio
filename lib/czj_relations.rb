# Managing relations between entries/meanings: add/remove, lookup, caching of denormalized relation data.
module CzjRelations
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
      doc['lemma']['homonym'] = [] if doc['lemma']['homonym'].nil?
      if not doc['lemma']['homonym'].include?(homonym)
        doc['lemma']['homonym'] << homonym
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
          $stdout.puts 'add variant to entry '+ doc['id'].to_s+ ':' + origin_media.to_s + ' ' + type.to_s
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
          'type'=>{'$in' => %w[sign_front sign_side sign_definition] }
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
            {'meanings.id'=>search},
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
            if mean['text'] and mean['text'].is_a?(Hash) and mean['text']['file'] and mean['text']['file']['@media_id']
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
          'type'=>{'$in' => %w[sign_front sign_side sign_definition] }
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

  def get_relations(meaning_id, type, user_info=nil)
    list = []
    entry = getdoc(meaning_id.split('-')[0].to_s)
    if entry['meanings']
      entry['meanings'].each{|mean|
        if mean['id'] == meaning_id
          mean['relation'].each{|rel|
            next if type != '' and rel['type'] != type
            next if user_info != nil and user_info['edit_synonym'] != nil and not user_info['edit_synonym'] and rel['type'] != 'translation'
            next if user_info != nil and user_info['edit_trans'] != nil and not user_info['edit_trans'] and rel['type'] == 'translation'
            next if user_info != nil and user_info['edit_dict'] != nil and not user_info['edit_dict'].include?(rel['target'])
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

  # remove all relations to entry
  def remove_all_relations(entry_id)
    query = {'$or'=>[
      {'meanings.relation'=>{'$elemMatch'=>{'target'=>@dictcode,'meaning_id'=>{'$regex'=>/^#{entry_id}-/}}}},
      {'meanings.usages.relation'=>{'$elemMatch'=>{'target'=>@dictcode,'meaning_id'=>{'$regex'=>/^#{entry_id}-/}}}}
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
    entry = @sw.get_sw(entry)
    if entry['meanings']
      entry['meanings'].each{|mean|
        if mean['relation']
          mean['relation'].each{|rel|
            rel['source_dict'] = entry['dict']
            rel['source_id'] = entry['id']
            rel['source_meaning_id'] = mean['id']
            rel['source_pos'] = ''
            rel['source_region'] = ''
            rel['source_priznak'] = ''
            if entry['lemma']['grammar_note'] and entry['lemma']['grammar_note'][0]
              if entry['lemma']['grammar_note'][0]['@slovni_druh']
                rel['source_pos'] = entry['lemma']['grammar_note'][0]['@slovni_druh'].to_s
              end
              if entry['lemma']['grammar_note'][0]['@region']
                rel['source_region'] = entry['lemma']['grammar_note'][0]['@region'].to_s
              end
            end
            if entry['lemma']['style_note'] and entry['lemma']['style_note'][0] and entry['lemma']['style_note'][0]['@stylpriznak']
              rel['source_priznak'] = entry['lemma']['style_note'][0]['@stylpriznak'].to_s
            end
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
                targetentry = @sw.get_sw(targetentry)
                rel['target_pos'] = ''
                rel['target_priznak'] = ''
                rel['target_region'] = ''
                if targetentry['lemma']['grammar_note'] and targetentry['lemma']['grammar_note'][0]
                  if targetentry['lemma']['grammar_note'][0]['@slovni_druh']
                    rel['target_pos'] = targetentry['lemma']['grammar_note'][0]['@slovni_druh'].to_s
                  end
                  if targetentry['lemma']['grammar_note'][0]['@region']
                    rel['target_region'] = targetentry['lemma']['grammar_note'][0]['@region'].to_s
                  end
                end
                if targetentry['lemma']['style_note'] and targetentry['lemma']['style_note'][0] and targetentry['lemma']['style_note'][0]['@stylpriznak']
                  rel['target_priznak'] = targetentry['lemma']['style_note'][0]['@stylpriznak'].to_s
                end

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
                    targetentry = @sw.get_sw(targetentry)
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

end
