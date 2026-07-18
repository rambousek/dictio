class CzjApp < Sinatra::Base
  (WRITE_DICTS+SIGN_DICTS).each{|code|
    dict = $dict_array[code]

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
      doc.to_json
    end
    get '/'+code+'/jsonsearch/:type/:search(/:start)?(/:limit)?' do 
      content_type :json
      more_params = {}
      %w[slovni_druh stylpriznak oblast].each{|parname|
        if params[parname].to_s != '' and params[parname].to_s != 'undefined'
          more_params[parname] = params[parname]
        end
      }
      dict.search(code, params['search'].to_s.strip, params['type'].to_s, params['start'].to_i, params['limit'].to_i, more_params).to_json
    end
    get '/'+code+'/jsontranslate/:target/:type/:search(/:start)?(/:limit)?' do 
      content_type :json
      dict.translate2(code, params['target'], params['search'].to_s.strip, params['type'].to_s, params['start'].to_i, params['limit'].to_i).to_json
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
      {'count': count}.to_json
    end
    get '/'+code+'/cache_all_rel' do
      purge = false
      purge = true if params['purge'] == '1'
      count = dict.cache_all_relations(purge)
      content_type :json
      {'count': count}.to_json
    end
    get '/'+code+'/cache_rel_entry/:id' do
      count = dict.cache_relations_entry(code, params['id'])
      content_type :json
      {'count': count}.to_json
    end
    get '/'+code+'/normalize_fsw' do
      count = dict.sw.normalize_fsw
      {'count': count}.to_json
    end
  }
end
