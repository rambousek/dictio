## Support methods for webpages

module CzjWebHelper
  # @param [String] page_type
  # @param [String] path
  # @param [String] page_name
  # @param [Hash] dict_info
  # @param [Hash] entry
  # @param [String] lang_from
  # @param [String] lang_to
  # @return [Hash]
  def self.get_cite_attr(page_type, path = nil, page_name = nil, dict_info = nil, entry = nil, lang_from = nil, lang_to = nil)
    data = {'page-type' => page_type}
    data['page-name'] = page_name if page_name
    if entry and dict_info
      data['lang-type'] = dict_info[entry['dict']]['type']
      data['lemma-id'] = entry['id']
      data['lemma-lang'] = entry['dict']
      if data['lang-type'] == 'write'
        data['lemma'] = entry['lemma']['title'] if entry['lemma'] and entry['lemma']['title']
      else
        data['video'] = entry['lemma']['video_front'] if entry['lemma'] and entry['lemma']['video_front']
      end
    end
    data['page-lang'] = lang_from if lang_from
    data['page-target'] = lang_to if lang_to
    data['page-url'] = 'https://www.dictio.info' + path if path
    return {'data' => data}
  end
end
