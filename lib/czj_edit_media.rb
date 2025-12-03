# Method to handle media in editor for one dictionary
class CzjEditMedia < Object
  # @param [CZJDict] dict
  def initialize(dict)
    @dict = dict
    @dictcode = dict.dictcode
    @entrydb = $mongo['entries']
  end

  # remove video from entry
  # @param [String] entry_id
  # @param [String] media_id
  def remove_video(entry_id, media_id)
    media = @dict.get_media(media_id, @dictcode, false)
    if media != {}
      if media.has_key?('entry_folder') and media['entry_folder'].is_a?(Array)
        media['entry_folder'].delete(entry_id)
      end
      media.delete('media_folder_id')
      $mongo['media'].find({'dict'=> @dictcode, 'id'=> media['id'].to_s}).delete_many
      $mongo['media'].insert_one(media)
    end
  end

  # attach media info to entry
  # @param [String] location
  # @param [String] entry_id
  # @param [Hash] metadata
  # @return [String]
  def attach_file(location, entry_id, metadata)
    media = @dict.get_media_location(location, @dictcode)
    if media == {}
      cursor = $mongo['media'].find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
      cursor = cursor.limit(1)
      mediaid = 1
      cursor.each{|r|
        mediaid = r['id'].to_i + 1
      }
      media = {
        'id' => mediaid.to_s,
        'dict' => @dictcode,
        'location' => location,
        'original_file_name' => location,
        'label' => norm_name(location)[0],
        'id_meta_copyright' => metadata['id_meta_copyright'],
        'id_meta_author' => metadata['id_meta_author'],
        'id_meta_source' => metadata['id_meta_source'],
        'admin_comment' => metadata['admin_comment'],
        'type' => metadata['type'],
        'status' => metadata['status'],
        'orient' => metadata['orient'],
        'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S")
      }
    else
      mediaid = media['id'].to_s
      $mongo['media'].find({'dict'=> @dictcode, 'id'=> mediaid}).delete_many
    end
    media['entry_folder'] = [] unless media.has_key?('entry_folder')
    media['entry_folder'] << entry_id.to_s if entry_id.to_s != ''
    media['entry_folder'].uniq!
    $mongo['media'].insert_one(media)
    mediaid.to_s
  end

  # find media related to entry
  # @param [String] entry_id
  # @param [String] type
  # @return [Array]
  def get_entry_files(entry_id, type='')
    list = []
    entry = @dict.getone(@dictcode, entry_id)

    query = {'dict'=> @dictcode}
    query[:$or] = [{'entry_folder' => entry_id.to_s}]

    if entry != nil
      query[:$or] << {'media_folder_id' => entry['lemma']['media_folder_id']} if entry['lemma']['media_folder_id'].to_s != ''
      files = []
      if entry['meanings']
        entry['meanings'].each{|me|
          if me['usages']
            me['usages'].each{|us|
              files << us['text']['file']['@media_id'] if us['text'] and us['text']['file'] and us['text']['file'].is_a?(Hash) and us['text']['file']['@media_id']
            }
          end
          if me['text'] and me['text'].is_a?(Hash) and me['text']['file']
            if me['text']['file'].is_a?(Hash) and me['text']['file']['@media_id']
              files << me['text']['file']['@media_id']
            end
            if me['text']['file'].is_a?(Array)
              me['text']['file'].each{|mv|
                files << mv['@media_id'] if mv['@media_id']
              }
            end
          end
        }
      end
      if entry['lemma']['grammar_note'] and entry['lemma']['grammar_note'][0] and entry['lemma']['grammar_note'][0]['variant']
        entry['lemma']['grammar_note'][0]['variant'].each{|va|
          files << va['_text']
        }
      end
      if entry['lemma']['style_note'] and entry['lemma']['style_note'][0] and entry['lemma']['style_note'][0]['variant']
        entry['lemma']['style_note'][0]['variant'].each{|va|
          files << va['_text']
        }
      end
      files.uniq.each{|fi|
        query[:$or] << {'id' => fi}
      }
      if entry['lemma']['video_front'] and entry['lemma']['video_front'].to_s != ''
        query[:$or] << {'location' => entry['lemma']['video_front'].to_s}
      end
      if entry['lemma']['video_side'] and entry['lemma']['video_side'].to_s != ''
        query[:$or] << {'location' => entry['lemma']['video_side'].to_s}
      end
    end

    if type != ''
      case type
      when 'AB'
        query['type'] = {'$in' => %w[sign_front sign_side] }
      when 'A'
        query['type'] = 'sign_front'
      when 'K'
        query['type'] = 'sign_usage_example'
      when 'D'
        query['type'] = 'sign_definition'
      when 'G'
        query['type'] = 'sign_grammar'
      when 'S'
        query['type'] = 'sign_style'
      end
    end

    $mongo['media'].find(query).each{|re| list << re }

    list
  end

  # find file by name
  # @param [String] search
  # @param [String] type
  # @return [Array]
  def find_files(search, type)
    list = []
    if search.length > 1
      query = {'dict' => @dictcode, :$or => [{'location' => /#{search}/}, {'original_file_name' => /#{search}/}]}
      case type
      when 'AB'
        query['type'] = {'$in' => %w[sign_front sign_side] }
      when 'A'
        query['type'] = 'sign_front'
      when 'K'
        query['type'] = 'sign_usage_example'
      when 'D'
        query['type'] = 'sign_definition'
      when 'G'
        query['type'] = 'sign_grammar'
      when 'S'
        query['type'] = 'sign_style'
      end

      $mongo['media'].find(query).each{|re| list << re}
    end
    list
  end

  # save video file
  # @param [Hash] data
  # @return [String]
  def save_media(data)
    if data['id'].to_s == ''
      cursor = $mongo['media'].find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
      cursor = cursor.limit(1)
      mediaid = 1
      cursor.each{|r|
        mediaid = r['id'].to_i + 1
      }
      media = {'id' => mediaid.to_s}
    else
      media = @dict.get_media(data['id'].to_s, @dictcode)
    end

    media['dict'] = @dictcode
    media['location'] = data['location'].to_s
    media['original_file_name'] = data['original_file_name'].to_s
    media['label'] = data['label'].to_s
    media['id_meta_copyright'] = data['id_meta_copyright'].to_s
    media['id_meta_author'] = data['id_meta_author'].to_s
    media['id_meta_source'] = data['id_meta_source'].to_s
    media['admin_comment'] = data['admin_comment'].to_s
    media['type'] = data['type'].to_s
    media['status'] = data['status'].to_s
    media['orient'] = data['orient'].to_s
    media['created_at'] = data['created_at'].to_s
    media['updated_at'] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    media.delete('main_for_entry')
    $mongo['media'].find({'dict'=> @dictcode, 'id'=> data['id'].to_s}).delete_many
    $mongo['media'].insert_one(media)
    media['id'].to_s
  end

  # upload file, store metadata
  # @param [Hash] filedata
  # @param [Hash] metadata
  # @param [String] entry_id
  # @return [Array[String]]
  def save_uploaded_file(filedata, metadata, entry_id)
    filename = filedata['filename'].force_encoding("UTF-8").gsub(/[^\w^\p{Cyrillic}^\.^_^-]/, '')
    filename = filename[0,2]+filename[2..-1].gsub('_','-')
    $stdout.puts 'SAVE UPLOAD'
    $stdout.puts filedata['filename']
    $stdout.puts filename
    media = @dict.get_media_location(filename, @dictcode)
    if media == {}
      cursor = $mongo['media'].find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
      cursor = cursor.limit(1)
      mediaid = 1
      cursor.each{|r|
        mediaid = r['id'].to_i + 1
      }
    else
      mediaid = media['id']
      $mongo['media'].find({'dict'=> @dictcode, 'id'=> mediaid}).delete_many
    end
    data = {
      'id' => mediaid.to_s,
      'dict' => @dictcode,
      'location' => filename,
      'original_file_name' => filename,
      'label' => norm_name(filename)[0],
      'id_meta_copyright' => metadata['id_meta_copyright'],
      'id_meta_author' => metadata['id_meta_author'],
      'id_meta_source' => metadata['id_meta_source'],
      'admin_comment' => metadata['admin_comment'],
      'type' => metadata['type'],
      'status' => metadata['status'],
      'orient' => metadata['orient'],
      'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      'entry_folder' => []
    }
    data['entry_folder'] << entry_id.to_s if entry_id.to_s != ''
    $stdout.puts data
    $mongo['media'].insert_one(data)

    Net::SSH.start("files.dictio.info", $files_user, :key_data=>$files_keys){|ssh|
      ssh.scp.upload!(filedata['tempfile'].path, '/home/adam/upload/'+@dictcode+'/'+filename)
      command = '/home/adam/mkthumb.sh "'+filename+'" "'+@dictcode+'"'
      $stdout.puts command
      ssh.exec(command)
    }

    [filename, mediaid.to_s]
  end
end
