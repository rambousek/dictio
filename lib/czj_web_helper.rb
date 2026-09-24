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
        lemma = cite_attr['data']['lemma-lang'] + '-' + cite_attr['data']['lemma-id'].to_s
      end
    end
    part = cite_attr['data']['part'].to_s

    case cite_attr['data']['page-type']
    when 'search', 'video'
      if cite_attr['data']['page-search']
        dict_info = I18n.t('cite.search0',
                           dictionary: I18n.t('dict_cite_1.' + cite_attr['data']['page-lang']),
                           lemma: cite_attr['data']['page-search'])
      else
        dict_info = I18n.t('cite.search',
                         dictionary: I18n.t('dict_cite_1.' + cite_attr['data']['page-lang']),
                         lemma: lemma, part: part)
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
    dict_info = dict_info.to_s == '' ? '' : dict_info + ' '

    video = ''
    online = ''
    if cite_attr['data']['page-type'] == 'video'
      kind = cite_attr['data']['video-kind'] || video_kind_from_filename(cite_attr['data']['page-video'])
      video = I18n.t(kind == 'lemma' ? 'cite.video_lemma' : 'cite.video_collective',
                     video: cite_attr['data']['page-video'],
                     dictionary: I18n.t('dict_cite_1.' + cite_attr['data']['page-lang']))
    elsif part == ''
      online = I18n.t('cite.online')
    end

    I18n.t('cite.text', video: video, online: online, dict_info: dict_info, version: $app_version,
           date: DateTime.now.strftime('%-d. %-m. %Y'), url: cite_attr['data']['page-url'])
  end

  # Citation of a single video file, independent of the page it is shown on.
  # @param [Hash] dict_info
  # @param [Hash] entry
  # @param [Hash] media
  # @param [String] kind one of lemma, definition, example
  # @param [String] meaning_number
  # @return [String]
  def self.build_video_cite(dict_info, entry, media, kind, meaning_number = nil)
    return '' unless media.is_a?(Hash) and media['location'].to_s != ''
    path = '/' + entry['dict'] + '/show/' + entry['id'].to_s + '/' + media['location']
    cite_attr = get_cite_attr('video', path, nil, dict_info, entry, entry['dict'], nil, nil, media['location'])
    cite_attr['data']['video-kind'] = kind
    cite_attr['data']['part'] = cite_part(meaning_number, kind == 'example') if kind != 'lemma'
    build_cite(cite_attr)
  end

  # Citation of a meaning block or its examples within an entry.
  # @param [Hash] dict_info
  # @param [Hash] entry
  # @param [String] meaning_number
  # @param [Boolean] examples
  # @return [String]
  def self.build_part_cite(dict_info, entry, meaning_number, examples = false)
    dict = entry['dict']
    if dict_info[dict]['type'] == 'write'
      path = '/' + dict + '/search/text/' + entry['lemma']['title'].to_s + '/' + entry['id'].to_s
    else
      path = '/' + dict + '/show/' + entry['id'].to_s
    end
    cite_attr = get_cite_attr('search', path, nil, dict_info, entry, dict)
    cite_attr['data']['part'] = cite_part(meaning_number, examples)
    build_cite(cite_attr)
  end

  # @param [String] meaning_number
  # @param [Boolean] examples
  # @return [String]
  def self.cite_part(meaning_number, examples)
    return '' if meaning_number.to_s == ''
    I18n.t(examples ? 'cite.part_examples' : 'cite.part_meaning', number: meaning_number)
  end

  # @param [String] filename
  # @return [String]
  def self.video_kind_from_filename(filename)
    case filename.to_s[0]
    when 'D' then 'definition'
    when 'K' then 'example'
    else 'lemma'
    end
  end
end
