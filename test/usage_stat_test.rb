require_relative "test_helper"
require "date"

# CzjUsageStat aggregation against injected usageStat docs (FakeMongo).
class UsageStatTest < Minitest::Test
  def day(ago)
    (Date.today - ago).strftime("%Y-%m-%d")
  end

  def stat(type, dict, key, count, days_ago = 0, target = "")
    {"type" => type, "dict" => dict, "target" => target, "key" => key,
     "day" => day(days_ago), "count" => count}
  end

  def teardown
    $mongo.load("usageStat", []) # standard:disable Style/GlobalVars
  end

  def test_track_is_noop_in_test_mode
    # FakeMongo raises on any write, so this passing proves the $is_test gate
    CzjUsageStat.track("search", "cs", "škola")
  end

  def test_top_searched_merges_types_and_days
    $mongo.load("usageStat", [ # standard:disable Style/GlobalVars
      stat("search", "cs", "škola", 3, 0),
      stat("search", "cs", "škola", 2, 3),
      stat("translate", "cs", "škola", 4, 1, "czj"),
      stat("search", "cs", "pes", 5, 2),
      stat("show", "cs", "3881", 100, 0)
    ])
    top = CzjUsageStat.top_searched
    assert_equal [["cs", "škola", 9], ["cs", "pes", 5]],
      top.map { |r| [r["dict"], r["key"], r["count"]] }
  end

  def test_top_searched_ignores_old_days_and_honors_limit
    docs = [stat("search", "cs", "stary", 99, 8)]
    docs += (1..7).map { |i| stat("search", "cs", "slovo#{i}", i, 0) }
    $mongo.load("usageStat", docs) # standard:disable Style/GlobalVars
    top = CzjUsageStat.top_searched(7, 5)
    assert_equal 5, top.size
    assert_equal "slovo7", top.first["key"]
    refute_includes top.map { |r| r["key"] }, "stary"
  end

  def test_top_displayed_resolves_labels_and_skips_unknown_entries
    entry = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "entries.json")))
      .find { |e| e["dict"] == "cs" && e.dig("lemma", "title").to_s != "" }
    $mongo.load("usageStat", [ # standard:disable Style/GlobalVars
      stat("show", "cs", entry["id"], 5, 1),
      stat("show", "cs", "99999999", 9, 0)
    ])
    top = CzjUsageStat.top_displayed
    assert_equal 1, top.size
    assert_equal entry["lemma"]["title"], top.first["label"]
  end

  def test_top_displayed_label_fallback_for_sign_entries
    entry = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "entries.json")))
      .find { |e| e["dict"] == "czj" && e.dig("lemma", "title").to_s == "" }
    $mongo.load("usageStat", [stat("show", "czj", entry["id"], 2, 0)]) # standard:disable Style/GlobalVars
    top = CzjUsageStat.top_displayed
    assert_equal "ČZJ " + entry["id"].to_s, top.first["label"]
  end
end
