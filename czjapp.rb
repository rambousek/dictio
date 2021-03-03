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

require_relative 'lib/czj'
require_relative 'lib/host-config'
require_relative 'lib/dict-config'

class CzjApp < Sinatra::Base
  $mongo = Mongo::Client.new([$mongoHost], :database => 'dictio')
  
  configure do
    set :bind, '0.0.0.0'
    set :server, :puma
    set :strict_paths, false
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

  dict_array = {}

  @user_info = nil

  helpers do
    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="CZJ"'
      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      if @auth.provided? and @auth.basic? and @auth.credentials
        user = @auth.credentials.first
        pass = @auth.credentials[1]
        res = $mongo['users'].find({'login':user}).first
        return false if res.nil?
        if user == res['login'] and pass.crypt(res['password'][0,2]) == res['password']
          @user_info = {'login'=>res['login'], 'name'=>res['name'], 'email'=>res['email'], 'skupina'=>res['skupina'], 'copy'=>res['copy'], 'autor'=>res['autor'], 'zdroj'=>res['zdroj'], 'perm'=>[], 'admin'=>res['admin'], 'editor'=>res['editor'], 'revizor'=>res['revizor']}
          res['editor'].each{|e| @user_info['perm'] << 'editor_'+e}
          res['revizor'].each{|e| @user_info['perm'] << 'revizor_'+e}
          @user_info['perm'] = ['admin'] if res['admin']
          return true
        end
      end
      return false
    end

    def get_hostname(ip)
      begin
        name = Resolv.getname(ip)
      rescue
        name = ip.to_s
      end
      return name
    end

    def lang_defaults
      hostname = get_hostname(request.get_header('HTTP_X_FORWARDED_FOR'))
      case
      when hostname.end_with?('.cz'), hostname =~ /^[0-9\.]*$/
        default_locale = 'cs'
        default_dict = 'cs'
        default_target = 'czj'
      when hostname.end_with?('.sk')
        default_locale = 'sk'
        default_dict = 'sj'
        default_target = 'spj'
      when hostname.end_with?('.at'), hostname.end_with?('.de')
        default_locale = 'de'
        default_dict = 'de'
        default_target = 'ogs'
      else
        default_locale = 'en'
        default_dict = 'en'
        default_target = 'is'
      end
      return default_locale, default_dict, default_target
    end
  end


  before do
    if params['lang'].to_s != "" and I18n.available_locales.map(&:to_s).include?(params["lang"]) and params['lang'] != session[:locale]
      session[:locale] = 'cs' if session[:locale].to_s == ""
      session[:locale] = params['lang']
    end
    @selectlang = session[:locale]
    @hostname = get_hostname(request.get_header('HTTP_X_FORWARDED_FOR'))
    default_locale, @default_dict, @default_target = lang_defaults
    @selectlang = default_locale if @selectlang.nil?
    I18n.locale = @selectlang
    @langpath = request.fullpath.gsub(/lang=[a-z]*/,'').gsub(/&&*/,'&')
    @langpath += '?' unless @langpath.include?('?')
    @search_limit = 10
    @translate_limit = 9
    @is_edit = $is_edit
    protected! if $is_edit
  end

  get '/' do
    @dict_info = $dict_info
    @search_params = {}
    @target = @default_target
    @dictcode = @default_dict
    stat = $mongo['entryStat'].find({}, :sort=>{'dateField'=>-1}).first
    @count_entry = stat['entries'][0]['count']
    @count_rels = ((stat['rel'][0]['count'].to_i+stat['usgrel'][0]['count'].to_i)/2).round
    slim :home
  end

  get '/about' do
    @dict_info = $dict_info
    @search_params = {}
    @target = @default_target
    @dictcode = @default_dict
    @selected_page = 'about'
    page = 'about-'+I18n.locale.to_s
    slim page.to_sym
  end

  get '/help' do
    @dict_info = $dict_info
    @search_params = {}
    @target = @default_target
    @dictcode = @default_dict
    @selected_page = 'help'
    page = 'help-'+I18n.locale.to_s
    slim page.to_sym
  end

  get '/helpsign' do
    @dict_info = $dict_info
    @search_params = {}
    @target = @default_target
    @dictcode = @default_dict
    @selected_page = 'help'
    page = 'helpsign-'+I18n.locale.to_s
    slim page.to_sym
  end

  get '/contact' do
    @dict_info = $dict_info
    @search_params = {}
    @target = @default_target
    @dictcode = @default_dict
    @selected_page = 'contact'
    page = 'contact-'+I18n.locale.to_s
    slim page.to_sym
  end

  (write_dicts+sign_dicts).each{|code|
  	$stderr.puts code
    dict = CZJDict.new(code)
    dict.write_dicts = write_dicts
    dict.sign_dicts = sign_dicts
    dict.dict_info = $dict_info
    dict_array[code] = dict
 
    get '/'+code do
      redirect to('/')
    end
    get '/'+code+'/show/:id' do
      @dict_info = $dict_info
      @dictcode = code
      @show_dictcode = code
      @search_params = {}
      @search_type = 'search'
      @target = ''
      @entry = dict.getdoc(params['id'])
      if @entry != {}
        @title = $dict_info[code]['label'] + ' ' + params['id']
        slim :fullentry 
      else
        slim :notfound
      end
    end
    get '/'+code+'/json/:id' do 
      content_type :json
      doc = dict.getdoc(params['id'])
      if $is_edit
        doc['user_info'] = @user_info
      end
      body = doc.to_json
    end
    get '/'+code+'/jsonsearch/:type/:search(/:start)?(/:limit)?' do 
      content_type :json
      more_params = {}
      if params['slovni_druh'].to_s != '' and params['slovni_druh'].to_s != 'undefined'
        more_params['slovni_druh'] = params['slovni_druh']
      end
      body = dict.search(code, params['search'].to_s.strip, params['type'].to_s, params['start'].to_i, params['limit'].to_i, more_params).to_json
    end
    get '/'+code+'/jsontranslate/:target/:type/:search(/:start)?(/:limit)?' do 
      content_type :json
      body = dict.translate2(code, params['target'], params['search'].to_s.strip, params['type'].to_s, params['start'].to_i, params['limit'].to_i).to_json
    end
    get '/'+code+'/search/:type/:search(/:selected)?' do
      @dict_info = $dict_info
      @request = request
      @search_path = '/'+code+'/search/'+params['type']+'/'+params['search']
      more_params = {}
      url_pars = []
      if params['slovni_druh'].to_s != ''
        url_pars << 'slovni_druh='+params['slovni_druh']
        more_params['slovni_druh'] = params['slovni_druh']
      end
      @url_params = url_pars.join('&')
      @result = dict.search(code, params['search'].to_s.strip, params['type'].to_s, 0, @search_limit, more_params)
      $stderr.puts(@result['count'])
      @entry = nil
      if params['selected'] != nil
        @entry = dict.getdoc(params['selected']) 
      elsif @result['entries'].first != nil
        @entry = dict.getdoc(@result['entries'].first['id'])
      end
      @search_type = 'search'
      @search = ''
      @search = params['search'] if params['search'] != '_'
      @input_type = params['type']
      @search_params = more_params
      @dictcode = code
      @target = 'czj'
      
      slim :searchresult
    end
    get '/'+code+'/translate/:target/:type/:search(/:selected)?' do
      @dict_info = $dict_info
      @request = request
      @target = params['target']
      selected = params['selected']
      @tran_path = '/'+code+'/translate/'+params['target']+'/'+params['type']+'/'+params['search']
      url_pars = []
      @url_params = url_pars.join('&')
      @search_type = 'translate'
      @search = params['search']
      @input_type = params['type']
      @dictcode = code
      if selected.nil?
        @result = dict.translate2(code, params['target'], params['search'].to_s.strip, params['type'].to_s, 0, @translate_limit)
        slim :transresult
      else
        if selected.include?('-')
          @show_target = code
          sela = selected.split('-')
          @show_dictcode = sela[0]
          @entry = dict_array[sela[0]].getdoc(sela[1])
        else
          @show_target = @target
          @show_dictcode = @dictcode
          @entry = dict.getdoc(selected)
        end
        slim :fullentry 
      end
    end
    get '/'+code+'/translatelist/:target/:type/:search(/:start)?(/:limit)?' do
      @dict_info = $dict_info
      @request = request
      @target = params['target']
      selected = params['selected']
      @tran_path = '/'+code+'/translate/'+params['target']+'/'+params['type']+'/'+params['search']
      url_pars = []
      @url_params = url_pars.join('&')
      @search_type = 'translate'
      @search = params['search']
      @input_type = params['type']
      @dictcode = code
      @result = dict.translate2(code, params['target'], params['search'].to_s.strip, params['type'].to_s, params['start'].to_i, params['limit'].to_i)
      slim :transresultlist, :layout=>false
    end
    if $is_edit
      get '/'+code+'/newentry' do
        newid = dict.get_new_id
        doc = {'user_info' => @user_info, 'newid' => newid}
        content_type :json
        body = doc.to_json
      end
      get '/'+code+'/comments/:id(/:type)?' do
        content_type :json
        body = dict.get_comments(params['id'], params['type'].to_s).to_json
      end
      post '/'+code+'/save' do
        data = JSON.parse(params['data'])
        dict.save_doc(data)
        content_type :json
        body = '{"success":true,"msg":"Uloženo"}'
      end
      post '/'+code+'/delete/:id' do
        if params['id'].to_s != ''
          if @user_info['editor'].length > 0 or @user_info['revizor'].length > 0 or @user_info['perm'].include?('admin')
            dict.remove_all_relations(params['id'].to_s)
            dict.remove_colloc(params['id'].to_s)
            dict.delete_doc(params['id'].to_s)
            body = 'DELETED ' + params['id'].to_s
          else
            body = 'not authorized to delete entry'
          end
        end
      end
      post '/'+code+'/add_comment' do
        user = ''
        if params['box'] != '' and params['entry'] != '' and params['type'] != ''
          dict.comment_add(@user_info['login'], params['entry'], params['box'], params['text'])
        end
        content_type :json
        body = '{"success":true,"msg":"Uloženo"}'
      end
      get '/'+code+'/del_comment/:cid' do
        if params['cid'] != ''
          dict.comment_del(params['cid'])
        end
        content_type :json
        body = '{"success":true,"msg":"Uloženo"}'
      end
      get '/'+code+'/filelist/:id' do
        list = dict.get_entry_files(params['id'])
        if params['search'].to_s != ''
          list = dict.find_files(params['search'].to_s, params['type'].to_s)
        end
        content_type :json
        body = list.to_json
      end
      get '/'+code+'/relfind' do
        data = dict.find_relation(params['search'].to_s)
        content_type :json
        body = data.to_json
      end
      get '/'+code+'/linkfind' do
        data = dict.find_link(params['search'].to_s)
        content_type :json
        body = data.to_json
      end
      get '/'+code+'/getfsw' do
        fsw = dict.getfsw(params['sw'].to_s)
        body = fsw
      end
      get '/'+code+'/fromfsw' do
        sw = dict.fromfsw(params['fsw'].to_s)
        body = sw
      end
      get '/'+code+'/relationinfo' do
        info = dict.get_relation_info(params['meaning_id'].to_s)
        body = info
      end
      get '/'+code+'/getrelations' do
        list = dict.get_relations(params['meaning_id'].to_s, params['type'].to_s)
        content_type :json
        body = list.to_json
      end
      post '/'+code+'/upload' do
        $stderr.puts params
        $stderr.puts JSON.parse(params['metadata'])
        content_type :json
        body = {'success'=>false, 'message'=>"Chyba při uploadu"}.to_json
        if not params['filedata'].nil?
          filename, mediaid = dict.save_uploaded_file(params['filedata'], JSON.parse(params['metadata'].to_s), params['entryid'].to_s)
          body = {'success'=>true, 'message'=>"Soubor nahrán: #{filename} (#{mediaid})", 'mediaid'=>mediaid}.to_json
        end
      end
      get '/'+code+'/getgram/:id' do
        content_type :json
        body = dict.get_gram(params['id']).to_json
      end
    end
  }

  get '/swapi/symbol_definition/:id.json' do
    data = $mongo['symbol'].find({'id'=>params['id']}).first
    body = params['callback'] + '(' + data.to_json.to_s + ')'
  end

  get '/swapi/symbol_table/sg.:sg.bs.:bs.json' do
    data = {}
    $mongo['symbol'].find({'sg'=>params['sg'], 'bs'=>params['bs']}).each{|sy|
      data[sy['id']] = sy
    }
    body = params['callback'] + '(' + data.to_json.to_s + ')'
  end

end
