# Entry change history: saving, listing, navigating revisions.
module CzjHistory
  extend self

  def save_history_info(dict, entryid, data_new, data_old, user)
    changes = data_new['track_changes']
    data_new.delete('track_changes')
    history = {
      'dict' => dict,
      'entry' => entryid,
      'user' => user,
      'timestamp' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      'detail' => changes,
      'full_entry_old' => data_old,
      'full_entry' => data_new
    }
    $mongo['history'].insert_one(history)
  end

  def list_history(code, user, entry, limit = 100)
    report = {'entries'=>[]}
    $stderr.puts code
    $stderr.puts entry
    query = {}
    query['dict'] = code if code.to_s != ''
    query['user'] = user if user.to_s != ''
    query['entry'] = entry if entry.to_s != ''

    $stderr.puts query
    result = $mongo['history'].find(query, {}).sort({ 'timestamp' => -1 }).limit(limit)

    result.each{|r_entry|
      report['entries'] << r_entry
    }
    report
  end

  def get_history(cid)
    $mongo['history'].find({ '_id': BSON::ObjectId.from_string(cid)}).first
  end

  def history_prev(change)
    $mongo['history'].find({ 'dict': change['dict'], 'entry': change['entry'], '_id': { '$lt': BSON::ObjectId.from_string(change['_id'])}}).sort('_id':-1).limit(1).first
  end

  def history_next(change)
    $mongo['history'].find({ 'dict': change['dict'], 'entry': change['entry'], '_id': { '$gt': BSON::ObjectId.from_string(change['_id'])}}).sort('_id':1).limit(1).first
  end

end
