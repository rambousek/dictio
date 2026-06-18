# frozen_string_literal: true

module CzjApiHelper
  def self.reformat_report_sign(data)
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
      media.each do |media_id, media_data|
        next unless media_data.is_a?(Hash)

        type = media_data['type']
        location = media_data['location']
        if %w[sign_front sign_side].include?(type)
          unless main_videos.include?(location) || variant_ids.include?(media_id.to_s)
            more_media << {
              'id' => media_id,
              'video' => location
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
end
