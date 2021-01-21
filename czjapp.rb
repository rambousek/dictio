#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json'
require 'bson'
require 'open-uri'
require 'i18n'
require 'i18n/backend/fallbacks'

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
        return (user == res['login'] and pass.crypt(res['password'][0,2]) == res['password'])
      end
      return false
    end
  end


  before do
    if params['lang'].to_s != "" and I18n.available_locales.map(&:to_s).include?(params["lang"]) and params['lang'] != session[:locale]
      session[:locale] = 'cs' if session[:locale].to_s == ""
      session[:locale] = params['lang']
    end
    @selectlang = session[:locale]
    @selectlang = 'cs' if @selectlang.nil?
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
    @target = 'czj'
    @dictcode = 'cs'
    stat = $mongo['entryStat'].find({}, :sort=>{'dateField'=>-1}).first
    @count_entry = stat['entries'][0]['count']
    @count_rels = ((stat['rel'][0]['count'].to_i+stat['usgrel'][0]['count'].to_i)/2).round
    slim :home
  end

  get '/about' do
    @dict_info = $dict_info
    @search_params = {}
    @target = 'czj'
    @dictcode = 'cs'
    @selected_page = 'about'
    page = 'about-'+I18n.locale.to_s
    slim page.to_sym
  end

  get '/help' do
    @dict_info = $dict_info
    @search_params = {}
    @target = 'czj'
    @dictcode = 'cs'
    @selected_page = 'help'
    page = 'help-'+I18n.locale.to_s
    slim page.to_sym
  end

  get '/contact' do
    @dict_info = $dict_info
    @search_params = {}
    @target = 'czj'
    @dictcode = 'cs'
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
      @entry = dict.getdoc(params['id'])
      @search_params = {}
      @search_type = 'search'
      @target = ''
      @title = dict_info[code]['label'] + ' ' + params['id']
      slim :fullentry 
    end
    get '/'+code+'/json/:id' do 
      content_type :json
      body = dict.getdoc(params['id']).to_json
    end
    get '/'+code+'/jsonsearch/:type/:search(/:start)?(/:limit)?' do 
      content_type :json
      more_params = {}
      if params['slovni_druh'].to_s != ''
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
  }

end
