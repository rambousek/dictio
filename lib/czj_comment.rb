## Handle all comments for entries

class CzjComment < Object
  attr_accessor :sign_dicts
  def initialize
    super
    @commentdb = $mongo['koment']
  end

  # Save comment to database for selected box in entry editor
  # @param [CZJDict] dict Dictionary object
  # @param [String] user User login
  # @param [String] entry Entry ID
  # @param [String] box Box ID in editor
  # @param [String] text Comment text
  # @param [String] assign_user Login for assigned user
  def comment_add(dict, user, entry, box, text, assign_user)
    if @sign_dicts.include?(dict.dictcode) and box.start_with?('vyznam') and not box.include?('vazby')
      entrydata = dict.getone(dict.dictcode, entry)
      if entrydata and entrydata['meanings']
        # for sign editor, if box is meaning definition, change box name to video ID
        entrydata['meanings'].select{|m| m['id'] == box[6..-1]}.each{|m|
          if m['text'] and m['text'].is_a?(Hash) and m['text']['file'] and m['text']['file']['@media_id']
            video = dict.get_media(m['text']['file']['@media_id'], dict.dictcode, false)
            if video
              box = 'video' + video['location']
            end
          end
        }
      end
    end
    comment_data = {
      'dict' => @dictcode,
      'entry' => entry,
      'box' => box,
      'text' => text,
      'user' => user,
      'time' => Time.new.strftime('%Y-%m-%d %H:%M'),
      'assign' => assign_user
    }
    $stdout.puts comment_data
    @commentdb.insert_one(comment_data)
  end

  # Delete comment from database
  # @param [String] cid Comment database ID
  def comment_del(cid)
    @commentdb.find({'_id' => BSON::ObjectId.from_string(cid)}).delete_many
  end

  # Update comment in database
  # @param [String] cid Comment database ID
  # @param [String] assign Asssigned username
  # @param [String] solved Is solved
  def comment_save(cid, assign, solved)
    comments = @commentdb.find({'_id' => BSON::ObjectId.from_string(cid)})
    if comments.count == 1
      comment_data = comments.first
      comment_data['assign'] = assign
      comment_data['solved'] = solved
      comments.delete_many
      @commentdb.insert_one(comment_data)
    end
  end

  # Find comments for selected entry
  # @param [String] dictcode Dictionary code
  # @param [String] id Entry ID
  # @param [String] type Select comment box
  # @param [Boolean] exact Exact match for comment box
  # @return [Hash{Symbol->Array}] Array of comments
  def get_comments(dictcode, id, type, exact=true)
    coms = []
    dict = $dict_array[dictcode]
    query = {'dict': dictcode, 'entry': id}
    if type != ''
      if exact
        query['$or'] = [{'box': type}]
      else
        query['$or'] = [{'box': {'$regex': '.*'+type+'.*'}}]
      end
    end

    if @sign_dicts.include?(dictcode) and type.start_with?('vyznam') and not type.include?('vazby')
      entrydata = dict.getone(dictcode, id)
      if entrydata and entrydata['meanings']
        # for sign entries, change box name to video ID
        entrydata['meanings'].select{|m| m['id'] == type[6..-1]}.each{|m|
          if m['text'] and m['text'].is_a?(Hash) and m['text']['file']
            if m['text']['file'].is_a?(Hash)
              if m['text']['file']['@media_id']
                video = dict.get_media(m['text']['file']['@media_id'], dict.dictcode, false)
                if video
                  query['$or'].push({'box': 'video' + video['location']})
                end
              end
            else
              m['text']['file'].each{|mf|
                if mf['@media_id']
                  video = dict.get_media(mf['@media_id'], dict.dictcode, false)
                  if video
                    query['$or'].push({'box': 'video' + video['location']})
                  end
                end
              }
            end
          end
        }
      end
    end

    # find comments, sorted by time descending
    @commentdb.find(query, :sort => {'time' => -1}).each{|com|
      coms << com
    }
    {'comments': coms}
  end
end
