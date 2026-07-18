#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json'
require 'bson'
require 'open-uri'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'net/scp'
require 'resolv'
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
require_relative 'lib/czj_fuzzy_match'
require_relative 'lib/czj_csv_report'

class CzjApp < Sinatra::Base
  $mongo = Mongo::Client.new($mongoHost) if $mongo.nil?
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
    set :host_authorization, permitted_host: [$hostname]
    set :session_secret, $session_secret
    I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
    I18n.load_path = Dir[File.join(settings.root, 'locales', '*.yml')]
    I18n.backend.load_translations
    I18n.default_locale = 'cs'
    enable :sessions
  end
  
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
      headers['WWW-Authenticate'] = 'Basic realm="CZJ"'
      halt 401, {'Refresh' => '1; URL=https://www.dictio.info?login_fail=true'}, 'Not authorized'
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      if @auth.provided? and @auth.basic? and @auth.credentials
        user = @auth.credentials.first.force_encoding('UTF-8')
        pass = @auth.credentials[1].force_encoding('UTF-8')
        res = $mongo['users'].find({'login':user}).first
        return false if res.nil?
        if user == res['login'] and pass.crypt(res['password'][0,2]) == res['password']
          @user_info = {'login'=>res['login'], 'name'=>res['name'], 'email'=>res['email'], 'skupina'=>res['skupina'], 'copy'=>res['copy'], 'autor'=>res['autor'], 'zdroj'=>res['zdroj'], 'perm'=>[], 'admin'=>res['admin'], 'editor'=>res['editor'], 'revizor'=>res['revizor'], 'dict_allowed'=>res['lang'], 'default_dict'=>res['default_dict'], 'default_lang'=>res['default_lang'], 'edit_dict'=>res['edit_dict'], 'edit_synonym'=>res['edit_synonym'], 'edit_trans'=>res['edit_trans']}
          res['editor'].each{|e| @user_info['perm'] << 'editor_'+e}
          res['revizor'].each{|e| @user_info['perm'] << 'revizor_'+e}
          @user_info['perm'] = ['admin'] if res['admin']
          return true
        end
      end
      return false
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
    protected! if $is_edit or $is_admin
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
    @search_limit = 10
    @translate_limit = 9
    @report_limit = 15
    cookies.set(:dictio_pref, {:httponly=>false, :value=>(WRITE_DICTS+SIGN_DICTS).map{|i| 'dict-'+i+'=true'}.join(';')})
    @is_edit = $is_edit
    @is_admin = $is_admin
    @is_test = $is_test
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
require_relative "routes/swapi"
