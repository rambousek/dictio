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
require_relative 'lib/host-config'
require_relative 'lib/dict-config'
require_relative 'lib/czj_fsw'
require_relative 'lib/czj_comment'
require_relative 'lib/czj_report'
require_relative 'lib/czj_web_helper'
require_relative 'lib/czj_admin'
require_relative 'lib/czj_admin_info'
require_relative 'lib/czj_admin_duplicate'

class CzjApp < Sinatra::Base
  $mongo = Mongo::Client.new($mongoHost)
  $georeader = MaxMind::GeoIP2::Reader.new(
    database: '/usr/share/GeoIP/GeoLite2-Country.mmdb'
  )
  
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
  $dict_array = {}
  comments = CzjComment.new
  comments.sign_dicts = sign_dicts
  reports = CzjReport.new
  reports.sign_dicts = sign_dicts
  admin_dict = CzjAdmin.new

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
    cookies.set(:dictio_pref, {:httponly=>false, :value=>(write_dicts+sign_dicts).map{|i| 'dict-'+i+'=true'}.join(';')})
    @is_edit = $is_edit
    @is_admin = $is_admin
    @is_test = $is_test
  end

  get '/' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    stat = $mongo['entryStat'].find({}, :sort=>{'dateField'=>-1}).first
    @count_entry = stat['entries'][0]['count']
    @count_rels = ((stat['rel'][0]['count'].to_i+stat['usgrel'][0]['count'].to_i)/2).round
    @params = params
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, 'index')
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim :home
  end

  get '/about' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'about'
    page = 'about-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/help' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'help'
    page = 'help-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/helpsign' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'help'
    page = 'helpsign-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/contact' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'contact'
    page = 'contact-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end
  
  get '/admin' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'admin'
    @lemma_counts = admin_dict.info_count.get_count_entry
    @duplicate = CzjAdminDuplicate.get_duplicate_counts
    @notrans_count = admin_dict.info_count.get_count_relation_notrans
    page = 'admin'
    slim page.to_sym
  end

  (write_dicts+sign_dicts).each{|code|
  	$stdout.puts code
    dict = CZJDict.new(code)
    dict.write_dicts = write_dicts
    dict.sign_dicts = sign_dicts
    dict.dict_info = $dict_info
    dict.comments = comments
    $dict_array[code] = dict
 
    get '/'+code do
      redirect to('/')
    end
    get '/'+code+'/show/:id' do
      $stderr.puts params
      $stderr.puts request
      $stderr.puts request.path_info
      @dict_info = $dict_info
      @dictcode = code
      @show_dictcode = code
      @search_params = {}
      @search_type = 'show'
      @target = ''
      @entry = dict.getdoc(params['id'], false)
      if @entry != {}
        @title = $dict_info[code]['label'] + ' ' + params['id']
        @cite_attr = CzjWebHelper.get_cite_attr('show', request.path_info, nil, $dict_info, @entry, @dictcode)
        @cite_text = CzjWebHelper.build_cite(@cite_attr)
        slim :fullentry
      else
        slim :notfound
      end
    end
    get '/'+code+'/show/:id/:video' do
      @dict_info = $dict_info
      @dictcode = code
      @show_dictcode = code
      @search_params = {}
      @search_type = 'show'
      @target = ''
      @entry = dict.getdoc(params['id'], false)
      if @entry != {}
        @title = $dict_info[code]['label'] + ' ' + params['id']
        @video = params['video']
        @cite_attr = CzjWebHelper.get_cite_attr('video', request.path_info, nil, $dict_info, @entry, @dictcode, nil, nil, @video)
        @cite_text = CzjWebHelper.build_cite(@cite_attr)
        slim :showvideo
      else
        slim :notfound
      end
    end
    get '/'+code+'/json/:id' do 
      content_type :json
      $stdout.puts 'START json'+Time.now.to_s
      add_rev = false
      add_rev = true if params['add_rev'] == 'true'
      if params['history'].to_s != '' and params['historytype'].to_s != ''
        change = $dict_array['czj'].get_history(params['history'])
        if params['historytype'].to_s == 'old'
          if change['full_entry_old']
            doc = change['full_entry_old']
          else
            doc = nil
          end
        else
          doc = change['full_entry']
        end
        doc = $dict_array[code].full_entry(doc, false)
        doc = $dict_array[code].add_rels(doc, false)
      else
        doc = dict.getdoc(params['id'], add_rev)
      end
      if $is_edit
        doc['user_info'] = @user_info
        doc['user_list'] = $dict_array[code].get_users.
          select{|x| x['lang'].nil? or x['lang'].length == 0 or x['lang'].include?(code)}.
          collect{|x| [x['login']]}
      end
      $stdout.puts 'END json'+Time.now.to_s
      body = doc.to_json
    end
    get '/'+code+'/jsonsearch/:type/:search(/:start)?(/:limit)?' do 
      content_type :json
      more_params = {}
      %w[slovni_druh stylpriznak oblast].each{|parname|
        if params[parname].to_s != '' and params[parname].to_s != 'undefined'
          more_params[parname] = params[parname]
        end
      }
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
      %w[slovni_druh stylpriznak oblast].each{|parname|
        if params[parname].to_s != ''
          url_pars << parname + '=' + params[parname]
          more_params[parname] = params[parname]
        end
      }
      @url_params = url_pars.join('&')
      @result = dict.search(code, params['search'].to_s.strip, params['type'].to_s, 0, @search_limit, more_params)
      $stdout.puts(@result['count'])
      if @result['count'] == 0
        File.open("public/log/search.csv", "a"){|f| f << [code, params['search'].to_s, Time.now.strftime("%Y-%m-%d %H:%M:%S")].join(";")+"\n"}
      end
      @entry = nil
      @cite_attr = CzjWebHelper.get_cite_attr('search', request.path_info, nil, $dict_info, nil, code, nil, params['search'])
      if params['selected'] != nil
        @entry = dict.getdoc(params['selected'])
        @cite_attr = CzjWebHelper.get_cite_attr('search', request.path_info, nil, $dict_info, @entry, code)
      end
      @cite_text = CzjWebHelper.build_cite(@cite_attr)
      @search_type = 'search'
      @search = ''
      @search = params['search'] if params['search'] != '_'
      @input_type = params['type']
      @search_params = more_params
      @dictcode = code
      @target = 'czj'
      
      slim :searchresult
    end
    get '/'+code+'/searchentry/:entry' do
      @dictcode = code
      @entry = dict.getdoc(params['entry'], false)
      @search_type = 'search'
      if @entry != nil and @entry != {}
        @cite_attr = CzjWebHelper.get_cite_attr('search', request.path_info, nil, $dict_info, @entry, @dictcode)
        @cite_text = CzjWebHelper.build_cite(@cite_attr)
        @add_cite = true
        slim :entry, :layout=>false
      else
        return ''
      end
    end
    get '/'+code+'/translate/:target/:type/:search(/:selected)?' do
      @dict_info = $dict_info
      @request = request
      @target = params['target']
      selected = params['selected']
      @tran_path = '/'+code+'/translate/'+params['target']+'/'+params['type']+'/'+params['search']
      url_pars = []
      @search_params = {}
      %w[slovni_druh stylpriznak oblast].each{|parname|
        if params[parname].to_s != ''
          url_pars << parname + '=' + params[parname]
          @search_params[parname] = params[parname]
        end
      }
      @url_params = url_pars.join('&')
      @search_type = 'translate'
      @search = ''
      @search = params['search'] if params['search'] != '_'
      @input_type = params['type']
      @dictcode = code
      @entry = nil
      if selected != nil
        if selected.include?('-')
          @show_target = code
          sela = selected.split('-')
          @show_dictcode = sela[0]
          @entry = $dict_array[sela[0]].getdoc(sela[1], false)
        else
          @show_target = @target
          @show_dictcode = @dictcode
          @entry = dict.getdoc(selected, false)
        end
      end
      if @entry != nil and @entry != {}
        @cite_attr = CzjWebHelper.get_cite_attr('translate', request.path_info, nil, $dict_info, @entry, @dictcode, @target)
        @cite_text = CzjWebHelper.build_cite(@cite_attr)
        slim :fullentry
      else
        @cite_attr = CzjWebHelper.get_cite_attr('translate', request.path_info, nil, nil, nil, @dictcode, @target, params['search'].to_s.strip)
        @cite_text = CzjWebHelper.build_cite(@cite_attr)
        #@result = dict.translate2(code, params['target'], params['search'].to_s.strip, params['type'].to_s, 0, @translate_limit)
        @result = {'relations'=>[], 'initial'=>true}
        slim :transresult
      end
    end
    get '/'+code+'/translatelist/:target/:type/:search(/:start)?(/:limit)?' do
      @dict_info = $dict_info
      @request = request
      @target = params['target']
      selected = params['selected']
      @tran_path = '/'+code+'/translate/'+params['target']+'/'+params['type']+'/'+params['search']
      more_params = {}
      url_pars = []
      %w[slovni_druh stylpriznak oblast].each{|parname|
        if params[parname].to_s != ''
          url_pars << parname + '=' + params[parname]
          more_params[parname] = params[parname]
        end
      }
      @url_params = url_pars.join('&')
      @search_type = 'translate'
      @search = ''
      @search = params['search'].strip if params['search'] != '_'
      @input_type = params['type']
      @dictcode = code
      @search_params = more_params
      @resultinfo1 = false
      @resultinfo2 = false
      @resultinfo3 = false
      puts "DEBUG: Calling translate2 with search term: #{@search}"              
      
      def find_closest_match(search, possible_matches, max_distance)
        filtered_matches = possible_matches.select do |term|
          DamerauLevenshtein.distance(search, term) <= max_distance
        end
        filtered_matches.min_by { |term| DamerauLevenshtein.distance(search, term) }
      end
      
      def process_multisyllabic_search(words_array, possible_matches, dict, code, params)
        words_array.shift if words_array.first.length <= 2
        while words_array.size > 0
          closest_match = find_closest_match(words_array.first, possible_matches, 2)
          if closest_match
            @resultinfo3 = true
            @search = closest_match
            return dict.translate2(code, params['target'], closest_match, params['type'], params['start'].to_i, params['limit'].to_i)            
          else
            words_array.shift
          end
        end
        return nil
      end
      
      def process_single_word_search(search, possible_matches, dict, code, params)
        search.slice!(0, 2) if search.start_with?("ne") && (code == "cs" || code == "sk") &&  search.length > 4
        @resultinfo1 = true
        while search.length > 1
          closest_match = find_closest_match(search, possible_matches, 2)
          if closest_match
            @resultinfo2 = true if not @resultinfo1
            @search = closest_match
            return dict.translate2(code, params['target'], closest_match, params['type'], params['start'].to_i, params['limit'].to_i) 
          else
            if search.length >= 10
              search = search[0, [search.length / 2, 1].max]
            else
              search.slice!(-2, 2)
            end
            @resultinfo1 = false if @resultinfo1
          end
        end
        return nil
      end
      
      @result = dict.translate2(code, params['target'], @search, params['type'], params['start'].to_i, params['limit'].to_i, more_params)
      if @result['count'] == 0 and @search != ''
        # Logování neúspěšného vyhledávání
        File.open("public/log/translate.csv", "a"){|f| f << [code, params['target'],  params['search'].to_s, Time.now.strftime("%Y-%m-%d %H:%M:%S")].join(";")+"\n"}
      
        @search0 = @search
        #načtení všech existujících překladů
        possible_matches = dict.wordlist[params['target']]
        possible_matches.delete(@search)
        @search = @search.downcase
      
        words_array = @search.split.reject(&:empty?)
        result_similar = nil
        if words_array.size > 1
          result_similar = process_multisyllabic_search(words_array, possible_matches, dict, code, params)
        else
          result_similar = process_single_word_search(@search, possible_matches, dict, code, params)
        end
        if result_similar
          @result = result_similar
        end
      end
      #výpis výsledků hledání
      slim :transresultlist, layout: false
    end

    get '/'+code+'/revcolloc/:id' do
      @entry = dict.get_revcolloc(params['id'], 'collocation')
      @type = 'collocation'
      if $dict_info[code]['type'] == 'write'
        slim :revcollocwrite, :layout=>false
      else
        slim :revcollocsign, :layout=>false
      end
    end
    get '/'+code+'/revderivat/:id' do
      @entry = dict.get_revcolloc(params['id'], 'derivat')
      @type = 'derivat'
      if $dict_info[code]['type'] == 'write'
        slim :revcollocwrite, :layout=>false
      else
        slim :revcollocsign, :layout=>false
      end
    end
    get '/'+code+'/revkompozitum/:id' do
      @entry = dict.get_revcolloc(params['id'], 'kompozitum')
      @type = 'kompozitum'
      if $dict_info[code]['type'] == 'write'
        slim :revcollocwrite, :layout=>false
      else
        slim :revcollocsign, :layout=>false
      end
    end
    get '/'+code+'/cache_all_sw' do
      purge = false
      purge = true if params['purge'] == '1'
      count = dict.sw.cache_all_sw(purge)
      content_type :json
      body = {'count': count}.to_json
    end
    get '/'+code+'/cache_all_rel' do
      purge = false
      purge = true if params['purge'] == '1'
      count = dict.cache_all_relations(purge)
      content_type :json
      body = {'count': count}.to_json
    end
    get '/'+code+'/cache_rel_entry/:id' do
      count = dict.cache_relations_entry(code, params['id'])
      content_type :json
      body = {'count': count}.to_json
    end
    get '/'+code+'/normalize_fsw' do
      count = dict.sw.normalize_fsw
      body = {'count': count}.to_json
    end


    if $is_edit
      set (:dict_allowed) {|value| condition { @user_info['admin'] or ((@user_info['revizor'] != [] or (@user_info['editor'] != [] and @user_info['editor'] != ['komparator'])) and (@user_info['dict_allowed'].nil? or @user_info['dict_allowed'] == [] or @user_info['dict_allowed'].include?(value))) } }

      get '/'+code+'/newentry' do
        newid = dict.get_new_id
        doc = {'user_info' => @user_info, 'newid' => newid}
        content_type :json
        body = doc.to_json
      end
      get '/'+code+'/comments/:id(/:type)?' do
        content_type :json
        body = comments.get_comments(code, params['id'], params['type'].to_s).to_json
      end
      post '/'+code+'/save' do
        data = JSON.parse(params['data'])
        dict.save_doc(data, @user_info['login'])
        content_type :json
        body = {"success"=>true,"msg"=>"Uloženo"}.to_json
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
      post '/'+code+'/update_video' do
        data = JSON.parse(params['data'])
        if data['update_video']
          data['update_video'].each{|uv|
            dict.edit_media.save_media(uv)
          }
        end
        content_type :json
        body = {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      post '/'+code+'/remove_video' do
        content_type :json
        if params['entry_id'].to_s != '' and params['media_id'].to_s != ''
          dict.edit_media.remove_video(params['entry_id'].to_s, params['media_id'].to_s)
          body = {"success"=>true, "message"=>"Soubor odebrán"}.to_json
        else
          body = {'success'=>false, 'message'=>"Chybí parametry videa"}.to_json
        end
      end
      get '/'+code+'/del_comment/:cid' do
        if params['cid'] != ''
          comments.comment_del(params['cid'])
        end
        content_type :json
        body = {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      get '/'+code+'/filelist/:id' do
        list = dict.edit_media.get_entry_files(params['id'], params['type'].to_s)
        if params['search'].to_s != ''
          list = dict.edit_media.find_files(params['search'].to_s, params['type'].to_s)
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
        fsw = CzjFsw.getfsw(params['sw'].to_s)
        body = fsw
      end
      get '/'+code+'/fromfsw' do
        sw = CzjFsw.fromfsw(params['fsw'].to_s)
        body = sw
      end
      get '/'+code+'/relationinfo' do
        info = dict.get_relation_info(params['meaning_id'].to_s)
        body = info
      end
      get '/'+code+'/getrelations' do
        list = dict.get_relations(params['meaning_id'].to_s, params['type'].to_s, @user_info)
        content_type :json
        body = list.to_json
      end
      post '/'+code+'/upload' do
        $stdout.puts params
        $stdout.puts JSON.parse(params['metadata'])
        body = {'success'=>false, 'message'=>"Chyba při uploadu"}.to_json
        metadata = JSON.parse(params['metadata'].to_s)
        if not params['filedata'].nil? and params['filedata'] != 'undefined'
          filename, mediaid = dict.edit_media.save_uploaded_file(params['filedata'], metadata, params['entryid'].to_s)
          body = {'success'=>true, 'message'=>"Soubor nahrán: #{filename} (#{mediaid})", 'mediaid'=>mediaid, 'filename'=>filename}.to_json
        end
        if (params['filedata'].nil? or params['filedata'] == 'undefined') and metadata['location'].to_s != ''
          dict.edit_media.attach_file(metadata['location'].to_s, params['entryid'].to_s, metadata)
          body = {'success'=>true, 'message'=>"Soubor připojen: #{metadata['@location']}"}.to_json
        end
        content_type :json
        body
      end
      get '/'+code+'/getgram/:id' do
        content_type :json
        body = dict.get_gram(params['id']).to_json
      end
      get '/editor'+code, :dict_allowed => code do
        @dictcode = code
        @dict_info = $dict_info
	js_type = $dict_info[code]['type']
	js_path = File.join(settings.public_folder, "editor", "#{js_type}.js")
	@app_version = File.mtime(js_path).to_i
        slim :editor, :layout=>false
      end
      get '/editor'+code do
        @dict_info = $dict_info
        @search_params = {}
        @target = @default_target
        @dictcode = @default_dict
        slim :error401, :status=>401
      end
    end

    if $is_edit or $is_admin
      post '/'+code+'/add_comment' do
        user = ''
        if params['box'] != '' and params['entry'] != '' and params['type'] != ''
          comments.comment_add(dict, @user_info['login'], params['entry'], params['box'], params['text'], params['user'])
        end
        content_type :json
        body = {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      post '/'+code+'/save_comment/:cid' do
        if params['cid'] != ''
          comments.comment_save(params['cid'], params['assign'], params['solved'])
        end
        content_type :json
        body = {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      get '/admin/'+code+'/comments' do
        @dictcode = code
        @params = params
        @target = ''
        @dict_info = $dict_info
        @report = reports.get_comment_report(dict, params)
        @users = dict.get_users
        slim :commentreport
      end
    end

    get '/'+code+'/report' do
      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      @report = dict.get_report(params, @user_info, 0, @report_limit)
      @duplicate = CzjAdminDuplicate.get_duplicate_counts
      slim :report
    end
    get '/'+code+'/reportlist(/:start)?(/:limit)?' do
      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      @report = dict.get_report(params, @user_info, params['start'].to_i, params['limit'].to_i)
      slim :reportresultlist, :layout=>false
    end
    get '/'+code+'/jsonreport' do
      content_type :json
      body = dict.get_report(params, @user_info).to_json
    end
    get '/'+code+'/csvreport' do
      content_type 'text/csv; charset=utf-8'
      attachment code+'report.csv'
      if $dict_info[code]['type'] == 'sign'
	csv = ['ID;video čelní;video boční;překlady;překlady text;fsw;synonyma;varianty;sl.druh;sl.druh2;sl.druh3']
        dict.get_report(params, @user_info)['entries'].each{|rep|
          ri = [rep['id']]
          ri << rep['lemma']['video_front'].to_s
          ri << rep['lemma']['video_side'].to_s
          rels = []
          relst = []
          if rep['meanings']
            rep['meanings'].each{|rm|
              if rm['relation']
                rm['relation'].each{|rel|
                  if rel['type'] == 'translation'
                    rels << rel['target'] + ':' + rel['meaning_id']
                    if rel['entry'] and rel['entry']['lemma'] and rel['entry']['lemma']['title']
                      relst << rel['target'] + ':' + rel['entry']['lemma']['title'].to_s
                    end
                  end
                }
              end
            }
          end
          ri << rels.join(',')
          ri << relst.join(',')
          if rep['lemma']['swmix']
            sws = []
            rep['lemma']['swmix'].each{|sw|
              sws << sw['@fsw']
            }
            ri << sws.join(',')
          elsif rep['lemma']['sw']
            sws = []
            rep['lemma']['sw'].each{|sw|
              sws << sw['@fsw']
            }
            ri << sws.join(',')
          end
	  # synonyma
	  syns = []
	  if rep['meanings']
	  rep['meanings'].each{|rm|
            if rm['relation']
		    rm['relation'].select{|rel| rel['type'] == 'synonym'}.each{|rr|
			    syns << rr['meaning_id'].split('-')[0]
		    }
	    end
	  }
	  end
	  ri << syns.join(',')
	  # varianty
	  vars = []
	  if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0]['variant']
		  rep['lemma']['grammar_note'][0]['variant'].each{|var|
			  vars << var['_text'] if var['_text']
		  }
	  end
	  if rep['lemma']['style_note'] and rep['lemma']['style_note'][0]['variant']
		  rep['lemma']['style_note'][0]['variant'].each{|var|
			  vars << var['_text'] if var['_text']
		  }
	  end
	  ri << vars.join(',')
	  # slovni druh
	  pos = ''
	  pos2 = ''
	  pos3 = ''
	  if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0] 
		  if rep['lemma']['grammar_note'][0]['@slovni_druh']
			  pos = rep['lemma']['grammar_note'][0]['@slovni_druh']
		  end
		  if rep['lemma']['grammar_note'][0]['@skupina']
			  pos2 = rep['lemma']['grammar_note'][0]['@skupina']
		  end
		  if rep['lemma']['grammar_note'][0]['@skupina2']
			  pos3 = rep['lemma']['grammar_note'][0]['@skupina2']
		  end
	  end
	  ri << pos
	  ri << pos2
	  ri << pos3

          csv << ri.join(';')
        }
      else
        csv = ['ID;lemma;slovní druh;význam ID;definice;zdroj definice;*příklad ID;*příklad;*zdroj příkladu;překlady;překlady text']
        dict.get_report(params, @user_info)['entries'].each{|rep|
          if rep['meanings'].size > 0
            rep['meanings'].each{|rm|
              ri = [rep['id']]
              ri << rep['lemma']['title']
              ri << rep['lemma']['grammar_note'][0]['@slovni_druh'].to_s if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0]
              ri << rm['id']
              ri << rm['text']['_text'].to_s.gsub("\n"," ") if rm['text']
              ri << rm['id']['source']
              ri << []
              ri << []
              ri << []
              rels = []
              relst = []
              if rm['relation']
                rm['relation'].each{|rel|
                  if rel['type'] == 'translation'
                    rels << rel['target'] + ':' + rel['meaning_id']
                    if rel['entry'] and rel['entry']['lemma'] and rel['entry']['lemma']['title']
                      relst << rel['target'] + ':' + rel['entry']['lemma']['title'].to_s
                    end
                  end
                }
              end
              ri << rels.join(',')
              ri << relst.join(',')
              csv << ri.join(';')
            }
          else
            ri = [rep['id']]
            ri << rep['lemma']['title']
            ri << rep['lemma']['grammar_note'][0]['@slovni_druh'].to_s if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0]
            csv << ri.join(';')
          end
        }
      end
      body = csv.join("\n")
    end
    get '/'+code+'/videoreport' do
      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      @report = dict.get_videoreport(params, 0, @report_limit)
      @skupiny = []
      @autori = $mongo['media'].distinct('id_meta_author')
      @zdroje = $mongo['media'].distinct('id_meta_source')
      @copys = $mongo['media'].distinct('id_meta_copyright')
      @skupiny = $mongo['entries'].distinct('lemma.pracskupina')
      slim :videoreport
    end
    get '/'+code+'/videoreportlist(/:start)?(/:limit)?' do
      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      @report = dict.get_videoreport(params, params['start'].to_i, params['limit'].to_i)
      slim :videoreportresultlist, :layout=>false
    end
    get '/'+code+'/jsonvideoreport' do
      content_type :json
      body = dict.get_videoreport(params).to_json
    end
    get '/'+code+'/csvvideoreport' do
      content_type 'text/csv; charset=utf-8'
      attachment 'export.csv'
      csv = ['název;hesla;autor;zdroj;autor videa;datum']
      csv += dict.export_videoreport(params)
      body = csv.join("\n")
    end

    if $is_admin
      get '/'+code+'/jsonduplicate' do
        content_type :json
        body = CzjAdminDuplicate.get_duplicate(dict).to_json
      end
      get '/'+code+'/duplicatelist(/:start)?(/:limit)?' do
        content_type :json
        body = CzjAdminDuplicate.get_duplicate(dict, params['start'].to_i, params['limit'].to_i).to_json
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
        body = {"success"=>true,"msg"=>"Uloženo"}.to_json
      else
        body = {"success"=>false,"msg"=>res}.to_json
      end
    end

    post '/users/delete', :admin => true do
      res = $dict_array['czj'].delete_user(params['login'])
      content_type :json
      if res == true
        body = {"success"=>true,"msg"=>"Uloženo"}.to_json
      else
        body = {"success"=>false,"msg"=>res}.to_json
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
      @report = $dict_array['czj'].list_history(params['code'].to_s, params['user'].to_s, params['entry'].to_s)
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
        body = {'logid'=>logid}.to_json
      else
        body = {'error'=>'no dict info'}.to_json
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
      body = data.to_json
    else
      body = params['callback'] + '(' + data.to_json.to_s + ')'
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
      body = data.to_json
    else
      body = params['callback'] + '(' + data.to_json.to_s + ')'
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
    body = response.body
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
