class CzjApp < Sinatra::Base
  if $is_edit
    set (:dict_allowed) {|value| condition { @user_info['admin'] or ((@user_info['revizor'] != [] or (@user_info['editor'] != [] and @user_info['editor'] != ['komparator'])) and (@user_info['dict_allowed'].nil? or @user_info['dict_allowed'] == [] or @user_info['dict_allowed'].include?(value))) } }
  end
  (WRITE_DICTS+SIGN_DICTS).each{|code|
    dict = $dict_array[code]

    if $is_edit

      get '/'+code+'/newentry' do
        newid = dict.get_new_id
        doc = {'user_info' => @user_info, 'newid' => newid}
        content_type :json
        doc.to_json
      end
      get '/'+code+'/comments/:id(/:type)?' do
        content_type :json
        COMMENTS.get_comments(code, params['id'], params['type'].to_s).to_json
      end
      post '/'+code+'/save' do
        data = JSON.parse(params['data'])
        dict.save_doc(data, @user_info['login'])
        content_type :json
        {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      post '/'+code+'/delete/:id' do
        if params['id'].to_s != ''
          if @user_info['editor'].length > 0 or @user_info['revizor'].length > 0 or @user_info['perm'].include?('admin')
            dict.remove_all_relations(params['id'].to_s)
            dict.remove_colloc(params['id'].to_s)
            dict.delete_doc(params['id'].to_s)
            'DELETED ' + params['id'].to_s
          else
            'not authorized to delete entry'
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
        {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      post '/'+code+'/remove_video' do
        content_type :json
        if params['entry_id'].to_s != '' and params['media_id'].to_s != ''
          dict.edit_media.remove_video(params['entry_id'].to_s, params['media_id'].to_s)
          {"success"=>true, "message"=>"Soubor odebrán"}.to_json
        else
          {'success'=>false, 'message'=>"Chybí parametry videa"}.to_json
        end
      end
      get '/'+code+'/del_comment/:cid' do
        if params['cid'] != ''
          COMMENTS.comment_del(params['cid'])
        end
        content_type :json
        {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      get '/'+code+'/filelist/:id' do
        list = dict.edit_media.get_entry_files(params['id'], params['type'].to_s)
        if params['search'].to_s != ''
          list = dict.edit_media.find_files(params['search'].to_s, params['type'].to_s)
        end
        content_type :json
        list.to_json
      end
      get '/'+code+'/relfind' do
        data = dict.find_relation(params['search'].to_s)
        content_type :json
        data.to_json
      end
      get '/'+code+'/linkfind' do
        data = dict.find_link(params['search'].to_s)
        content_type :json
        data.to_json
      end
      get '/'+code+'/getfsw' do
        fsw = CzjFsw.getfsw(params['sw'].to_s)
        fsw
      end
      get '/'+code+'/fromfsw' do
        sw = CzjFsw.fromfsw(params['fsw'].to_s)
        sw
      end
      get '/'+code+'/relationinfo' do
        info = dict.get_relation_info(params['meaning_id'].to_s)
        info
      end
      get '/'+code+'/getrelations' do
        list = dict.get_relations(params['meaning_id'].to_s, params['type'].to_s, @user_info)
        content_type :json
        list.to_json
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
        dict.get_gram(params['id']).to_json
      end
      get '/editor'+code, :dict_allowed => code do
        @dictcode = code
        @dict_info = $dict_info
	      js_type = $dict_info[code]['type']
	      js_path = File.join(settings.public_folder, "editor", "#{js_type}.js")
	      common_path = File.join(settings.public_folder, "editor", "editor-common.js")
	      @app_version = [File.mtime(js_path), File.mtime(common_path)].max.to_i
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
        if params['box'] != '' and params['entry'] != '' and params['type'] != ''
          COMMENTS.comment_add(dict, @user_info['login'], params['entry'], params['box'], params['text'], params['user'])
        end
        content_type :json
        {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      post '/'+code+'/save_comment/:cid' do
        if params['cid'] != ''
          COMMENTS.comment_save(params['cid'], params['assign'], params['solved'])
        end
        content_type :json
        {"success"=>true,"msg"=>"Uloženo"}.to_json
      end
      get '/admin/'+code+'/comments' do
        @dictcode = code
        @params = params
        @target = ''
        @dict_info = $dict_info
        @report = REPORTS.get_comment_report(dict, params)
        @users = CzjUsers.get_users
        slim :commentreport
      end
    end
  }
end
