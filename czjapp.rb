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

  get '/admin' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'admin'
    @lemma_counts = ADMIN_DICT.info_count.get_count_entry
    @duplicate = CzjAdminDuplicate.get_duplicate_counts
    @notrans_count = ADMIN_DICT.info_count.get_count_relation_notrans
    page = 'admin'
    slim page.to_sym
  end

  (WRITE_DICTS+SIGN_DICTS).each{|code|
  	$stdout.puts code
    dict = CZJDict.new(code)
    dict.write_dicts = WRITE_DICTS
    dict.sign_dicts = SIGN_DICTS
    dict.dict_info = $dict_info
    dict.comments = COMMENTS
    $dict_array[code] = dict
 




    if $is_admin
      get '/'+code+'/jsonduplicate' do
        content_type :json
        CzjAdminDuplicate.get_duplicate(dict).to_json
      end
      get '/'+code+'/duplicatelist(/:start)?(/:limit)?' do
        content_type :json
        CzjAdminDuplicate.get_duplicate(dict, params['start'].to_i, params['limit'].to_i).to_json
      end
      get '/'+code+'/duplicate' do
        @dictcode = code
        @target = ''
        @dict_info = $dict_info
        @params = params
        @report = CzjAdminDuplicate.get_duplicate(dict)
        slim :duplicate
      end
      get '/'+code+'/duplicatesyno' do
        @dictcode = code
        @target = ''
        @dict_info = $dict_info
        @params = params
        @report = CzjAdminDuplicate.get_duplicate_syno(dict)
        slim :duplicate
      end
      get '/'+code+'/notrans' do
        @dictcode = code
        @target = ''
        @dict_info = $dict_info
        @report = {}
        @report['notrans1'] = dict.get_relation_notrans(@params['user'].to_s)
        @report['notrans2'] = dict.get_relation_notrans2(@params['user'].to_s)
        slim :notrans
      end
    end
  }

  if $is_edit or $is_admin
    get '/video' do
      @dict_info = $dict_info
      @search_params = {}
      @request = request
      @selected_page = 'help'
      page = 'video'
      slim page.to_sym
    end

    get '/usersettings' do
      @dict_info = $dict_info
      slim :usersettings
    end

    post '/savesettings' do
      $dict_array['czj'].save_user_setting(@user_info, params)
      redirect to('/usersettings?profile_save=true&lang='+params['default_lang'].to_s)
    end
  end

  if $is_admin
    set (:admin) {|value| condition { @user_info['admin'] == value } }

    get '/users', :admin => false do
      @dict_info = $dict_info
      @search_params = {}
      slim :error401, :status=>401
    end

    get '/users', :admin => true do
      @dict_info = $dict_info
      @users = $dict_array['czj'].get_users
      slim :users
    end

    post '/users/save', :admin => true do
      data = JSON.parse(params['user'])
      res = $dict_array['czj'].save_user(data)
      content_type :json
      if res == true
        {"success"=>true,"msg"=>"Uloženo"}.to_json
      else
        {"success"=>false,"msg"=>res}.to_json
      end
    end

    post '/users/delete', :admin => true do
      res = $dict_array['czj'].delete_user(params['login'])
      content_type :json
      if res == true
        {"success"=>true,"msg"=>"Uloženo"}.to_json
      else
        {"success"=>false,"msg"=>res}.to_json
      end
    end

    get '/duplicates' do
      @dict_info = $dict_info
      @report = CzjAdminDuplicate.get_duplicate_counts
      slim :duplicates
    end

    get '/history' do
      @dict_info = $dict_info
      @users = $mongo['history'].distinct('user').sort
	  limit = params['limit'].to_i
      limit = 100 if limit.nil? or limit == 0
      @report = $dict_array['czj'].list_history(params['code'].to_s, params['user'].to_s, params['entry'].to_s, limit)
      @params = params
      slim :history
    end

    get '/compare/:cid' do
      @dict_info = $dict_info
      @change = $dict_array['czj'].get_history(params['cid'])
      @dictcode = @change['dict']
      @show_dictcode = @change['dict']
      @target = ''
      if @change['full_entry_old']
        @entry_old = $dict_array[@dictcode].full_entry(@change['full_entry_old'], false)
        @entry_old = $dict_array[@dictcode].add_rels(@entry_old, false)
      end
      @entry_new = $dict_array[@dictcode].full_entry(@change['full_entry'], false)
      @entry_new = $dict_array[@dictcode].add_rels(@entry_new, false)
      @prev = $dict_array[@dictcode].history_prev(@change)
      @next = $dict_array[@dictcode].history_next(@change)
      slim :historycompare
    end

    get '/import' do
      @dict_info = $dict_info
      slim :adminimport1
    end

    post '/importupload' do
      $stdout.puts params
      $stdout.puts params['data1']
      dir = Dir::mktmpdir('czj','/tmp')
      $dict_array['czj'].handle_upload(params['data1'], dir)
      $dict_array['czj'].handle_upload(params['data2'], dir)
      $dict_array['czj'].handle_upload(params['data3'], dir)
      redirect to('/import2?dir=' + dir)
    end

    post '/importwupload' do
      logid = Array.new(8) { (Array('a'..'z')+Array('0'..'9')).sample }.join
      targetdict = $dict_array[params['srcdict']]
      Thread.new{ targetdict.handle_upload_write(params['data'], @user_info['login'], logid) }
      redirect to('/importlog?logid=' + logid)
    end

    get '/import2' do
      @dict_info = $dict_info
      @dir = params['dir']
      @importfiles, @gotmeta = $dict_array['czj'].get_import_files(@dir)
      slim :adminimport2
    end

    post '/importstart2' do
      $stdout.puts params['data']
      content_type :json
      if not $dict_info[params['data']['srcdict']].nil?
        logid = Array.new(8) { (Array('a'..'z')+Array('0'..'9')).sample }.join
        if params['data']['targetdict'] == '-'
          targetdict = nil
        else
          targetdict = $dict_array[params['data']['targetdict']]
        end
        Thread.new{ $dict_array[params['data']['srcdict']].import_run(params['data'], targetdict, params['data']['not_createrel'], @user_info['login'], logid) }
        {'logid'=>logid}.to_json
      else
        {'error'=>'no dict info'}.to_json
      end
    end

    get '/importlog' do
      @dict_info = $dict_info
      logname = 'logs/czjimport' + params['logid'] + '.log'
      @progress = IO.readlines(logname).join("\n")
      slim :adminimportlog
    end
  end

  get '/swapi/symbol_definition/:id.json' do
    data = $mongo['symbol'].find({'id'=>params['id']}).first
    if params['callback'].to_s == ''
      content_type :json
      data.to_json
    else
      params['callback'] + '(' + data.to_json.to_s + ')'
    end
  end

  get '/swapi/symbol_table/sg.:sg.bs.:bs.json' do
    data = {}
    if params['bs'].to_s == '0'
      $mongo['symbol'].find({'id'=>params['sg']}).each{|sy|
        data[sy['id']] = sy
        data[sy['id']]['sid'] = sy['id']
      }
    else
      $mongo['symbol'].find({'id'=>params['bs']}).each{|sy|
        data[sy['id']] = sy
        data[sy['id']]['sid'] = sy['id']
      }
    end
    $mongo['symbol'].find({'sg'=>params['sg'], 'bs'=>params['bs']}).each{|sy|
      data[sy['id']] = sy
    }
    if params['callback'].to_s == ''
      content_type :json
      data.to_json
    else
      params['callback'] + '(' + data.to_json.to_s + ')'
    end
  end

  get '/korpus' do
    apikey = $ske_api
    newurl = 'https://api.sketchengine.eu/bonito/run.cgi/first?corpname=preloaded%2Fcstenten19_mj2&iquery='+params['lemma']+'&queryselector=iqueryrow&default_attr=word&fc_lemword_window_type=both&fc_lemword_wsize=5&gdex_enabled=1&viewmode=sentence&refs==doc.url&pagesize=50&format=json';
    $stdout.puts 'PROXY '+ newurl
    require 'net/http'
    require 'net/https'
    require 'openssl'
    uri = URI(newurl)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri, {'Authorization'=>'Bearer '+apikey})
    response = http.request(request)
    content_type :json
    response.body
  end

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
