#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'rack/session/cookie'
require 'mongo'
require 'json'
require 'bson'
require 'open-uri'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'net/scp'
require 'resolv'
require 'openssl'
require 'securerandom'
require 'sinatra/cookies'
require 'maxmind/geoip2'
require 'damerau-levenshtein'
require 'yabeda'
require 'yabeda/prometheus'
require 'resolv'

require_relative 'lib/czj'
if ENV['RACK_ENV'] == 'test'
  require_relative 'test/host-config'
else
  require_relative 'lib/host-config'
end
require_relative 'lib/dict-config'
require_relative 'lib/czj_fsw'
require_relative 'lib/czj_comment'
require_relative 'lib/czj_report'
require_relative 'lib/czj_web_helper'
require_relative 'lib/czj_admin'
require_relative 'lib/czj_admin_info'
require_relative 'lib/czj_admin_duplicate'
require_relative 'lib/czj_api_helper'
require_relative 'lib/czj_export_job'
require_relative 'lib/czj_video_export'
require_relative 'lib/czj_fuzzy_match'
require_relative 'lib/czj_csv_report'
require_relative 'lib/czj_entry_json'
require_relative 'lib/czj_korpus'
require_relative 'lib/czj_usage_stat'
require_relative 'lib/czj_word_lists'

class CzjApp < Sinatra::Base
  $mongo = Mongo::Client.new($mongoHost) if $mongo.nil?
  Thread.new { CzjUsageStat.ensure_indexes } unless $is_test
  Thread.new { CzjWordLists.ensure_indexes } unless $is_test
  # GeoIP DB is installed on the servers; without it (CI) the country lookup
  # at $georeader.country raises and falls back to the hostname heuristic.
  geoip_db = '/usr/share/GeoIP/GeoLite2-Country.mmdb'
  $georeader = MaxMind::GeoIP2::Reader.new(database: geoip_db) if File.exist?(geoip_db)
  
  configure do
    set :bind, '0.0.0.0'
    set :server, :puma
    set :strict_paths, false
    set :logging, true
    set :environment, $environment
    set :session_secret, $session_secret
    I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
    I18n.load_path = Dir[File.join(settings.root, 'locales', '*.yml')]
    I18n.backend.load_translations
    I18n.default_locale = 'cs'
  end

  use Rack::Session::Cookie,
    key: 'dictio.session',
    domain: '.dictio.info',
    secret: $session_secret,
    httponly: true,
    secure: true,
    same_site: :lax,
    assume_ssl: true
  
  write_dicts = []
  sign_dicts = []
  $dict_info.each{|code,info|
    if info['type'] == 'write'
      write_dicts << code
    else
      sign_dicts << code
    end
  }
  # constants so route files reopening the class can reference them
  WRITE_DICTS = write_dicts
  SIGN_DICTS = sign_dicts
  $dict_array = {}
  COMMENTS = CzjComment.new
  COMMENTS.sign_dicts = SIGN_DICTS
  REPORTS = CzjReport.new
  REPORTS.sign_dicts = SIGN_DICTS
  ADMIN_DICT = CzjAdmin.new

  @user_info = nil
  helpers Sinatra::Cookies
  helpers do
    def protected!
      return if authorized?
      redirect "/login?#{Rack::Utils.build_query('return_to' => request.fullpath)}"
    end

    def authorized?
      login = session[:user_login]
      return false if login.to_s.empty?

      user = $mongo['users'].find({'login': login}).first
      signature = session[:auth_signature].to_s
      current_signature = user && OpenSSL::HMAC.hexdigest('SHA256', $session_secret, user['password'].to_s)
      unless user && user['email_verified'] != false && signature.length == current_signature.length &&
          Rack::Utils.secure_compare(signature, current_signature)
        session.delete(:user_login)
        session.delete(:auth_signature)
        return false
      end

      @user_info = {
        'login' => user['login'],
        'name' => user['name'],
        'email' => user['email'],
        'organization' => user['organization'],
        'skupina' => user['skupina'],
        'copy' => user['copy'],
        'autor' => user['autor'],
        'zdroj' => user['zdroj'],
        'perm' => [],
        'admin' => user['admin'],
        'editor' => user['editor'],
        'revizor' => user['revizor'],
        'dict_allowed' => user['lang'],
        'default_dict' => user['default_dict'],
        'default_lang' => user['default_lang'],
        'edit_dict' => user['edit_dict'],
        'edit_synonym' => user['edit_synonym'],
        'edit_trans' => user['edit_trans']
      }
      user['editor'].each { |e| @user_info['perm'] << 'editor_' + e }
      user['revizor'].each { |e| @user_info['perm'] << 'revizor_' + e }
      @user_info['perm'] = ['admin'] if user['admin']
      true
    end

    def can_edit_entries?
      return false unless @user_info
      return true if @user_info['admin']

      permissions = Array(@user_info['perm'])
      !permissions.empty? && !permissions.include?('editor_komparator')
    end

    def can_view_entry_ids?
      can_edit_entries? || Array(@user_info && @user_info['perm']).include?('editor_komparator')
    end

    def can_view_admin_menu?
      return false unless @user_info

      @user_info['admin'] || !Array(@user_info['perm']).empty?
    end

    def can_view_duplicate_list?
      can_view_admin_menu? && !Array(@user_info && @user_info['perm']).include?('editor_komparator')
    end

    def safe_return_path(path)
      return '/' unless path.is_a?(String)
      return '/' unless path.start_with?('/') && !path.start_with?('//')
      return '/' if path.include?("\\") || path.match?(/[\r\n]/)
      return '/' if path == '/login' || path.start_with?('/login?') || path == '/logout'

      path
    end

    def csrf_token
      session[:csrf_token] ||= SecureRandom.hex(32)
    end

    def verify_csrf_token!
      expected = session[:csrf_token].to_s
      provided = params['csrf_token'].to_s
      valid = expected.length == provided.length && !expected.empty? &&
        Rack::Utils.secure_compare(expected, provided)
      halt 403, 'Invalid CSRF token' unless valid
    end

    def protected_host?
      $is_edit || $is_admin
    end

    # Unsolved comments assigned to logged-in user, per dictionary
    def assigned_comments
      return {} unless @user_info
      @assigned_comments ||= COMMENTS.count_assigned(@user_info['login'])
    end

    def get_hostname(ip)
      $stdout.puts 'START getname '+Time.now.to_s
      begin
        name = Resolv.getname(ip)
      rescue
        name = ip.to_s
      end
      $stdout.puts 'END getname '+Time.now.to_s
      return name
    end

    def lang_defaults
      unless request.get_header('HTTP_X_FORWARDED_FOR').nil?
        ipaddr = request.get_header('HTTP_X_FORWARDED_FOR')
      else
        ipaddr = request.get_header('REMOTE_ADDR')
      end
      if @user_info and @user_info['default_lang'].to_s != '' and @user_info['default_dict'].to_s != ''
        return @user_info['default_lang'].to_s, @user_info['default_dict'].to_s, $dict_info[@user_info['default_dict'].to_s]['target']
      else
        begin
          georecord = $georeader.country(ipaddr.split(',')[0])
          country = georecord.country.iso_code
        rescue
          if get_hostname(ipaddr).end_with?('cz')
            country = 'CZ'
          else
            country = 'EN'
          end
        end
        case country
        when 'CZ'
          default_locale = 'cs'
          default_dict = 'cs'
          default_target = 'czj'
        when 'SK'
          default_locale = 'sk'
          default_dict = 'sj'
          default_target = 'spj'
        when 'DE','AT'
          default_locale = 'de'
          default_dict = 'de'
          default_target = 'ogs'
        when 'US'
          default_locale = 'en'
          default_dict = 'en'
          default_target = 'asl'
        else
          default_locale = 'en'
          default_dict = 'en'
          default_target = 'is'
        end
        return default_locale, default_dict, default_target
      end
    end
  end


  before do
    @request = request
    public_auth_path = ['/login', '/logout', '/register', '/password-reset'].include?(request.path_info) ||
      request.path_info.start_with?('/activate/', '/reset-password/')
    public_auth_page = ['/login', '/register', '/password-reset'].include?(request.path_info) ||
      request.path_info.start_with?('/activate/', '/reset-password/')
    @public_site_url = public_auth_page ? 'https://www.dictio.info' : ''
    response['Referrer-Policy'] = 'no-referrer' if request.path_info.start_with?('/reset-password/')
    protected! if protected_host? && !public_auth_path
    if @user_info and @user_info['default_lang'].to_s != "" and I18n.available_locales.map(&:to_s).include?(@user_info["default_lang"]) and session[:locale].to_s == ""
      session[:locale] = @user_info['default_lang']
    end
    if params['lang'].to_s != "" and I18n.available_locales.map(&:to_s).include?(params["lang"]) and params['lang'] != session[:locale]
      session[:locale] = params['lang']
    end
    @selectlang = session[:locale]
    default_locale, @default_dict, @default_target = lang_defaults
    if @selectlang.nil?
      @selectlang = default_locale
      session[:locale] = default_locale
    end
    I18n.locale = @selectlang
    @langpath = request.fullpath.gsub(/lang=[a-z]*/,'').gsub(/&&*/,'&')
    @langpath += '?' unless @langpath.include?('?')
    @language_link_base = @public_site_url.empty? ? @langpath : "#{@public_site_url}/?"
    @search_limit = 10
    @translate_limit = 9
    @report_limit = 15
    cookies.set(:dictio_pref, {:httponly=>false, :value=>(WRITE_DICTS+SIGN_DICTS).map{|i| 'dict-'+i+'=true'}.join(';')})
    @is_edit = $is_edit
    @is_admin = $is_admin
    @is_test = $is_test
  end

  get '/login' do
    halt 404 unless protected_host?

    @page_title = I18n.t("auth.title")
    @noindex = true
    @login_return_to = safe_return_path(params['return_to'])
    if authorized?
      redirect @login_return_to
    else
      slim :login
    end
  end

  post '/login' do
    halt 404 unless protected_host?
    verify_csrf_token!
    @page_title = I18n.t("auth.title")
    @noindex = true

    login = params['login'].to_s.force_encoding('UTF-8')
    password = params['password'].to_s.force_encoding('UTF-8')
    user = $mongo['users'].find({'login': login}).first
    stored_password = user && user['password'].to_s

    if user && user['login'] == login && user['email_verified'] != false &&
        CzjUsers.password_valid?(password, stored_password)
      session.clear
      session[:user_login] = user['login']
      session[:auth_signature] = OpenSSL::HMAC.hexdigest('SHA256', $session_secret, stored_password)
      redirect safe_return_path(params['return_to'])
    else
      @login_error = true
      @login_return_to = safe_return_path(params['return_to'])
      status 401
      slim :login
    end
  end

  get '/register' do
    @page_title = I18n.t("auth.register_title")
    @noindex = true
    @registration_error = params['error']
    slim :register
  end

  get '/password-reset' do
    @page_title = I18n.t("auth.password_reset_title")
    @noindex = true
    slim :password_reset
  end

  post '/password-reset' do
    verify_csrf_token!
    @page_title = I18n.t("auth.password_reset_title")
    @noindex = true
    reset = CzjUsers.create_password_reset(params['email'])
    if reset
      reset_url = "https://edit.dictio.info/reset-password/#{Rack::Utils.escape_path(reset['token'])}"
      subject = I18n.t("auth.password_reset_email_subject")
      message = I18n.t("auth.password_reset_email_body", login: reset["login"], url: reset_url)
      begin
        CzjMail.send_mail(reset["email"], subject, message)
      rescue StandardError => e
        $stderr.puts "password reset email delivery failed for #{reset['login']}: #{e.message}"
      end
    end
    @password_reset_sent = true
    slim :password_reset
  end

  get '/reset-password/:token' do
    @page_title = I18n.t("auth.password_reset_title")
    @noindex = true
    @password_reset_token = params['token']
    slim :password_reset
  end

  post '/reset-password/:token' do
    verify_csrf_token!
    @page_title = I18n.t("auth.password_reset_title")
    @noindex = true
    @password_reset_token = params['token']
    result = CzjUsers.reset_password(
      @password_reset_token,
      params['password'],
      params['password_confirmation']
    )
    if result == true
      @password_reset_success = true
    else
      @password_reset_error = result.to_s
      status 422 unless result == :invalid_token
    end
    slim :password_reset
  end

  post '/register' do
    verify_csrf_token!
    @page_title = I18n.t("auth.register_title")
    @noindex = true
    registration = CzjUsers.register_user(
      login: params['login'],
      password: params['password'],
      password_confirmation: params['password_confirmation'],
      name: params['name'],
      email: params['email'],
      organization: params['organization']
    )
    if registration.is_a?(Hash)
      activation_url = "https://edit.dictio.info/activate/#{Rack::Utils.escape_path(registration['token'])}"
      subject = I18n.t("auth.activation_email_subject")
      message = I18n.t("auth.activation_email_body", login: registration["login"], url: activation_url)
      begin
        CzjMail.send_mail(registration["email"], subject, message)
      rescue StandardError => e
        $stderr.puts "registration email delivery failed for #{registration['login']}: #{e.message}"
        @registration_error = "email_failed"
        status 503
        slim :register
      else
        @registration_sent = true
        slim :register
      end
    else
      @registration_error = registration.to_s
      status 422
      slim :register
    end
  end

  get '/activate/:token' do
    @page_title = I18n.t("auth.activation_title")
    @noindex = true
    @activation_success = CzjUsers.activate_user(params['token'])
    slim :registration_activation
  end

  post '/logout' do
    halt 404 unless protected_host?
    verify_csrf_token!

    session.clear
    redirect 'https://www.dictio.info'
  end


  (WRITE_DICTS+SIGN_DICTS).each{|code|
  	$stdout.puts code
    dict = CZJDict.new(code)
    dict.write_dicts = WRITE_DICTS
    dict.sign_dicts = SIGN_DICTS
    dict.dict_info = $dict_info
    dict.comments = COMMENTS
    $dict_array[code] = dict
 




  }


  get '/testerror' do
    raise ZeroDivisionError
  end
  not_found do
    @dict_info = $dict_info
    @search_params = {}
    @target = @default_target
    @dictcode = @default_dict
    slim :error404, :status=>404
  end
  error do
    @dict_info = $dict_info
    @search_params = {}
    @target = @default_target
    @dictcode = @default_dict
    slim :error500, :status=>500
  end
end

require_relative "routes/pages"
require_relative "routes/dict_public"
require_relative "routes/dict_translate"
require_relative "routes/dict_edit"
require_relative "routes/dict_reports"
require_relative "routes/admin"
require_relative "routes/word_lists"
require_relative "routes/swapi"
