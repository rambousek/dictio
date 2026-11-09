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

  def test_password_reset_uses_one_time_token_and_updates_password
    edit_get "/password-reset"
    csrf_token = csrf_token_from_response
    assert_includes last_response.body, I18n.t("auth.password_reset_instructions")

    sent_mail = nil
    original_send_mail = CzjMail.method(:send_mail)
    CzjMail.define_singleton_method(:send_mail) do |to, subject, body|
      sent_mail = [to, subject, body]
    end
    begin
      edit_post "/password-reset", email: USER["email"].upcase, csrf_token: csrf_token
    ensure
      CzjMail.define_singleton_method(:send_mail, original_send_mail)
    end

    assert_predicate last_response, :ok?
    assert_includes last_response.body, I18n.t("auth.password_reset_sent")
    assert_equal USER["email"], sent_mail[0]
    assert_includes sent_mail[2], "https://edit.dictio.info/reset-password/"
    token = sent_mail[2].match(%r{/reset-password/([A-Za-z0-9_-]+)})[1]
    stored_user = $mongo["users"].find({"login" => USER["login"]}).first
    refute_equal token, stored_user["password_reset_token_hash"]
    assert_operator stored_user["password_reset_expires_at"], :>, Time.now

    edit_get "/reset-password/#{token}"
    assert_equal "no-referrer", last_response.headers["Referrer-Policy"]
    assert_includes last_response.body, 'name="password_confirmation"'
    csrf_token = csrf_token_from_response
    edit_post "/reset-password/#{token}",
              password: "a-new-secure-password",
              password_confirmation: "a-new-secure-password",
              csrf_token: csrf_token

    assert_predicate last_response, :ok?
    assert_includes last_response.body, I18n.t("auth.password_reset_success")
    stored_user = $mongo["users"].find({"login" => USER["login"]}).first
    assert CzjUsers.password_valid?("a-new-secure-password", stored_user["password"])
    refute CzjUsers.password_valid?(PASSWORD, stored_user["password"])
    assert_nil stored_user["password_reset_token_hash"]
    assert_nil stored_user["password_reset_expires_at"]
    assert_equal :invalid_token,
                 CzjUsers.reset_password(token, "another-secure-password", "another-secure-password")

    edit_get "/login"
    edit_post "/login", login: USER["login"], password: "a-new-secure-password",
                        csrf_token: csrf_token_from_response
    assert last_response.redirect?
  end

  def test_password_reset_request_and_submission_require_csrf
    edit_post "/password-reset", email: USER["email"]
    assert_equal 403, last_response.status

    edit_post "/reset-password/invalid-token",
              password: "a-new-secure-password",
              password_confirmation: "a-new-secure-password"
    assert_equal 403, last_response.status
  end

  def test_password_reset_page_uses_global_layout_and_hides_account_existence
    edit_get "/password-reset"
    csrf_token = csrf_token_from_response
    assert_includes last_response.body, '<header class="header"'
    assert_includes last_response.body, '<footer class="footer"'
    assert_includes last_response.body, I18n.t("auth.password_reset_title")

    original_send_mail = CzjMail.method(:send_mail)
    CzjMail.define_singleton_method(:send_mail) do |_to, _subject, _body|
    end
    begin
      edit_post "/password-reset", email: USER["email"], csrf_token: csrf_token
      known_account_response = last_response.body
      assert_includes known_account_response, I18n.t("auth.password_reset_sent")

      edit_post "/password-reset", email: "unknown@example.test", csrf_token: csrf_token
      assert_equal known_account_response, last_response.body
    ensure
      CzjMail.define_singleton_method(:send_mail, original_send_mail)
    end
  end

  def test_login_page_links_to_registration
    edit_get "/login"

    assert_includes last_response.body, '<header class="header"'
    assert_includes last_response.body, '<footer class="footer"'
    assert_match(/<meta\b(?=[^>]*name="robots")(?=[^>]*content="noindex,nofollow")[^>]*>/, last_response.body)
    assert_includes last_response.body, "<title>#{I18n.t('auth.title')}</title>"
    assert_includes last_response.body, 'href="/password-reset"'
    assert_includes last_response.body, 'href="/register"'
    assert_includes last_response.body, 'href="https://www.dictio.info/"'
    assert_includes last_response.body, 'href="https://www.dictio.info/about"'
    assert_includes last_response.body, 'href="https://www.dictio.info/help"'
    assert_includes last_response.body, 'href="https://www.dictio.info/contact"'
    assert_includes last_response.body, 'href="https://www.dictio.info/?lang=cs"'
    refute_includes last_response.body, 'href="https://edit.dictio.info/login"'
    refute_includes last_response.body, 'class="mobile-search'
  end

  def test_registration_and_activation_use_the_global_layout
    edit_get "/register"
    assert_includes last_response.body, '<header class="header"'
    assert_includes last_response.body, '<footer class="footer"'
    assert_includes last_response.body, "<title>#{I18n.t('auth.register_title')}</title>"
    assert_includes last_response.body, 'href="https://www.dictio.info/about"'
    assert_includes last_response.body, 'href="https://www.dictio.info/help"'
    assert_includes last_response.body, 'href="https://www.dictio.info/contact"'
    assert_includes last_response.body, 'href="https://www.dictio.info/?lang=cs"'
    refute_includes last_response.body, 'href="https://edit.dictio.info/register"'
    refute_includes last_response.body, 'class="mobile-search'

    edit_get "/activate/invalid-token"
    assert_includes last_response.body, '<header class="header"'
    assert_includes last_response.body, '<footer class="footer"'
    assert_includes last_response.body, "<title>#{I18n.t('auth.activation_title')}</title>"
    assert_includes last_response.body, 'href="https://www.dictio.info/about"'
    assert_includes last_response.body, 'href="https://www.dictio.info/help"'
    assert_includes last_response.body, 'href="https://www.dictio.info/contact"'
    refute_includes last_response.body, 'class="mobile-search'
  end

  def test_registration_requires_email_activation_before_login
    edit_get "/register"
    csrf_token = csrf_token_from_response
    assert_includes last_response.body, 'name="organization"'
    assert_includes last_response.body, I18n.t("auth.organization")
    sent_mail = nil
    registration_params = {
      login: "new-user",
      name: "New User",
      organization: "Example Organization",
      email: "new-user@example.test",
      password: "a-secure-password",
      password_confirmation: "a-secure-password",
      csrf_token: csrf_token
    }

    original_send_mail = CzjMail.method(:send_mail)
    CzjMail.define_singleton_method(:send_mail) do |to, subject, body|
      sent_mail = [to, subject, body]
    end
    begin
      edit_post "/register", registration_params
    ensure
      CzjMail.define_singleton_method(:send_mail, original_send_mail)
    end

    assert_predicate last_response, :ok?
    assert_includes last_response.body, I18n.t("auth.registration_sent")
    refute_nil sent_mail
    assert_equal "new-user@example.test", sent_mail[0]
    assert_includes sent_mail[2], "https://edit.dictio.info/activate/"

    user = $mongo["users"].find({"login" => "new-user"}).first
    assert_equal false, user["email_verified"]
    assert_equal false, user["admin"]
    assert_equal "Example Organization", user["organization"]
    assert_empty user["editor"]
    assert CzjUsers.password_valid?("a-secure-password", user["password"])
    refute CzjUsers.password_valid?("wrong-password", user["password"])

    edit_get "/login"
    edit_post "/login", login: "new-user", password: "a-secure-password",
                        csrf_token: csrf_token_from_response
    assert_equal 401, last_response.status

    activation_token = sent_mail[2].match(%r{/activate/([A-Za-z0-9_-]+)})[1]
    edit_get "/activate/#{activation_token}"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, I18n.t("auth.activation_success")
    assert_equal true, $mongo["users"].find({"login" => "new-user"}).first["email_verified"]

    edit_get "/login"
    edit_post "/login", login: "new-user", password: "a-secure-password",
                        csrf_token: csrf_token_from_response
    assert last_response.redirect?
  end

  def test_registration_rejects_invalid_data_and_requires_csrf
    edit_post "/register", login: "x", name: "", email: "invalid",
                           password: "short", password_confirmation: "different"
    assert_equal 403, last_response.status

    edit_get "/register"
    edit_post "/register", login: "x", name: "", email: "invalid",
                           password: "short", password_confirmation: "different",
                           csrf_token: csrf_token_from_response

    assert_equal 422, last_response.status
    assert_empty $mongo["users"].find({"login" => "x"}).to_a
  end

  def test_user_can_update_organization_in_profile_settings
    edit_get "/login"
    edit_post "/login", login: USER["login"], password: PASSWORD,
                        csrf_token: csrf_token_from_response
    assert last_response.redirect?

    edit_get "/usersettings"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'name="organization"'
    assert_includes last_response.body, I18n.t("admin.users.organization")

    edit_post "/savesettings",
              name: USER["name"], email: USER["email"], organization: "Example Institute",
              default_lang: "cs", default_dict: "cs"

    assert last_response.redirect?
    user = $mongo["users"].find({"login" => USER["login"]}).first
    assert_equal "Example Institute", user["organization"]
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

  def test_video_export_is_forbidden_to_regular_editors
    edit_get "/login"
    csrf_token = csrf_token_from_response
    edit_post "/login", login: USER["login"], password: PASSWORD, csrf_token: csrf_token
    assert last_response.redirect?

    edit_post "/czj/video-export/start", csrf_token: csrf_token, front: "1"

    assert_equal 403, last_response.status
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
