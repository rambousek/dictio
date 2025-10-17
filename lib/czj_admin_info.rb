## Admin, gather information about dictionariess
module CzjAdminInfo
  # Return number of notrans relation for each dictionary
  # @return [Hash]
  def self.get_count_relation_notrans
    info_count = {}
    $dict_info.each{|code,_|
      info_count[code] = self.get_count_relation_notrans_to(code) + self.get_count_relation_notrans_from(code)
    }
    info_count
  end

  # count notrans relations to dictionary
  # @param [String] dictcode
  # @return [Integer]
  def self.get_count_relation_notrans_to(dictcode)
    return $mongo['entries'].find({'meanings.relation': {'$elemMatch': {'notrans': true, 'target': dictcode}}}).count
  end

  # count notrans relations from dictionary
  # @param [String] dictcode
  # @return [Integer]
  def self.get_count_relation_notrans_from(dictcode)
    return $mongo['entries'].find({'dict': dictcode, 'meanings.relation.notrans': true}).count
  end


  # number of entries and published entriess for each dictionary
  # @return [Hash]
  def get_count_entry
    res = {}
    $dict_info.each{|code, _|
      res[code] = {}
      res[code]['entry_count'] = @entrydb.find({'dict': code}).count_documents
      res[code]['entry_pub_count'] = @entrydb.find({'dict': code, 'lemma.completeness': {'$ne': '1'}}).count_documents
    }
    res
  end
end
