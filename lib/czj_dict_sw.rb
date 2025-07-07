class CzjDictSw < Object
  # @param [CZJDict] dict
  def initialize(dict)
    @dict = dict
    @dictcode = dict.dictcode
    @entrydb = $mongo['entries']
  end

  # @return [Integer]
  def normalize_fsw
    count = 0
    @entrydb.find({
                    'dict': @dictcode,
                    'lemma.sw': {'$elemMatch':{
                      '_text': {'$exists':true, '$ne':''},
                      '$or': [{'@fsw':''}, {'@fsw':{'$regex':/^M500/}}]
                    }}
                  }).each{|entry|
      entry['lemma']['sw'].each{|sw|
        if sw['_text'].to_s != '' and (sw['@fsw'].to_s == '' or sw['@fsw'].start_with?('M500'))
          fsw = CzjFsw.getfsw(sw['_text'])
          sw['@fsw'] = fsw
          count += 1
        end
      }
      # update entry
      @entrydb.find({'dict': @dictcode, 'id': entry['id']}).delete_many
      @entrydb.insert_one(entry)
      # clear SW cache
      $mongo['sw'].find({'dict': @dictcode, 'entries_used': entry['id']}).delete_many
    }

    # update SW cache
    cache_all_sw(false)
    count
  end

  # @param [Boolean] delete_existing
  # @return [Hash{String->Integer}]
  def cache_all_sw(delete_existing=true)
    puts @dictcode
    count = {'single' => 0, 'compos' => 0, 'deleted' => 0}
    swids = []
    if delete_existing
      res = $mongo['sw'].find({'dict': @dictcode}).delete_many
      count['deleted'] = res.deleted_count
    end
    $mongo['sw'].find({'dict': @dictcode}).each{|sw|
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

    count
  end

  # @param [Hash] entry
  # @return [Hash]
  def cache_sw(entry)
    if @dict.write_dicts.include?(entry['dict'])
      return entry
    end
    $stdout.puts 'CACHE SW, entry ' + @dictcode + ' ' + entry['id'].to_s
    entries_used = [entry['id']]
    entry['lemma']['swmix'] = []
    if %w[collocation derivat kompozitum fingerspell].include?(entry['lemma']['lemma_type'])
      if entry['collocations']
        # pridat colloc
        entry, collocs_used = @dict.add_colloc(entry, false)
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
    entry
  end

  # @param [Hash] entry
  # @return [Hash]
  def get_sw(entry)
    if @dict.write_dicts.include?(entry['dict'])
      return entry
    end
    $stdout.puts 'GETSW, entry ' + entry['id'].to_s
    swdoc = $mongo['sw'].find({'id': entry['id'], 'dict': entry['dict']})
    if swdoc.first and swdoc.first['swmix'] and swdoc.first['swmix'].length > 0
      entry['lemma']['swmix'] = swdoc.first['swmix']
    end
    entry
  end
end
