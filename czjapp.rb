#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json'
require 'bson'
require 'open-uri'
require 'i18n'
require 'i18n/backend/fallbacks'

require_relative 'lib/dict/czj'

class CzjApp < Sinatra::Base
  $mongo = Mongo::Client.new([ '192.168.0.156:27017' ], :database => 'dictio')
  
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
  
  dict_info = {
    'cs' => {'type' => 'write', 'label'=>'Czech'},
    'en' => {'type' => 'write', 'label'=>'English'},
    'sj' => {'type' => 'write', 'label'=>'Slovak'},
    'de' => {'type' => 'write', 'label'=>'German'},
    'czj' => {'type' => 'sign', 'label'=>'ČZJ', 'search_in'=>'cs'},
    'spj' => {'type' => 'sign', 'label'=>'SPJ', 'search_in'=>'sj'},
    'asl' => {'type' => 'sign', 'label'=>'ASL', 'search_in'=>'en'},
    'is' => {'type' => 'sign', 'label'=>'IS', 'search_in'=>'en'},
    'ogs' => {'type' => 'sign', 'label'=>'OGS', 'search_in'=>'de'},
  }
  #write_dicts = ['en','cs','de','sj']
  #sign_dicts = ['czj','ogs','spj','asl','is']
  write_dicts = []
  sign_dicts = []
  dict_info.each{|code,info|
    if info['type'] == 'write'
      write_dicts << code
    else
      sign_dicts << code
    end
  }

  dict_array = {}

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
  end

  get '/' do
    @dict_info = dict_info
    @search_params = {}
    @target = 'czj'
    @dictcode = 'cs'
    stat = $mongo['entryStat'].find({}, :sort=>{'dateField'=>-1}).first
    @count_entry = stat['entries'][0]['count']
    @count_rels = ((stat['rel'][0]['count'].to_i+stat['usgrel'][0]['count'].to_i)/2).round
    slim :home
  end

  get '/about' do
    @dict_info = dict_info
    @search_params = {}
    @target = 'czj'
    @dictcode = 'cs'
    @selected_page = 'about'
    page = 'about-'+I18n.locale.to_s
    slim page.to_sym
  end

  (write_dicts+sign_dicts).each{|code|
  	$stderr.puts code
    dict = CZJDict.new(code)
    dict.write_dicts = write_dicts
    dict.sign_dicts = sign_dicts
    dict.dict_info = dict_info
    dict_array[code] = dict
 
    get '/proxy/:dir/:video' do
      content_type 'video/mp4'
      if File.exist?('public/'+params['dir']+'/'+params['video'])
        redirect '/'+params['dir']+'/'+params['video']
      else
        url = 'http://www.dictio.info/media/'+params['dir']+'/'+params['video']
        open(url) do |content|
          content.read
        end
      end
    end
    get '/'+code do
      redirect to('/')
    end
    get '/'+code+'/show/:id' do
      @dict_info = dict_info
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
    get '/'+code+'/jsonsearch/:type/:search' do 
      content_type :json
      body = dict.search(code, params['search'].to_s.strip, params['type'].to_s, params).to_json
    end
    get '/'+code+'/jsontranslate/:target/:type/:search' do 
      content_type :json
      body = dict.translate(code, params['target'], params['search'].to_s.strip, params['type'].to_s, params).to_json
    end
    get '/'+code+'/search/:type/:search(/:selected)?' do
      @dict_info = dict_info
      @request = request
      @search_path = '/'+code+'/search/'+params['type']+'/'+params['search']
      more_params = {}
      url_pars = []
      @url_params = url_pars.join('&')
      @result = dict.search(code, params['search'].to_s.strip, params['type'].to_s, more_params)
      @entry = nil
      if params['selected'] != nil
        @entry = dict.getdoc(params['selected']) #@result.select{|re| re['id'] == params['selected']}.first
      elsif @result.first != nil
        @entry = dict.getdoc(@result.first['id'])
      end
      @search_type = 'search'
      @search = params['search']
      @input_type = params['type']
      @search_params = more_params
      @dictcode = code
      @target = 'czj'
      
      slim :searchresult
    end
    get '/'+code+'/translate/:target/:type/:search(/:selected)?' do
      @dict_info = dict_info
      @request = request
      @target = params['target']
      selected = params['selected']
      @tran_path = '/'+code+'/translate/'+params['target']+'/'+params['type']+'/'+params['search']
      more_params = {}
      url_pars = []
      @url_params = url_pars.join('&')
      @search_type = 'translate'
      @search = params['search']
      @search_params = more_params
      @dictcode = code
      if selected.nil?
        @result = dict.translate(code, params['target'], params['search'].to_s.strip, params['type'].to_s, more_params)
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
  }

end
