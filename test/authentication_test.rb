require_relative "test_helper"
require "uri"

class AuthenticationTest < AppTest
  PASSWORD = "test-password"
  USER = {
    "login" => "editor",
    "password" => PASSWORD.crypt("ab"),
    "name" => "Test Editor",
    "email" => "editor@example.test",
    "skupina" => "",
    "copy" => "",
    "autor" => "",
    "zdroj" => "",
    "admin" => false,
    "editor" => [],
    "revizor" => [],
    "lang" => [],
    "default_dict" => "",
    "default_lang" => "",
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
  end

  def edit_get(path, params = {})
    get "https://edit.dictio.info#{path}", params
  end

  def edit_post(path, params = {})
    post "https://edit.dictio.info#{path}", params
  end

  def teardown
    $is_edit = @previous_edit # standard:disable Style/GlobalVars
    $is_admin = @previous_admin # standard:disable Style/GlobalVars
    $mongo.load("users", []) # standard:disable Style/GlobalVars
  end

  def test_login_session_is_shared_by_edit_and_admin
    edit_get "/about"
    assert last_response.redirect?
    assert_includes last_response.location, "/login?return_to=%2Fabout"

    edit_get "/login", return_to: "/about"
    csrf_token = csrf_token_from_response
    refute_nil csrf_token
    initial_cookie = Array(last_response.headers["Set-Cookie"]).find do |value|
      value.start_with?("dictio.session=")
    end
    refute_nil initial_cookie, "login page must issue the session cookie used for CSRF validation"
    assert_includes initial_cookie.downcase, "domain=.dictio.info"
    edit_post "/login", login: USER["login"], password: PASSWORD, return_to: "/about", csrf_token: csrf_token
    assert last_response.redirect?
    assert_equal "/about", URI(last_response.location).path
    cookie = Array(last_response.headers["Set-Cookie"]).find do |value|
      value.start_with?("dictio.session=")
    end
    refute_nil cookie
    assert_includes cookie.downcase, "domain=.dictio.info"
    assert_includes cookie.downcase, "secure"
    assert_includes cookie.downcase, "httponly"

    $is_edit = false # standard:disable Style/GlobalVars
    $is_admin = true # standard:disable Style/GlobalVars
    get "https://admin.dictio.info/about"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Test Editor"
  end

  def test_invalid_login_does_not_authorize_protected_pages
    edit_get "/login", return_to: "/about"
    csrf_token = csrf_token_from_response
    edit_post "/login", login: USER["login"], password: "wrong", return_to: "/about", csrf_token: csrf_token
    assert_equal 401, last_response.status
    assert_includes last_response.body, 'name="password"'

    edit_get "/about"
    assert last_response.redirect?
    assert_includes last_response.location, "/login?return_to=%2Fabout"
  end

  def test_login_requires_csrf_token
    edit_post "/login", login: USER["login"], password: PASSWORD, return_to: "/about"
    assert_equal 403, last_response.status
  end

  def test_administrator_links_are_available_from_edit_only_to_admin_users
    edit_get "/login"
    csrf_token = csrf_token_from_response
    admin_user = USER.merge("admin" => true)
    $mongo.load("users", [admin_user]) # standard:disable Style/GlobalVars
    edit_post "/login", login: admin_user["login"], password: PASSWORD, csrf_token: csrf_token
    assert last_response.redirect?

    edit_get "/about"
    assert_includes last_response.body, "https://admin.dictio.info/users"
    assert_includes last_response.body, "https://admin.dictio.info/history"
    assert_includes last_response.body, "https://admin.dictio.info/import"
  end

  def test_administrator_links_are_hidden_from_regular_editors
    edit_get "/login"
    csrf_token = csrf_token_from_response
    edit_post "/login", login: USER["login"], password: PASSWORD, csrf_token: csrf_token
    assert last_response.redirect?

    edit_get "/about"
    refute_includes last_response.body, "https://admin.dictio.info/users"
    refute_includes last_response.body, "https://admin.dictio.info/history"
    refute_includes last_response.body, "https://admin.dictio.info/import"
  end

  def test_password_change_invalidates_existing_session
    edit_get "/login", return_to: "/about"
    csrf_token = csrf_token_from_response
    edit_post "/login", login: USER["login"], password: PASSWORD, return_to: "/about", csrf_token: csrf_token
    assert last_response.redirect?

    changed_user = USER.merge("password" => "new-password".crypt("xy"))
    $mongo.load("users", [changed_user]) # standard:disable Style/GlobalVars
    edit_get "/about"
    assert last_response.redirect?
    assert_includes last_response.location, "/login?return_to=%2Fabout"
  end

  def test_public_site_remains_accessible_without_login
    $is_edit = false # standard:disable Style/GlobalVars
    $mongo.load("users", []) # standard:disable Style/GlobalVars

    get "https://www.dictio.info/about"
    assert_predicate last_response, :ok?
  end
end
