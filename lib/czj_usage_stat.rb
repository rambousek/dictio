# usage tracking for the homepage "most searched / most displayed" lists;
# daily counter docs in $mongo['usageStat'], written only on the public server
module CzjUsageStat
  module_function

  KEEP_DAYS = 90
  CACHE_TTL = 3600
  BOT_UA = /bot|crawl|spider|slurp|curl|wget/i

  # fire-and-forget: never raises, never runs on edit/admin/test instances
  def track(type, dict, key, target = '', ua = nil)
    return if $is_edit or $is_admin or $is_test
    return if ua.to_s =~ BOT_UA
    key = key.to_s.strip
    return if key == '' or key == '_'
    key = key.downcase unless type == 'show'
    $mongo['usageStat'].update_one(
      {'type'=>type, 'dict'=>dict, 'target'=>target.to_s, 'key'=>key, 'day'=>Time.now.strftime('%Y-%m-%d')},
      {'$inc'=>{'count'=>1}, '$setOnInsert'=>{'date'=>Time.now.utc}},
      upsert: true)
  rescue => e
    $stderr.puts 'usageStat track failed: '+e.message
  end

  # top queries over the last +days+, search+translate merged, grouped by (dict, key)
  def top_searched(days = 7, limit = 5)
    top_keys(%w[search translate], days, limit)
  end

  # top opened entries over the last +days+, resolved to display labels
  def top_displayed(days = 7, limit = 5)
    rows = top_keys(['show'], days, limit*2)
    resolved = []
    rows.each{|row|
      entry = $mongo['entries'].find({'dict'=>row['dict'], 'id'=>row['key'], 'empty'=>{'$exists'=>false}}).first
      next if entry.nil?
      row['label'] = entry.dig('lemma', 'title').to_s
      row['label'] = $dict_info[row['dict']]['label'] + ' ' + row['key'] if row['label'] == ''
      resolved << row
      break if resolved.size == limit
    }
    resolved
  end

  def top_keys(types, days, limit)
    cutoff = (Date.today - days).strftime('%Y-%m-%d')
    $mongo['usageStat'].aggregate([
      {'$match'=>{'type'=>{'$in'=>types}, 'day'=>{'$gte'=>cutoff}}},
      {'$group'=>{'_id'=>{'dict'=>'$dict', 'key'=>'$key'}, 'count'=>{'$sum'=>'$count'}}},
      {'$sort'=>{'count'=>-1}},
      {'$limit'=>limit}
    ]).map{|d| {'dict'=>d['_id']['dict'], 'key'=>d['_id']['key'], 'count'=>d['count']}}
  end

  # cached [top_searched, top_displayed] pair for the homepage (per-worker cache)
  def homepage_top
    return compute_top if $is_test
    if @cache.nil? or Time.now - @cache_at > CACHE_TTL
      @cache = compute_top
      @cache_at = Time.now
    end
    @cache
  end

  def compute_top
    [top_searched, top_displayed]
  rescue => e
    $stderr.puts 'usageStat aggregation failed: '+e.message
    [[], []]
  end

  # idempotent, called from a boot thread
  def ensure_indexes
    idx = $mongo['usageStat'].indexes
    idx.create_one({'type'=>1, 'dict'=>1, 'target'=>1, 'key'=>1, 'day'=>1}, unique: true)
    idx.create_one({'type'=>1, 'day'=>1})
    idx.create_one({'date'=>1}, expire_after: KEEP_DAYS*24*3600)
  rescue => e
    $stderr.puts 'usageStat index creation failed: '+e.message
  end
end
