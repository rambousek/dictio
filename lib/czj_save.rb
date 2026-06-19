# Persisting edited entries (the big save_doc workflow).
module CzjSave
  def save_doc(data, user='')
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
      if data['meanings']
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
    end

    # for new entries, add relations
    if olddata.nil?
      if data['meanings']
        data['meanings'].each{|m|
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
    end
    

    #add fsw
    if data['lemma']['sw']
      $stdout.puts "update sw"
      data['lemma']['sw'].each{|sw|
        sw['@fsw'] = CzjFsw.getfsw(sw['_text']) if sw['@fsw'] == '' or sw['@fsw'].start_with?('M500')
      }
    end

    #add homonym
    if data['lemma']['homonym'] and data['lemma']['homonym'].is_a?(Array)
      data['lemma']['homonym'].each{|hom|
        if hom.to_s != ''
          add_homonym_target(hom, entryid)
        end
      }
    end

    #add variants 
    fmedia = get_media_location(data['lemma']['video_front'].to_s, @dictcode)
    if fmedia['id'].to_s != ''
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

    #title without diacritics
    if @write_dicts.include?(dict) and data["lemma"]["title"]
      data["lemma"]["title_dia"] = remove_diacritics(data["lemma"]["title"])
    end

    #save media info
    if data['update_video']
      $stdout.puts "update video"
      data['update_video'].each{|uv|
        @edit_media.save_media(uv)
      }
      data.delete('update_video')
    end

    # save history
    save_history_info(dict, entryid, data, olddata, user)
    data.delete('track_changes')
    $stdout.puts data

    @entrydb.find({'dict':dict, 'id': entryid}).delete_many
    @entrydb.insert_one(data)

    # update SW cache
    if @sign_dicts.include?(dict)
      $stdout.puts "update sw cache"
      $mongo['sw'].find({'dict': dict, 'entries_used': entryid}).delete_many
      @sw.cache_all_sw(false)
    end

    #update relations cache
    Thread.new{ cache_relations(data, true) }

    return true
  end

end
