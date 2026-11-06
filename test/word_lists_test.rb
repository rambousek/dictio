require_relative "test_helper"
require "uri"

class WordListsTest < AppTest
  PASSWORD = "wordlist-password"
  USER = {
    "login" => "wordlist-user",
    "password" => PASSWORD.crypt("ab"),
    "name" => "Wordlist User",
    "email" => "wordlist@example.test",
    "skupina" => "",
    "copy" => "",
    "autor" => "",
    "zdroj" => "",
    "admin" => false,
    "editor" => [],
    "revizor" => [],
    "lang" => [],
    "default_dict" => "cs",
    "default_lang" => "cs",
    "edit_dict" => [],
    "edit_synonym" => false,
    "edit_trans" => false
  }.freeze
  COLLABORATOR_PASSWORD = "wordlist-collaborator-password"
  COLLABORATOR = USER.merge(
    "login" => "wordlist-collaborator",
    "password" => COLLABORATOR_PASSWORD.crypt("ab"),
    "email" => "wordlist-collaborator@example.test"
  ).freeze

  def setup
    @previous_edit = $is_edit
    @previous_admin = $is_admin
    $is_edit = true # standard:disable Style/GlobalVars
    $is_admin = false # standard:disable Style/GlobalVars
    $mongo.load("users", [USER, COLLABORATOR]) # standard:disable Style/GlobalVars
    $mongo.load("wordlists", []) # standard:disable Style/GlobalVars
  end

  def teardown
    $is_edit = @previous_edit # standard:disable Style/GlobalVars
    $is_admin = @previous_admin # standard:disable Style/GlobalVars
    $mongo.load("users", []) # standard:disable Style/GlobalVars
    $mongo.load("wordlists", []) # standard:disable Style/GlobalVars
  end

  def edit_get(path)
    get "https://edit.dictio.info#{path}"
  end

  def edit_post(path, params = {})
    post "https://edit.dictio.info#{path}", params
  end

  def login(user = USER, password = PASSWORD)
    edit_get "/login"
    token = csrf_token_from_response
    edit_post "/login", login: user["login"], password: password, csrf_token: token
    assert last_response.redirect?
  end

  def create_wordlist(name: "Test list", dict: "cs")
    edit_get "/wordlists"
    token = csrf_token_from_response
    edit_post "/wordlists", name: name, dict: dict, csrf_token: token
    assert last_response.redirect?
    last_response.location.split("/").last
  end

  def test_wordlist_management_requires_login
    edit_get "/wordlists"

    assert last_response.redirect?
    assert_includes last_response.location, "/login"
  end

  def test_create_query_opens_wordlist_creation_form
    login

    edit_get "/wordlists?create=true"

    assert last_response.ok?
    assert_includes last_response.body, 'id="new-wordlist-form"'
    refute_match(/id="new-wordlist-form"[^>]*display:\s*none/, last_response.body)
  end

  def test_owner_can_create_add_sort_and_remove_entries
    login
    list_id = create_wordlist

    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/entries", entry_id: "3881", csrf_token: token
    assert last_response.redirect?

    wordlist = CzjWordLists.new.find_owned(list_id, USER["login"])
    assert_equal [{"dict" => "cs", "id" => "3881"}], wordlist["entries"]

    edit_get "/wordlists/#{list_id}"
    assert_includes last_response.body, "vosk"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/entries/3881/remove", csrf_token: token
    assert_empty CzjWordLists.new.find_owned(list_id, USER["login"])["entries"]
  end

  def test_owner_can_rename_wordlist_without_changing_settings
    login
    list_id = create_wordlist
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/#{list_id}/name", name: "Renamed list", csrf_token: token

    assert last_response.redirect?
    wordlist = CzjWordLists.new.find_owned(list_id, USER["login"])
    assert_equal "Renamed list", wordlist["name"]
    assert_equal "manual", wordlist["sort_mode"]
    assert_equal "all", wordlist["second_language"]
  end

  def test_owner_can_share_and_revoke_wordlist_access
    login
    list_id = create_wordlist
    service = CzjWordLists.new
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/#{list_id}/sharing",
              shared_with: "#{COLLABORATOR['login']}, #{USER['login']}", csrf_token: token
    assert last_response.redirect?
    assert_equal [COLLABORATOR["login"]], service.find_owned(list_id, USER["login"])["shared_with"]
    assert service.find_accessible(list_id, COLLABORATOR["login"])
    assert_includes service.list_for(COLLABORATOR["login"]), service.find_owned(list_id, USER["login"])

    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/sharing", shared_with: "", csrf_token: token
    assert last_response.redirect?
    assert_nil service.find_accessible(list_id, COLLABORATOR["login"])
    assert service.find_owned(list_id, USER["login"])
  end

  def test_sharing_rejects_unknown_users_without_changing_access
    login
    list_id = create_wordlist
    service = CzjWordLists.new
    service.update_sharing(list_id, USER["login"], COLLABORATOR["login"])
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/#{list_id}/sharing", shared_with: "missing-user", csrf_token: token

    assert_includes last_response.location, "error=invalid_users"
    assert_equal [COLLABORATOR["login"]], service.find_owned(list_id, USER["login"])["shared_with"]
  end

  def test_owner_can_transfer_wordlist_ownership_and_remains_a_collaborator
    login
    list_id = create_wordlist
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/#{list_id}/transfer",
              new_owner_login: COLLABORATOR["login"], csrf_token: token

    assert last_response.redirect?
    assert_includes last_response.location, "transferred=true"
    service = CzjWordLists.new
    wordlist = service.find_owned(list_id, COLLABORATOR["login"])
    assert_equal [USER["login"]], wordlist["shared_with"]
    assert_nil service.find_owned(list_id, USER["login"])
    assert service.find_accessible(list_id, USER["login"])
    assert_equal 0, service.delete(list_id, USER["login"]).deleted_count
    edit_get URI(last_response.location).request_uri
    assert_includes last_response.body, I18n.t("wordlists.ownership_transferred")
    refute_includes last_response.body, "/transfer"
  end

  def test_ownership_transfer_rejects_unknown_user
    login
    list_id = create_wordlist
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/#{list_id}/transfer",
              new_owner_login: "missing-user", csrf_token: token

    assert_includes last_response.location, "error=invalid_owner"
    assert CzjWordLists.new.find_owned(list_id, USER["login"])
  end

  def test_shared_user_can_edit_wordlist_but_cannot_delete_or_manage_sharing
    service = CzjWordLists.new
    wordlist = service.create(USER["login"], "Shared list", "cs")
    assert_equal :updated, service.update_sharing(wordlist["_id"], USER["login"], COLLABORATOR["login"])
    login(COLLABORATOR, COLLABORATOR_PASSWORD)

    edit_get "/wordlists/#{wordlist['_id']}"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, I18n.t("wordlists.shared_with_you")
    refute_includes last_response.body, "/sharing"
    refute_includes last_response.body, "/transfer"
    refute_includes last_response.body, "/delete"

    token = csrf_token_from_response
    edit_post "/wordlists/#{wordlist['_id']}/entries", entry_id: "3881", csrf_token: token
    assert_equal [{"dict" => "cs", "id" => "3881"}],
                 service.find_owned(wordlist["_id"], USER["login"])["entries"]

    edit_post "/wordlists/#{wordlist['_id']}/name",
              name: "Changed by collaborator", csrf_token: token
    assert_equal "Changed by collaborator", service.find_owned(wordlist["_id"], USER["login"])["name"]

    edit_post "/wordlists/#{wordlist['_id']}/delete", csrf_token: token
    assert_equal 403, last_response.status
    assert service.find_owned(wordlist["_id"], USER["login"])

    edit_post "/wordlists/#{wordlist['_id']}/sharing",
              shared_with: "", csrf_token: token
    assert_equal 404, last_response.status
    assert service.find_accessible(wordlist["_id"], COLLABORATOR["login"])

    edit_post "/wordlists/#{wordlist['_id']}/transfer",
              new_owner_login: COLLABORATOR["login"], csrf_token: token
    assert_equal 404, last_response.status
    assert service.find_owned(wordlist["_id"], USER["login"])
  end

  def test_wordlist_settings_can_be_updated_without_submitting_name
    login
    list_id = create_wordlist(name: "Keep this name")
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/#{list_id}/update",
              sort_mode: "alphabetical", second_language: "all",
              is_public: "false", csrf_token: token

    assert last_response.redirect?
    refute_includes last_response.location, "error=invalid"
    wordlist = CzjWordLists.new.find_owned(list_id, USER["login"])
    assert_equal "Keep this name", wordlist["name"]
    assert_equal "alphabetical", wordlist["sort_mode"]
  end

  def test_entry_page_action_adds_to_the_selected_wordlist
    login
    list_id = create_wordlist
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/add-entry",
              wordlist_id: list_id, dict: "cs", entry_id: "3881", csrf_token: token

    assert last_response.redirect?
    assert_includes last_response.location, "/cs/show/3881?wordlist_added=true"
    assert_equal [{"dict" => "cs", "id" => "3881"}],
                 CzjWordLists.new.find_owned(list_id, USER["login"])["entries"]

    edit_get "/cs/show/3881?wordlist_added=true"
    assert_includes last_response.body, I18n.t("wordlists.entry_added")
    assert_includes last_response.body, 'href="/wordlists?create=true"'
    assert_includes last_response.body, 'href="/wordlists"'
    assert_includes last_response.body, I18n.t("wordlists.show")
  end

  def test_wordlist_link_is_disabled_when_user_has_no_wordlists
    login

    edit_get "/cs/show/3881"

    assert_includes last_response.body, "disabled"
    assert_includes last_response.body, I18n.t("wordlists.show")
  end

  def test_duplicate_entry_is_only_stored_once
    login
    list_id = create_wordlist
    service = CzjWordLists.new

    assert_equal :added, service.add_entry(list_id, USER["login"], "3881")
    assert_equal :duplicate, service.add_entry(list_id, USER["login"], "3881")
    assert_equal 1, service.find_owned(list_id, USER["login"])["entries"].size
  end

  def test_multiple_entries_can_be_added_from_comma_separated_ids
    login
    list_id = create_wordlist

    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/entries",
              entry_id: "3881, 3881, missing-id", csrf_token: token

    assert last_response.redirect?
    assert_includes last_response.location, "added=1"
    assert_includes last_response.location, "duplicate=1"
    assert_includes last_response.location, "missing=1"
    assert_equal [{"dict" => "cs", "id" => "3881"}],
                 CzjWordLists.new.find_owned(list_id, USER["login"])["entries"]
    edit_get URI(last_response.location).request_uri
    assert_includes last_response.body, I18n.t(
      "wordlists.batch_result", added: 1, duplicate: 1, missing: 1, invalid: 0
    )
  end

  def test_wordlist_mutations_require_csrf
    login

    edit_post "/wordlists", name: "No token", dict: "cs"

    assert_equal 403, last_response.status
  end

  def test_wordlist_rejects_an_entry_from_a_different_dictionary
    login
    list_id = create_wordlist(dict: "cs")

    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/entries", entry_id: "38", csrf_token: token

    assert_empty CzjWordLists.new.find_owned(list_id, USER["login"])["entries"]
    assert_includes last_response.location, "missing=1"
  end

  def test_private_wordlist_is_not_public_and_other_users_cannot_own_it
    login
    list_id = create_wordlist
    service = CzjWordLists.new
    wordlist = service.find_owned(list_id, USER["login"])

    assert_nil service.find_owned(list_id, "another-user")
    assert_nil service.find_public(wordlist["share_token"])

    $is_edit = false # standard:disable Style/GlobalVars
    get "https://www.dictio.info/wordlist/#{wordlist['share_token']}"
    assert_equal 404, last_response.status
  end

  def test_public_wordlist_is_read_only
    login
    list_id = create_wordlist
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/entries", entry_id: "3881", csrf_token: token

    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/update",
              name: "Shared list", sort_mode: "alphabetical", second_language: "all",
              is_public: "true", csrf_token: token
    wordlist = CzjWordLists.new.find_owned(list_id, USER["login"])

    edit_get "/wordlist/#{wordlist['share_token']}"
    assert_equal 404, last_response.status

    $is_edit = false # standard:disable Style/GlobalVars
    $is_admin = false # standard:disable Style/GlobalVars
    get "https://www.dictio.info/wordlist/#{wordlist['share_token']}"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Shared list"
    assert_includes last_response.body, "vosk"
    assert_includes last_response.body, 'href="/cs/show/3881"'
    refute_includes last_response.body, "vosk (3881)"
    assert_includes last_response.body, 'class="wordlist-entry-row"'
    refute_match(/<form\b/, last_response.body)
  end

  def test_entry_urls_follow_the_wordlists_second_language
    service = CzjWordLists.new
    item = {"dict" => "cs", "id" => "3881"}

    assert_equal "/cs/show/3881", service.entry_url({"second_language" => "all"}, item)
    assert_equal "/cs/search/text/3881", service.entry_url({"second_language" => "none"}, item)
    assert_equal "/en/translate/cs/text/*/cs-3881", service.entry_url({"second_language" => "en"}, item)
    assert_equal "/cs/show/3881", service.entry_url({}, item)

    sign_item = {"dict" => "czj", "id" => "1234"}
    sign_wordlist = {"dict" => "czj", "second_language" => "cs"}
    assert_equal "/cs/translate/czj/text/*/czj-1234", service.entry_url(sign_wordlist, sign_item)
  end

  def test_sign_language_wordlist_displays_front_video_at_report_size
    login
    list_id = create_wordlist(dict: "czj")
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/entries", entry_id: "10000", csrf_token: token
    edit_get "/wordlists/#{list_id}"

    video_tag = last_response.body[/<video\b[^>]*>/]
    assert video_tag, "Expected a video element for the sign-language entry"
    assert_includes video_tag, 'class="czj"'
    assert_includes video_tag, 'width="177"'
    assert_includes video_tag, 'height="142"'
    assert_includes last_response.body, 'src="https://files.dictio.info/videoczj/A_velryba1.mp4"'
  end

  def test_wordlist_shows_only_up_to_five_published_translations
    service = CzjWordLists.new
    entry = {
      "meanings" => [{
        "relation" => [
          {"type" => "translation", "target" => "cs", "meaning_id" => "pohádka", "status" => "published"},
          {"type" => "translation", "target" => "czj", "meaning_id" => "10000-1", "status" => "published"},
          {"type" => "translation", "target" => "cs", "meaning_id" => "skryté", "status" => "hidden"},
          {"type" => "translation", "target" => "cs", "meaning_id" => "šestý", "status" => "published"},
          {"type" => "translation", "target" => "cs", "meaning_id" => "sedmý", "status" => "published"},
          {"type" => "translation", "target" => "cs", "meaning_id" => "osmý", "status" => "published"},
          {"type" => "translation", "target" => "cs", "meaning_id" => "devátý", "status" => "published"}
        ]
      }]
    }

    translations = service.approved_translations(entry, "all")

    assert_equal 5, translations.length
    assert_equal "pohádka", translations.first["title"]
    assert_equal "czj", translations[1]["dict"]
    assert_equal "A_velryba1.mp4", translations[1]["video"]
    refute translations.any? { |translation| translation["title"] == "skryté" }

    assert_empty service.approved_translations(entry, "none")
    cs_translations = service.approved_translations(entry, "cs")
    assert_equal %w[pohádka šestý sedmý osmý devátý], cs_translations.map { |translation| translation["title"] }
    assert cs_translations.all? { |translation| translation["dict"] == "cs" }
    assert_equal ["czj"], service.approved_translations(entry, "czj").map { |translation| translation["dict"] }
  end

  def test_wordlist_renders_approved_sign_translation_video
    login
    list_id = create_wordlist
    entry = $mongo["entries"].find({"dict" => "cs", "id" => "3881"}).first # standard:disable Style/GlobalVars
    original_meanings = Marshal.load(Marshal.dump(entry["meanings"])) # standard:disable Style/GlobalVars
    begin
      $mongo["entries"].update_one(
        {"dict" => "cs", "id" => "3881"},
        {"$set" => {"meanings" => [{
          "relation" => [{
            "type" => "translation",
            "target" => "czj",
            "meaning_id" => "10000-1",
            "status" => "published"
          }]
        }]}}
      ) # standard:disable Style/GlobalVars
      edit_get "/wordlists/#{list_id}"
      token = csrf_token_from_response
      edit_post "/wordlists/#{list_id}/entries", entry_id: "3881", csrf_token: token
      edit_get "/wordlists/#{list_id}"

      assert_includes last_response.body, 'src="https://files.dictio.info/videoczj/A_velryba1.mp4"'
    ensure
      $mongo["entries"].update_one(
        {"dict" => "cs", "id" => "3881"},
        {"$set" => {"meanings" => original_meanings}}
      ) # standard:disable Style/GlobalVars
    end
  end

  def test_second_language_is_saved_and_rejects_unknown_dictionary
    login
    list_id = create_wordlist
    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response

    edit_post "/wordlists/#{list_id}/update",
              name: "Translated list", sort_mode: "manual", second_language: "en",
              is_public: "false", csrf_token: token

    assert_equal "en", CzjWordLists.new.find_owned(list_id, USER["login"])["second_language"]
    CzjWordLists.new.add_entry(list_id, USER["login"], "3881")
    edit_get "/wordlists/#{list_id}"
    assert_includes last_response.body, 'href="/en/translate/cs/text/*/cs-3881"'

    edit_get "/wordlists/#{list_id}"
    token = csrf_token_from_response
    edit_post "/wordlists/#{list_id}/update",
              name: "Translated list", sort_mode: "manual", second_language: "unknown",
              is_public: "false", csrf_token: token

    assert_includes last_response.location, "error=invalid"
    assert_equal "en", CzjWordLists.new.find_owned(list_id, USER["login"])["second_language"]
  end

  def test_manual_order_can_be_changed
    service = CzjWordLists.new
    wordlist = service.create(USER["login"], "Order", "cs")
    $mongo["wordlists"].update_one(
      {"_id" => wordlist["_id"]},
      {"$set" => {"entries" => [{"dict" => "cs", "id" => "3881"}, {"dict" => "cs", "id" => "41198"}]}}
    ) # standard:disable Style/GlobalVars

    assert service.move_entry(wordlist["_id"], USER["login"], "41198", "up")
    assert_equal %w[41198 3881], service.find_owned(wordlist["_id"], USER["login"])["entries"].map { |entry| entry["id"] }
  end
end
