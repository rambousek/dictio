## Admin, work with duplicate entries

module CzjAdminDuplicate
  # count number of duplicate entries for each dictionary
  # @return [Hash]
  def self.get_duplicate_counts
    res = {'duplicate' => []}
    $dict_info.each{|code, _|
      pipeline = get_duplicate_pipeline(code)
      $mongo['entries'].aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
        count = re['total'].to_i
        res['duplicate'] << {'code'=>code, 'count'=>count}
      }
    }
    res
  end

  # build db pipeline to find duplicate entries in dictionary
  # @param [String] dict
  # @param [Boolean] remove_syno remove synonyms from duplicates
  # @param [Boolean] second first or second run
  def self.get_duplicate_pipeline(dict, remove_syno=true, second=false)
    if $dict_info[dict]['type'] == 'write'
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
      if $dict_info[dict]['type'] == 'write'
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
    if $dict_info[dict]['type'] == 'sign' and not second
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
    pipeline
  end

  # find duplicate entries
  # @param [CzjDict] dict
  # @param [Integer] start
  # @param [Integer] limit
  # @return [Hash]
  def self.get_duplicate(dict, start=0, limit=nil)
    pipeline = CzjAdminDuplicate.get_duplicate_pipeline(dict.dictcode)
    if $dict_info[dict.dictcode]['type'] == 'write'
      locale = dict.dictcode
      locale = 'sk' if dict.dictcode == 'sj'
    else
      locale = 'cs'
    end
    pipeline << {'$skip' => start.to_i}
    pipeline << {'$limit' => limit.to_i} if limit.to_i > 0

    res = {'count'=> 0, 'duplicate'=> []}
    $mongo['entries'].aggregate(pipeline+[{'$count'=>'total'}]).each{|re|
      res['count'] = re['total'].to_i
    }
    cursor = $mongo['entries'].aggregate(pipeline, {:allow_disk_use => true, :collation => {'locale' => locale}})
    cursor.each{|re|
      if re['_id']['ids'] and not re['front']
        doc = dict.getone(dict.dictcode, re['_id']['ids'][0])
        re['front'] = doc['lemma']['video_front'].to_s if doc['lemma']
      end
      res['duplicate'] << re
    }
    res
  end

  # find duplicate entries, skip synonyms
  # @param [CzjDict] dict
  # @param [Integer] start
  # @param [Integer] limit
  # @return [Hash]
  def self.get_duplicate_syno(dict, start=0, limit=nil)
    pipeline = CzjAdminDuplicate.get_duplicate_pipeline(dict.dictcode, false)
    if $dict_info[dict.dictcode]['type'] == 'write'
      locale = dict.dictcode
      locale = 'sk' if dict.dictcode == 'sj'
    else
      locale = 'cs'
    end
    pipeline << {'$skip' => start.to_i}
    pipeline << {'$limit' => limit.to_i} if limit.to_i > 0

    res = {'count'=> 0, 'duplicate'=> []}
    cursor = $mongo['entries'].aggregate(pipeline, {:allow_disk_use => true, :collation => {'locale' => locale}})
    cursor.each{|re|
      if re['_id']['ids'] and not re['front']
        doc = dict.getone(dict.dictcode, re['_id']['ids'][0])
        re['front'] = doc['lemma']['video_front'].to_s if doc['lemma']
      end
      add_re = true
      if re['_id']['ids']
        syno_num = 0
        re['_id']['ids'].each{|id|
          doc = dict.getone(dict.dictcode, id)
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
    res
  end
end
