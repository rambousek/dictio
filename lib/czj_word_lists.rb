require "securerandom"

class CzjWordLists
  SORT_MODES = %w[alphabetical id manual].freeze
  SECOND_LANGUAGE_MODES = %w[none all].freeze
  SECOND_LANGUAGE_ALL = "all"
  MAX_NAME_LENGTH = 100

  def self.ensure_indexes
    collection = $mongo["wordlists"].indexes
    collection.create_one({"owner_login" => 1, "updated_at" => -1})
    collection.create_one({"share_token" => 1}, unique: true)
  rescue => e
    $stderr.puts "wordlists index creation failed: #{e.message}"
  end

  def list_for(owner_login, dictcode = nil)
    query = {"owner_login" => owner_login.to_s}
    query["dict"] = dictcode.to_s unless dictcode.to_s.empty?
    $mongo["wordlists"].find(query, :sort => {"updated_at" => -1}).to_a
  end

  def find_owned(id, owner_login)
    $mongo["wordlists"].find({"_id" => id.to_s, "owner_login" => owner_login.to_s}).first
  end

  def find_public(share_token)
    $mongo["wordlists"].find({"share_token" => share_token.to_s, "is_public" => true}).first
  end

  def create(owner_login, name, dictcode)
    name = clean_name(name)
    return nil if name.empty? || !$dict_info.key?(dictcode.to_s)

    wordlist = {
      "_id" => SecureRandom.hex(16),
      "owner_login" => owner_login.to_s,
      "name" => name,
      "dict" => dictcode.to_s,
      "second_language" => SECOND_LANGUAGE_ALL,
      "is_public" => false,
      "share_token" => SecureRandom.urlsafe_base64(24, false),
      "sort_mode" => "manual",
      "entries" => [],
      "created_at" => Time.now,
      "updated_at" => Time.now
    }
    $mongo["wordlists"].insert_one(wordlist)
    wordlist
  end

  def update(id, owner_login, name: nil, sort_mode:, second_language:, is_public:)
    wordlist = find_owned(id, owner_login)
    return nil unless wordlist

    name = clean_name(name.nil? ? wordlist["name"] : name)
    second_language = second_language.to_s
    valid_second_language = SECOND_LANGUAGE_MODES.include?(second_language) || $dict_info.key?(second_language)
    return nil if name.empty? || !SORT_MODES.include?(sort_mode.to_s) || !valid_second_language

    $mongo["wordlists"].update_one(
      {"_id" => wordlist["_id"], "owner_login" => owner_login.to_s},
      {"$set" => {
        "name" => name,
        "sort_mode" => sort_mode.to_s,
        "second_language" => second_language,
        "is_public" => !!is_public,
        "updated_at" => Time.now
      }}
    )
    find_owned(id, owner_login)
  end

  def update_name(id, owner_login, name)
    wordlist = find_owned(id, owner_login)
    return nil unless wordlist

    name = clean_name(name)
    return nil if name.empty?

    $mongo["wordlists"].update_one(
      {"_id" => wordlist["_id"], "owner_login" => owner_login.to_s},
      {"$set" => {"name" => name, "updated_at" => Time.now}}
    )
    find_owned(id, owner_login)
  end

  def entry_url(wordlist, item)
    dictcode = item["dict"].to_s
    entry_id = Rack::Utils.escape_path(item["id"].to_s)
    second_language = wordlist["second_language"].to_s
    second_language = SECOND_LANGUAGE_ALL unless SECOND_LANGUAGE_MODES.include?(second_language) ||
                                                   $dict_info.key?(second_language)

    case second_language
    when "none"
      "/#{dictcode}/search/text/#{entry_id}"
    when "all"
      "/#{dictcode}/show/#{entry_id}"
    else
      "/#{second_language}/translate/#{dictcode}/text/*/#{dictcode}-#{entry_id}"
    end
  end

  def delete(id, owner_login)
    $mongo["wordlists"].delete_one({"_id" => id.to_s, "owner_login" => owner_login.to_s})
  end

  def add_entry(id, owner_login, entry_id)
    wordlist = find_owned(id, owner_login)
    return :not_found unless wordlist

    entry_id = entry_id.to_s.strip
    return :invalid_id if entry_id.empty?
    entry = $mongo["entries"].find(
      {"dict" => wordlist["dict"], "id" => entry_id, "empty" => {"$exists" => false}}
    ).first
    return :entry_not_found unless entry

    entry_ref = {"dict" => wordlist["dict"], "id" => entry_id}
    result = $mongo["wordlists"].update_one(
      {"_id" => wordlist["_id"], "owner_login" => owner_login.to_s},
      {"$addToSet" => {"entries" => entry_ref}}
    )
    return :not_found if result.matched_count.zero?
    return :duplicate if result.modified_count.zero?

    $mongo["wordlists"].update_one(
      {"_id" => wordlist["_id"], "owner_login" => owner_login.to_s},
      {"$set" => {"updated_at" => Time.now}}
    )
    :added
  end

  def add_entries(id, owner_login, entry_ids)
    return nil unless find_owned(id, owner_login)

    ids = entry_ids.to_s.split(",", -1).map(&:strip).reject(&:empty?)
    results = Hash.new(0)
    ids = [""] if ids.empty?
    ids.each do |entry_id|
      results[add_entry(id, owner_login, entry_id)] += 1
    end
    results
  end

  def remove_entry(id, owner_login, entry_id)
    wordlist = find_owned(id, owner_login)
    return false unless wordlist

    $mongo["wordlists"].update_one(
      {"_id" => wordlist["_id"], "owner_login" => owner_login.to_s},
      {"$pull" => {"entries" => {"dict" => wordlist["dict"], "id" => entry_id.to_s}},
       "$set" => {"updated_at" => Time.now}}
    )
    true
  end

  def move_entry(id, owner_login, entry_id, direction)
    wordlist = find_owned(id, owner_login)
    return false unless wordlist && %w[up down].include?(direction)

    entries = Array(wordlist["entries"]).map(&:dup)
    index = entries.index { |entry| entry["id"] == entry_id.to_s && entry["dict"] == wordlist["dict"] }
    return false unless index

    target_index = direction == "up" ? index - 1 : index + 1
    return false unless target_index.between?(0, entries.length - 1)

    entries[index], entries[target_index] = entries[target_index], entries[index]
    $mongo["wordlists"].update_one(
      {"_id" => wordlist["_id"], "owner_login" => owner_login.to_s},
      {"$set" => {"entries" => entries, "updated_at" => Time.now}}
    )
    true
  end

  def entries_for(wordlist)
    refs = Array(wordlist["entries"])
    return [] if refs.empty?

    ids = refs.map { |entry| entry["id"].to_s }
    field = $dict_info[wordlist["dict"]]["type"] == "sign" ? "lemma.video_front" : "lemma.title"
    sort = case wordlist["sort_mode"]
           when "alphabetical" then {field => 1, "id" => 1}
           when "id" then {"id" => 1}
           else nil
           end
    options = {
      :collation => {"locale" => collation_locale(wordlist["dict"]), "numericOrdering" => true}
    }
    options[:sort] = sort if sort
    docs = $mongo["entries"].find(
      {"dict" => wordlist["dict"], "id" => {"$in" => ids}, "empty" => {"$exists" => false}},
      options
    ).to_a
    docs_by_id = docs.each_with_object({}) { |entry, result| result[entry["id"].to_s] = entry }
    ordered_refs = if %w[alphabetical id].include?(wordlist["sort_mode"])
                     docs.map { |entry| {"dict" => entry["dict"], "id" => entry["id"].to_s} } +
                       refs.reject { |ref| docs_by_id.key?(ref["id"].to_s) }
                   else
                     refs
                   end
    ordered_refs.map do |ref|
      entry = docs_by_id[ref["id"].to_s]
      {
        "dict" => ref["dict"],
        "id" => ref["id"].to_s,
        "entry" => entry,
        "translations" => entry ? approved_translations(entry, wordlist["second_language"]) : []
      }
    end
  end

  def approved_translations(entry, second_language)
    second_language = second_language.to_s
    second_language = SECOND_LANGUAGE_ALL unless SECOND_LANGUAGE_MODES.include?(second_language) ||
                                                   $dict_info.key?(second_language)
    return [] if second_language == "none"

    translations = []
    entry_cache = {}
    relations = Array(entry["meanings"]).flat_map do |meaning|
      Array(meaning["relation"])
    end

    relations.each do |relation|
      next unless relation["type"] == "translation" && relation["status"] == "published"

      target = relation["target"].to_s
      next unless $dict_info.key?(target)
      next unless second_language == SECOND_LANGUAGE_ALL || target == second_language

      meaning_id = relation["meaning_id"].to_s
      if (match = /\A(\d+)-\d+(?:_us\d+)?\z/.match(meaning_id))
        target_id = match[1]
        cache_key = [target, target_id]
        unless entry_cache.key?(cache_key)
          entry_cache[cache_key] = $mongo["entries"].find(
            {"dict" => target, "id" => target_id, "empty" => {"$exists" => false}}
          ).first
        end
        target_entry = entry_cache[cache_key]
        next unless target_entry

        lemma = target_entry["lemma"] || {}
        translation = {"dict" => target, "title" => lemma["title"].to_s}
        video_front = lemma["video_front"].to_s
        translation["video"] = video_front unless video_front.empty?
      else
        translation = {"dict" => target, "title" => meaning_id}
      end

      next if translation["title"].empty? && translation["video"].to_s.empty?

      translations << translation
      break if translations.length == 5
    end

    translations
  end

  private

  def clean_name(name)
    name.to_s.strip[0, MAX_NAME_LENGTH]
  end

  def collation_locale(dictcode)
    locale = $dict_info[dictcode]["search_in"] || dictcode
    {"sj" => "sk", "lse" => "es", "uzm" => "uk"}[locale] || locale
  end
end
