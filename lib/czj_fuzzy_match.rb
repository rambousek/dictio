require 'damerau-levenshtein'

# fuzzy matching for translatelist when exact search finds nothing
module CzjFuzzyMatch
  module_function

  def find_closest_match(search, possible_matches, max_distance)
    filtered_matches = possible_matches.select do |term|
      DamerauLevenshtein.distance(search, term) <= max_distance
    end
    filtered_matches.min_by { |term| DamerauLevenshtein.distance(search, term) }
  end

  def multisyllabic_match(words_array, possible_matches)
    words_array.shift if words_array.first.length <= 2
    while words_array.size > 0
      closest_match = find_closest_match(words_array.first, possible_matches, 2)
      if closest_match
        return {'match'=>closest_match, 'resultinfo3'=>true}
      else
        words_array.shift
      end
    end
    return {'match'=>nil, 'resultinfo3'=>false}
  end

  # NOTE: mutates search in place (ne-strip and short-word truncation), same
  # as the historical route-local implementation did to @search
  def single_word_match(search, possible_matches, code)
    search.slice!(0, 2) if search.start_with?("ne") && (code == "cs" || code == "sk") &&  search.length > 4
    resultinfo1 = true
    resultinfo2 = false
    while search.length > 1
      closest_match = find_closest_match(search, possible_matches, 2)
      if closest_match
        resultinfo2 = true if not resultinfo1
        return {'match'=>closest_match, 'resultinfo1'=>resultinfo1, 'resultinfo2'=>resultinfo2}
      else
        if search.length >= 10
          search = search[0, [search.length / 2, 1].max]
        else
          search.slice!(-2, 2)
        end
        resultinfo1 = false if resultinfo1
      end
    end
    return {'match'=>nil, 'resultinfo1'=>resultinfo1, 'resultinfo2'=>resultinfo2}
  end
end
