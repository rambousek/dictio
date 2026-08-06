require_relative "test_helper"
require "json"

# Routes rendered from fixture data through the FakeMongo (test/fixtures/).
class EntryPagesTest < AppTest
  FIXTURES = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "entries.json")))
  LOCALES = %w[cs de en sk ua].freeze

  def entry(dict, with: nil)
    FIXTURES.find { |e| e["dict"] == dict && (with.nil? || e.dig(*with).to_s != "") }
  end

  # title.slim picks translations matching the *current* UI locale, so a
  # relation that only breaks in one language is invisible to single-locale
  # tests. Render every entry page in all of them.
  def assert_renders_in_every_locale(url)
    LOCALES.each do |locale|
      get url, "lang" => locale
      assert_predicate last_response, :ok?, "#{url} failed for lang=#{locale}"
    end
  end

  # Sweeps every fixture entry rather than one per type: the fixtures are a
  # real production sample, and czj/2909 carries a published cs translation
  # whose target is unresolvable — exactly the shape that broke title.slim.
  def test_every_fixture_entry_renders_in_every_locale
    FIXTURES.each do |e|
      assert_renders_in_every_locale("/#{e["dict"]}/show/#{e["id"]}")
    end
  end

  # A relation whose target entry cannot be resolved: czj_entry.rb skips it
  # with `next if relentry.nil?`, leaving the relation with no 'entry' key.
  # meaning_id must look like "<id>-<number>" so add_rels takes that lookup
  # path in the first place.
  def entry_with_dangling_translation(id, target)
    doc = Marshal.load(Marshal.dump(entry("czj", with: ["lemma", "video_front"])))
    doc["id"] = id
    doc["meanings"][0]["relation"] = [
      {"target" => target, "meaning_id" => "999999-1", "status" => "published", "type" => "translation"}
    ]
    doc
  end

  # Guards against the dangling-relation fix being over-broad and dropping
  # every translation from the title.
  def test_title_still_lists_resolvable_translations
    get "/czj/show/38", "lang" => "cs"
    assert_predicate last_response, :ok?
    assert_match(/<title>.*ČZJ-38 \(.+\).*<\/title>/m, last_response.body)
  end

  def test_show_entry_with_dangling_translation
    $mongo.load("entries", FIXTURES + [entry_with_dangling_translation("88001", "cs")]) # standard:disable Style/GlobalVars
    # cs is the failing case: the dangling relation targets the UI locale.
    assert_renders_in_every_locale("/czj/show/88001")
  ensure
    $mongo.load("entries", FIXTURES) # standard:disable Style/GlobalVars
  end

  def test_homepage_shows_entry_counts
    stat = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "entryStat.json"))).first
    get "/"
    assert_predicate last_response, :ok?
    # the view groups digits by thousands with spaces
    grouped = stat["entries"][0]["count"].to_s.reverse.scan(/\d{3}|.+/).join(" ").reverse
    assert_includes last_response.body, grouped
  end

  def test_show_write_entry
    e = entry("cs", with: ["lemma", "title"])
    get "/#{e["dict"]}/show/#{e["id"]}"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, e["lemma"]["title"]
  end

  def test_show_sign_entry_with_video
    e = entry("czj", with: ["lemma", "video_front"])
    get "/#{e["dict"]}/show/#{e["id"]}"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, e["lemma"]["video_front"]
  end

  def test_homepage_shows_top_searched_and_displayed
    e = entry("cs", with: ["lemma", "title"])
    day = Date.today.strftime("%Y-%m-%d")
    $mongo.load("usageStat", [ # standard:disable Style/GlobalVars
      {"type" => "search", "dict" => "cs", "target" => "", "key" => "škola", "day" => day, "count" => 5},
      {"type" => "show", "dict" => "cs", "target" => "", "key" => e["id"], "day" => day, "count" => 3}
    ])
    get "/?lang=en"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, "/cs/translate/czj/text/%C5%A1kola"
    assert_includes last_response.body, "/cs/show/#{e["id"]}"
    assert_includes last_response.body, e["lemma"]["title"]
    assert_includes last_response.body, I18n.t("home.mostdisplayweek", locale: "en")
  ensure
    $mongo.load("usageStat", []) # standard:disable Style/GlobalVars
  end

  def test_homepage_hides_top_lists_without_data
    get "/"
    assert_predicate last_response, :ok?
    refute_includes last_response.body, "recent__headline"
  end

  def test_public_pages_do_not_load_edit_tools_js
    get "/"
    assert_includes last_response.body, "/js/dictio.js"
    refute_includes last_response.body, "edit-tools.js"
  end

  def test_show_unknown_entry_renders_notfound
    get "/cs/show/99999999"
    assert_predicate last_response, :ok?
    refute_includes last_response.body, "detail__block"
  end

  def test_json_entry
    e = entry("cs", with: ["lemma", "title"])
    get "/#{e["dict"]}/json/#{e["id"]}"
    assert_predicate last_response, :ok?
    doc = JSON.parse(last_response.body)
    assert_equal e["id"], doc["id"]
    assert_equal e["lemma"]["title"], doc["lemma"]["title"]
  end
end
