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
    mediaid
  end
end
