require_relative "test_helper"

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

  def setup
    @previous_edit = $is_edit
    @previous_admin = $is_admin
    $is_edit = true # standard:disable Style/GlobalVars
    $is_admin = false # standard:disable Style/GlobalVars
    $mongo.load("users", [USER]) # standard:disable Style/GlobalVars
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

  def login
    edit_get "/login"
    token = csrf_token_from_response
    edit_post "/login", login: USER["login"], password: PASSWORD, csrf_token: token
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
  end

  def test_duplicate_entry_is_only_stored_once
    login
    list_id = create_wordlist
    service = CzjWordLists.new

    assert_equal :added, service.add_entry(list_id, USER["login"], "3881")
    assert_equal :duplicate, service.add_entry(list_id, USER["login"], "3881")
    assert_equal 1, service.find_owned(list_id, USER["login"])["entries"].size
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
    assert_includes last_response.location, "error=entry_not_found"
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
              name: "Shared list", sort_mode: "alphabetical", is_public: "true", csrf_token: token
    wordlist = CzjWordLists.new.find_owned(list_id, USER["login"])

    edit_get "/wordlist/#{wordlist['share_token']}"
    assert_equal 404, last_response.status

    $is_edit = false # standard:disable Style/GlobalVars
    $is_admin = false # standard:disable Style/GlobalVars
    get "https://www.dictio.info/wordlist/#{wordlist['share_token']}"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Shared list"
    assert_includes last_response.body, "vosk"
    refute_match(/<form\b/, last_response.body)
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
