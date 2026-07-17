# frozen_string_literal: true

module CzjApiHelper
  # Map a media document's stored orientation (pr/lr) to the export value P/L.
  def self.video_orient(media)
    %w[lr l].include?((media || {})['orient'].to_s.downcase) ? 'L' : 'P'
  end

  def self.reformat_report_sign(dict, data)
    result = data.map do |entry|
      lemma = entry['lemma'] || {}
      grammar_note = (lemma['grammar_note'] || []).first || {}
      sw_source = lemma['swmix'] || lemma['sw'] || []
      fsw = sw_source.map do |sw|
        {
          'fsw'     => sw['@fsw'],
          'primary' => sw_source.length == 1 ? true : sw['@primary']
        }
      end

      media = entry['media'] || {}
      variant_ids = [
        lemma.dig('grammar_note', 0, 'variant'),
        lemma.dig('style_note', 0, 'variant')
      ].compact.flatten.map { |var| var['_text'] }.reject { |id| id.nil? || id.empty? }

      vars = variant_ids.map do |media_id|
        {
          'id'    => media_id,
          'video' => media.dig(media_id, 'location')
        }
      end

      main_videos = [lemma['video_front'], lemma['video_side']].compact
      more_media = []
      files = dict.edit_media.get_entry_files(entry['id'])
      files.each do |media_data|
        next unless media_data.is_a?(Hash)

        if %w[sign_front sign_side].include?(media_data['type'])
          unless main_videos.include?(media_data['location']) || variant_ids.include?(media_data['id'].to_s)
            more_media << {
              'id' => media_data['id'],
              'video' => media_data['location']
            }
          end
        end
      end

      meanings = (entry['meanings'] || []).map do |meaning|
        relations = meaning['relation'] || []

        translations = relations
                         .select { |rel| rel['type'] == 'translation' }
                         .map do |rel|
          rel_entry = rel['entry'] || {}
          rel_lemma = rel_entry['lemma'] || {}
          {
            'meaning_id' => rel['meaning_id'],
            'target' => rel['target'],
            'status' => rel['status'],
            'title' => rel_lemma['title'],
            'video' => rel_lemma['video_front'],
          }
        end

        synonyms = relations
                     .select { |rel| rel['type'] == 'synonym' }
                     .map do |rel|
          rel_entry = rel['entry'] || {}
          rel_lemma = rel_entry['lemma'] || {}
          {
            'meaning_id' => rel['meaning_id'],
            'target' => rel['target'],
            'status' => rel['status'],
            'title' => rel_lemma['title'],
            'video' => rel_lemma['video_front'],
          }
        end

        antonyms = relations
                     .select { |rel| rel['type'] == 'antonym' }
                     .map do |rel|
          rel_entry = rel['entry'] || {}
          rel_lemma = rel_entry['lemma'] || {}
          {
            'meaning_id' => rel['meaning_id'],
            'target' => rel['target'],
            'status' => rel['status'],
            'title' => rel_lemma['title'],
            'video' => rel_lemma['video_front'],
          }
        end

        {
          'meaning_id' => meaning['id'],
          'translations' => translations,
          'synonyms' => synonyms,
          'antonyms' => antonyms
        }
      end

      {
        'ID' => entry['id'],
        'video_front' => lemma['video_front'],
        'video_side' => lemma['video_side'],
        'pos' => grammar_note['@slovni_druh'] || '',
        'pos2' => grammar_note['@skupina'] || '',
        'pos3' => grammar_note['@skupina2'] || '',
        'mluv_komp' => grammar_note['@mluv_komp'],
        'oral_komp' => grammar_note['@oral_komp'],
        'fsw' => fsw,
        'variants' => vars,
        'more_video' => more_media,
        'meanings' => meanings
      }
    end
    result
  end
  def self.reformat_report_write(_dict, data)
    result = data.map do |entry|
      lemma = entry['lemma'] || {}
      grammar_note = (lemma['grammar_note'] || []).first || {}

      meanings = (entry['meanings'] || []).map do |meaning|
        relations = meaning['relation'] || []

        translations = relations
                         .select { |rel| rel['type'] == 'translation' }
                         .map do |rel|
          rel_entry = rel['entry'] || {}
          rel_lemma = rel_entry['lemma'] || {}
          {
            'target' => rel['target'],
            'meaning_id' => rel['meaning_id'],
            'title' => rel_lemma['title'],
            'video' => rel_lemma['video_front']
          }
        end

        examples = (meaning['example'] || []).map do |ex|
          {
            'usage_id' => ex['id'],
            'text' => ex.dig('text', '_text').to_s.gsub("\n", ' '),
            'source' => ex.dig('text', 'source')
          }
        end

        {
          'meaning_id' => meaning['id'],
          'definition' => meaning.dig('text', '_text').to_s.gsub("\n", ' '),
          'definition_source' => meaning.dig('text', 'source'),
          'usages' => examples,
          'translations' => translations
        }
      end

      {
        'ID'       => entry['id'],
        'lemma'    => lemma['title'],
        'pos'      => grammar_note['@slovni_druh'].to_s,
        'meanings' => meanings
      }
    end
    result
  end
end
