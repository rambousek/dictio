# Building the per-dictionary wordlist used for search suggestions.
module CzjWordlist
  # Prepare array with list of words and assign to wordlist attr
  # for each dictionary combination for translation, for search all words in current dictionary
  def build_wordlist
    wordlist = {}
    if $dict_info[@dictcode]['type'] == 'write'
      $dict_info.each do |target_code, _|
        list = []
        if @dictcode == target_code
          $mongo['entries'].find({'dict' => @dictcode, 'lemma.title': {'$exists': true}}).each do |entry|
            if entry['lemma']['title'] != ''
              list << entry['lemma']['title']
            end
            if entry['lemma']['gram'] and entry['lemma']['gram']['form']
              entry['lemma']['gram']['form'].each{|decl|
                if decl.is_a?(BSON::Document) and decl['_text'] and decl['_text'] != ''
                  list << decl['_text']
                end
              }
            end
          end
        else
          # take list of titles for dictionary
          cond1 = {'source_dict' => @dictcode, 'type' => 'translation', 'target' => target_code}
          # take list of text translation with dictionary as target
          cond2 = {'target' => @dictcode, 'source_dict' => target_code, 'meaning_nr' => {'$exists' => false}}
          # for public, check status
          if not $is_edit and not $is_admin
            cond1['status'] = 'published'
            cond2['status'] = 'published'
          end
          $mongo['relation'].find(cond1).each do |entry|
            if entry['source_title'] and entry['source_title'] != ''
              list << entry['source_title']
              if entry['entry_text']
                entry['entry_text'].each{|decl|
                  if decl != ''
                    list << decl
                  end
                }
              end
            end
          end
          $mongo['relation'].find(cond2).each do |entry|
            if entry['meaning_id'] and entry['meaning_id'] != ''
              list << entry['meaning_id']
            end
          end
        end
        $stdout.puts @dictcode + '-' + target_code
        wordlist[target_code] = list.uniq
      end
    end
    @wordlist = wordlist
  end

end
