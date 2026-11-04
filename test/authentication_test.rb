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
    host! "edit.dictio.info"
    https!
  end

  def teardown
    $is_edit = @previous_edit # standard:disable Style/GlobalVars
    $is_admin = @previous_admin # standard:disable Style/GlobalVars
    $mongo.load("users", []) # standard:disable Style/GlobalVars
  end

  def test_login_session_is_shared_by_edit_and_admin
    get "/about"
    assert last_response.redirect?
    assert_includes last_response.location, "/login?return_to=%2Fabout"

    get "/login", return_to: "/about"
    csrf_token = last_response.body[/name="csrf_token" value="([^"]+)"/, 1]
    refute_nil csrf_token
    post "/login", login: USER["login"], password: PASSWORD, return_to: "/about", csrf_token: csrf_token
    assert last_response.redirect?
    assert_equal "/about", URI(last_response.location).path
    cookie = last_response.headers["Set-Cookie"].to_s
    assert_includes cookie, "Domain=.dictio.info"
    assert_includes cookie.downcase, "secure"
    assert_includes cookie.downcase, "httponly"

    $is_edit = false # standard:disable Style/GlobalVars
    $is_admin = true # standard:disable Style/GlobalVars
    host! "admin.dictio.info"
    get "/about"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Test Editor"
  end

  def test_invalid_login_does_not_authorize_protected_pages
    get "/login", return_to: "/about"
    csrf_token = last_response.body[/name="csrf_token" value="([^"]+)"/, 1]
    post "/login", login: USER["login"], password: "wrong", return_to: "/about", csrf_token: csrf_token
    assert_equal 401, last_response.status
    assert_includes last_response.body, 'name="password"'

    get "/about"
    assert last_response.redirect?
    assert_includes last_response.location, "/login?return_to=%2Fabout"
  end

  def test_login_requires_csrf_token
    post "/login", login: USER["login"], password: PASSWORD, return_to: "/about"
    assert_equal 403, last_response.status
  end

  def test_password_change_invalidates_existing_session
    get "/login", return_to: "/about"
    csrf_token = last_response.body[/name="csrf_token" value="([^"]+)"/, 1]
    post "/login", login: USER["login"], password: PASSWORD, return_to: "/about", csrf_token: csrf_token
    assert last_response.redirect?

    changed_user = USER.merge("password" => "new-password".crypt("xy"))
    $mongo.load("users", [changed_user]) # standard:disable Style/GlobalVars
    get "/about"
    assert last_response.redirect?
    assert_includes last_response.location, "/login?return_to=%2Fabout"
  end

  def test_public_site_remains_accessible_without_login
    $is_edit = false # standard:disable Style/GlobalVars
    host! "www.dictio.info"
    $mongo.load("users", []) # standard:disable Style/GlobalVars

    get "/about"
    assert_predicate last_response, :ok?
  end
end
