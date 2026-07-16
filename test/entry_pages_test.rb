require_relative "test_helper"
require "json"

# Routes rendered from fixture data through the FakeMongo (test/fixtures/).
class EntryPagesTest < AppTest
  FIXTURES = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "entries.json")))

  def entry(dict, with: nil)
    FIXTURES.find { |e| e["dict"] == dict && (with.nil? || e.dig(*with).to_s != "") }
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
