require_relative "test_helper"
require "json"

# Edit-mode rendering of the sign detail templates. The public site runs with
# $is_edit false, so without these the *_edit templates are never exercised and
# fixes applied to the public copies can silently miss their edit twins.
class EntryEditPagesTest < AppTest
  ENTRIES = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "entries.json")))

  # czjapp.rb runs `protected!` on every request once $is_edit is set, and
  # authorized? compares pass.crypt(stored[0, 2]) against the stored value.
  EDITOR_PASSWORD = "secret"
  EDITOR = {
    "login" => "editor", "password" => EDITOR_PASSWORD.crypt("ab"),
    "name" => "Test Editor", "email" => "editor@example.org", "skupina" => "",
    "copy" => "", "autor" => "", "zdroj" => "", "admin" => false,
    "editor" => ["czj"], "revizor" => [], "lang" => ["czj", "cs"],
    "default_dict" => "czj", "default_lang" => "cs",
    "edit_dict" => [], "edit_synonym" => [], "edit_trans" => []
  }.freeze

  def in_edit_mode
    previous = $is_edit # standard:disable Style/GlobalVars
    $is_edit = true # standard:disable Style/GlobalVars
    $mongo.load("users", [EDITOR]) # standard:disable Style/GlobalVars
    basic_authorize EDITOR["login"], EDITOR_PASSWORD
    yield
  ensure
    $is_edit = previous # standard:disable Style/GlobalVars
    $mongo.load("entries", ENTRIES) # standard:disable Style/GlobalVars
    $mongo.load("users", []) # standard:disable Style/GlobalVars
  end

  # A relation whose meaning_id is free text rather than an "id-number"
  # reference: czj_entry.rb resolves it to an entry hash carrying only a lemma,
  # with no 'id' key. Targeting another dictionary is what makes the templates
  # take the rel['target'] + '-' + rel['entry']['id'] branch.
  def entry_with_textual_relation(id, *types)
    doc = Marshal.load(Marshal.dump(ENTRIES.find { |e| e["dict"] == "czj" }))
    doc["id"] = id
    doc["meanings"][0]["relation"] = types.map do |type|
      {"target" => "cs", "meaning_id" => "skákat do vody", "status" => "published", "type" => type}
    end
    doc
  end

  def test_edit_sign_entry_with_textual_synonym
    in_edit_mode do
      $mongo.load("entries", ENTRIES + [entry_with_textual_relation("77001", "synonym")]) # standard:disable Style/GlobalVars
      get "/czj/searchentry/77001"
      assert_predicate last_response, :ok?
    end
  end

  def test_edit_sign_entry_with_textual_antonym
    in_edit_mode do
      $mongo.load("entries", ENTRIES + [entry_with_textual_relation("77002", "antonym")]) # standard:disable Style/GlobalVars
      get "/czj/searchentry/77002"
      assert_predicate last_response, :ok?
    end
  end

  # The parent renders homosigndetail_edit for each homonym, so the relation
  # lives on the homonym entry. Synonyms and antonyms need separate cases: the
  # synonym block renders first and would abort before reaching the antonym.
  def assert_homonym_page_renders(parent_id, homonym_id, type)
    in_edit_mode do
      parent = Marshal.load(Marshal.dump(ENTRIES.find { |e| e["dict"] == "czj" }))
      parent["id"] = parent_id
      parent["lemma"]["homonym"] = [homonym_id]
      homonym = entry_with_textual_relation(homonym_id, type)
      $mongo.load("entries", ENTRIES + [parent, homonym]) # standard:disable Style/GlobalVars
      get "/czj/searchentry/#{parent_id}"
      assert_predicate last_response, :ok?
    end
  end

  def test_edit_sign_homonym_with_textual_synonym
    assert_homonym_page_renders("77004", "77003", "synonym")
  end

  def test_edit_sign_homonym_with_textual_antonym
    assert_homonym_page_renders("77006", "77005", "antonym")
  end

  # The remaining *_edit templates had no coverage at all. czj/38 is used for
  # the sign cases because it carries translations, which is what pulls in
  # fullentrytrans_edit.
  def test_edit_full_sign_entry
    in_edit_mode do
      get "/czj/show/38"
      assert_predicate last_response, :ok?
      # the /editor link is emitted only by the *_edit templates, so this
      # proves the edit branch was taken rather than the public fallback
      assert_includes last_response.body, "/editor"
    end
  end

  def test_edit_full_write_entry
    in_edit_mode do
      get "/cs/show/#{ENTRIES.find { |e| e["dict"] == "cs" }["id"]}"
      assert_predicate last_response, :ok?
      assert_includes last_response.body, "/editor"
    end
  end

  def test_edit_write_searchentry
    in_edit_mode do
      get "/cs/searchentry/#{ENTRIES.find { |e| e["dict"] == "cs" }["id"]}"
      assert_predicate last_response, :ok?
      assert_includes last_response.body, "/editor"
    end
  end

  # homonymsign_edit renders from fullentrysigndetail_edit, so this needs the
  # /show route rather than /searchentry. Fixture czj/2909 points at homonym
  # 21592, which is not in the fixture subset, so inject the pair.
  def test_edit_full_sign_entry_with_homonym
    in_edit_mode do
      parent = Marshal.load(Marshal.dump(ENTRIES.find { |e| e["dict"] == "czj" }))
      parent["id"] = "77007"
      parent["lemma"]["homonym"] = ["38"]
      $mongo.load("entries", ENTRIES + [parent]) # standard:disable Style/GlobalVars
      get "/czj/show/77007"
      assert_predicate last_response, :ok?
      assert_includes last_response.body, "homonym-block"
    end
  end
end
