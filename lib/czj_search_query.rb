## Helper methods to build search query
module CzjSearchQuery
  # @param [String] oblast
  # @return [Array]
  def self.get_search_cond_oblast(field, oblast)
    list_oblast = %w[cr]
    case oblast
    when 'morava'
      list_oblast += %w[morava brno vm ot ol zl kr]
    when 'cechy'
      list_oblast += %w[cechy praha plzen cb jih hk lib]
    else
      list_oblast += [oblast]
    end
    [{ field => { '$in' => list_oblast}}, { field => ''}, { field => { '$exists' => false}}]
  end
end
