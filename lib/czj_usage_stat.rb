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

  # top queries over the last +days+, search+translate merged, grouped by (dict, key);
  # numeric-only keys (id lookups, not real words) are dropped
  def top_searched(days = 7, limit = 5)
    rows = top_keys(%w[search translate], days, limit*3)
    rows.reject{|row| row['key'] =~ /\A\d+\z/}.first(limit)
  end

  # top opened entries over the last +days+, resolved to display labels
  def top_displayed(days = 7, limit = 5)
    rows = top_keys(['show'], days, limit*2)
    resolved = []
    rows.each{|row|
      entry = $mongo['entries'].find({'dict'=>row['dict'], 'id'=>row['key'], 'empty'=>{'$exists'=>false}}).first
      next if entry.nil?
      row['label'] = entry.dig('lemma', 'title').to_s
      row['label'] = display_label(entry, row) if row['label'] == ''
      resolved << row
      break if resolved.size == limit
    }
    resolved
  end

  # sign entries have no text lemma; build a label from translations instead,
  # same dedupe+skip-empty pattern as views/title.slim, tried in the dict's own
  # write language first (search_in), then cs, before falling back to the id
  def display_label(entry, row)
    search_in = $dict_info[row['dict']]['search_in'].to_s
    search_in = 'cs' if search_in == ''
    [search_in, 'cs'].uniq.each{|target|
      translations = entry['meanings'].to_a.flat_map{|m| m['relation'].to_a}
        .select{|rel| rel['type']=='translation' and rel['status']!='hidden' and rel['target']==target}
        .map{|rel| relation_title(rel)}.compact.uniq
      return $dict_info[row['dict']]['label'] + ' ' + translations.join(', ') unless translations.empty?
    }
    $dict_info[row['dict']]['label'] + ' ' + row['key']
  end

  # meaning_id is either "<id>-<number>" (look up the real lemma title) or
  # already human-readable text used as-is — same convention as
  # CzjEntry#add_rels (lib/czj_entry.rb:152-194), but a single light lookup
  # instead of the full getdoc/add_rels path (media/collocation/sign-writing
  # resolution we don't need here, for every relation of every row)
  def relation_title(rel)
    if rel['meaning_id'] =~ /\A\d+-\d+\z/
      lemmaid = rel['meaning_id'].split('-').first
      $mongo['entries'].find({'dict'=>rel['target'], 'id'=>lemmaid, 'empty'=>{'$exists'=>false}}).first&.dig('lemma', 'title')
    else
      rel['meaning_id']
    end
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
