class CzjApp < Sinatra::Base
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
    dict = $dict_array[code]

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
end
