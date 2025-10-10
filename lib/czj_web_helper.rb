## Support methods for webpages

module CzjWebHelper
  # @param [String] page_type
  # @param [String] path
  # @param [String] page_name
  # @param [Hash] dict_info
  # @param [Hash] entry
  # @param [String] lang_from
  # @param [String] lang_to
  # @param [String] page_search
  # @return [Hash]
  def self.get_cite_attr(page_type, path = nil, page_name = nil, dict_info = nil, entry = nil, lang_from = nil, lang_to = nil, page_search = nil, page_video = nil)
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
    data['page-search'] = page_search if page_search
    data['page-video'] = page_video if page_video
    data['page-url'] = 'https://www.dictio.info' + path if path
    return {'data' => data}
  end

  # @param [Hash] cite_attr
  # @return [String]
  def self.build_cite(cite_attr)
    lemma = ''
    if cite_attr['data']['lemma-id']
      if cite_attr['data']['lemma']
        lemma = cite_attr['data']['lemma']
      else
        lemma = cite_attr['data']['lemma-lang'] + '-' + cite_attr['data']['lemma-id']
      end
    end

    case cite_attr['data']['page-type']
    when 'search', 'video'
      if cite_attr['data']['page-search']
        dict_info = I18n.t('cite.search0',
                           dictionary: I18n.t('dict_cite_1.' + cite_attr['data']['page-lang']),
                           lemma: cite_attr['data']['page-search'])
      else
        dict_info = I18n.t('cite.search',
                         dictionary: I18n.t('dict_cite_1.' + cite_attr['data']['page-lang']),
                         lemma: lemma)
      end
    when 'translate'
      if cite_attr['data']['page-search']
        dict_info = I18n.t('cite.translate0',
                           dictionary_from: I18n.t('dict_cite_2.' + cite_attr['data']['page-lang']),
                           dictionary_to: I18n.t('dict_cite_2.' + cite_attr['data']['page-target']),
                           lemma: cite_attr['data']['page-search'])
      else
        dict_info = I18n.t('cite.translate',
                           dictionary_from: I18n.t('dict_cite_2.' + cite_attr['data']['page-lang']),
                           dictionary_to: I18n.t('dict_cite_2.' + cite_attr['data']['page-target']),
                           lemma: lemma)
      end
    when 'show'
      dict_info = I18n.t('cite.show', lemma: lemma)
    else
      if cite_attr['data']['page-name'] and cite_attr['data']['page-name'] != 'index'
        dict_info = I18n.t('menu.' + cite_attr['data']['page-name']) + '.'
      end
    end

    if cite_attr['data']['page-type'] == 'video'
      online = ''
      video = I18n.t('cite.video', video: cite_attr['data']['page-video'])
    else
      online = I18n.t('cite.online')
      video = ''
    end

    I18n.t('cite.text', video: video, online: online, dict_info: dict_info,
           date: DateTime.now.strftime('%-d. %-m. %Y'), url: cite_attr['data']['page-url'])
  end
end
