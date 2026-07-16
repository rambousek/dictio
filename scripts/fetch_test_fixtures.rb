# Fetch a small sample of documents from the live MongoDB into test/fixtures/.
# Read-only. Never touches the users collection. Run from the repo root:
#   bundle exec ruby scripts/fetch_test_fixtures.rb
require "mongo"
require "json"
require_relative "../lib/host-config"

Mongo::Logger.logger.level = Logger::WARN
client = Mongo::Client.new($mongoHost, server_selection_timeout: 10) # standard:disable Style/GlobalVars

FIXDIR = File.expand_path("../test/fixtures", __dir__)
Dir.mkdir(FIXDIR) unless Dir.exist?(FIXDIR)

# Convert BSON types to plain JSON-friendly values.
def plain(val)
  case val
  when BSON::Document, Hash
    val.each_with_object({}) { |(k, v), h| h[k.to_s] = plain(v) unless k.to_s == "_id" }
  when Array then val.map { |v| plain(v) }
  when BSON::ObjectId then val.to_s
  when Time, DateTime then val.to_s
  else val
  end
end

# Walk a document collecting every @media_id value.
def media_ids(val, acc = [])
  case val
  when Hash
    val.each { |k, v| (k == "@media_id") ? acc << v.to_s : media_ids(v, acc) }
  when Array then val.each { |v| media_ids(v, acc) }
  end
  acc
end

entries = {}
media = {}
sw = {}

fetch_entry = lambda do |dict, id|
  key = "#{dict}-#{id}"
  return entries[key] if entries.key?(key)
  doc = client["entries"].find({"dict" => dict, "id" => id, "empty" => {"$exists" => false}}).first
  return nil if doc.nil?
  entries[key] = plain(doc)
end

# Referenced docs one level deep: collocations, relations, media, sw.
add_refs = lambda do |entry|
  dict = entry["dict"]
  (entry.dig("collocations", "colloc") || []).each { |cid| fetch_entry.call(dict, cid) }
  (entry["meanings"] || []).each do |mean|
    (mean["relation"] || []).each do |rel|
      next unless rel["meaning_id"].to_s =~ /^([0-9]+)-[0-9]+(_us[0-9]+)?$/
      fetch_entry.call(rel["target"], $1)
    end
  end
  media_ids(entry).uniq.each do |mid|
    doc = client["media"].find({"id" => mid, "dict" => dict}).first
    media["#{dict}-#{mid}"] = plain(doc) if doc
  end
  if entry.dig("lemma", "video_front").to_s != ""
    doc = client["media"].find({"location" => entry["lemma"]["video_front"], "dict" => dict}).first
    media["#{dict}-loc-#{entry["lemma"]["video_front"]}"] = plain(doc) if doc
  end
  swdoc = client["sw"].find({"id" => entry["id"], "dict" => dict}).first
  sw["#{dict}-#{entry["id"]}"] = plain(swdoc) if swdoc
end

# One written-language entry with relations, one sign-language entry with video.
seed_write = client["entries"].find({"dict" => "cs", "empty" => {"$exists" => false},
                                     "meanings.relation" => {"$exists" => true}}).first
seed_sign = client["entries"].find({"dict" => "czj", "empty" => {"$exists" => false},
                                    "lemma.video_front" => {"$exists" => true, "$ne" => ""},
                                    "meanings.relation" => {"$exists" => true}}).first
seed_colloc = client["entries"].find({"dict" => "czj", "empty" => {"$exists" => false},
                                      "lemma.video_front" => {"$exists" => true, "$ne" => ""},
                                      "collocations.colloc.0" => {"$exists" => true}}).first
seed_colloc_w = client["entries"].find({"dict" => "cs", "empty" => {"$exists" => false},
                                        "collocations.colloc.0" => {"$exists" => true}}).first
raise "no seed entries found" if seed_write.nil? || seed_sign.nil?

[seed_write, seed_sign, seed_colloc, seed_colloc_w].compact.map { |e| plain(e) }.each do |entry|
  entries["#{entry["dict"]}-#{entry["id"]}"] = entry
end
entries.values.dup.each { |e| add_refs.call(e) }

stat = client["entryStat"].find({}, sort: {"dateField" => -1}).first
raise "no entryStat" if stat.nil?

File.write(File.join(FIXDIR, "entries.json"), JSON.pretty_generate(entries.values))
File.write(File.join(FIXDIR, "media.json"), JSON.pretty_generate(media.values))
File.write(File.join(FIXDIR, "sw.json"), JSON.pretty_generate(sw.values))
File.write(File.join(FIXDIR, "entryStat.json"), JSON.pretty_generate([plain(stat)]))

puts "entries: #{entries.size} (seeds cs-#{seed_write["id"]}, czj-#{seed_sign["id"]})"
puts "media: #{media.size}, sw: #{sw.size}, entryStat: 1"
