# Media lookup & attachment helpers for dictionary entries.
module CzjMediaHelpers
  def get_media(media_id, dict, add_entries=true)
    media = $mongo['media'].find({'id': media_id, 'dict': dict})
    if media.first
      media_info = media.first
      if add_entries
        entries = $mongo['entries'].find({'dict': dict, 'lemma.video_front': media_info['location']})
        if entries.first
          media_info['main_for_entry'] = @sw.get_sw(entries.first)
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
          if mean['text'] and mean['text'].is_a?(Hash) and mean['text']['file']
            if mean['text']['file'].is_a?(Hash)
              entry['media'][mean['text']['file']['@media_id'].to_s] = get_media(mean['text']['file']['@media_id'].to_s, entry['dict'])
            end
            if mean['text']['file'].is_a?(Array)
              mean['text']['file'].each{|mv|
                if mv['@media_id']
                  entry['media'][mv['@media_id'].to_s] = get_media(mv['@media_id'].to_s, entry['dict'])
                end
              }
            end
          end
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
      if entry['lemma'] and entry['lemma']['grammar_note']
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
      if entry['lemma'] and entry['lemma']['style_note']
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
    if entry['lemma']
      if entry['lemma']['video_front'].to_s != ''
        entry['media']['video_front'] = get_media_location(entry['lemma']['video_front'].to_s, entry['dict'])
      end
      if entry['lemma']['video_side'].to_s != ''
        entry['media']['video_side'] = get_media_location(entry['lemma']['video_side'].to_s, entry['dict'])
      end
    end
    return entry
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

end
