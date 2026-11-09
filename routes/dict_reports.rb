class CzjApp < Sinatra::Base
  (WRITE_DICTS+SIGN_DICTS).each{|code|
    dict = $dict_array[code]

    get '/'+code+'/report' do
      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      id_query = {'dict' => code, 'empty' => {'$exists' => false}}
      id_sort_options = {
        :projection => {'id' => 1},
        :collation => {'locale' => 'cs', 'numericOrdering' => true}
      }
      first_entry = $mongo['entries'].find(id_query, id_sort_options.merge(:sort => {'id' => 1})).first
      last_entry = $mongo['entries'].find(id_query, id_sort_options.merge(:sort => {'id' => -1})).first
      @id_range_min = first_entry ? first_entry['id'] : '0'
      @id_range_max = last_entry ? last_entry['id'] : @id_range_min
      @report = REPORTS.get_report(dict, params, @user_info, 0, @report_limit)
      @duplicate = can_view_duplicate_list? ? CzjAdminDuplicate.get_duplicate_counts : {'duplicate' => []}
      slim :report
    end
    get '/'+code+'/reportlist(/:start)?(/:limit)?' do
      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      @report = REPORTS.get_report(dict, params, @user_info, params['start'].to_i, params['limit'].to_i)
      slim :reportresultlist, :layout=>false
    end
    get '/'+code+'/jsonreport' do
      content_type :json
      REPORTS.get_report(dict, params, @user_info).to_json
    end
    get '/'+code+'/export' do
      content_type :json
      data = REPORTS.get_report(dict, params, @user_info)['entries']
      if $dict_info[code]['type'] == 'sign'
        result = CzjApiHelper.reformat_report_sign(dict, data)
      else
        result = CzjApiHelper.reformat_report_write(dict, data)
      end
      result.to_json
    end
    # long exports run in the background, frontend polls status and downloads the result
    get '/'+code+'/export/start' do
      content_type :json
      query = params
      user_info = @user_info
      id = CzjExportJob.start(user: @user_info ? @user_info['login'] : '', filename: code+'-export.json', content_type: 'application/json') do
        data = REPORTS.get_report(dict, query, user_info)['entries']
        if $dict_info[code]['type'] == 'sign'
          CzjApiHelper.reformat_report_sign(dict, data).to_json
        else
          CzjApiHelper.reformat_report_write(dict, data).to_json
        end
      end
      {'id' => id}.to_json
    end
    get '/'+code+'/export/status/:job_id' do
      content_type :json
      meta = CzjExportJob.meta(params['job_id'])
      halt 403 if meta && meta['admin_only'] && !(@user_info && @user_info['admin'])
      # 200 even for unknown ids: the not_found handler would replace a 404 body with HTML
      {'status' => meta.nil? ? 'unknown' : meta['status'], 'error' => meta && meta['error']}.to_json
    end
    get '/'+code+'/export/download/:job_id' do
      meta = CzjExportJob.meta(params['job_id'])
      halt 404 if meta.nil? or meta['status'] != 'done'
      halt 403 if meta['admin_only'] && !(@user_info && @user_info['admin'])
      halt 403 if meta['user'] != (@user_info ? @user_info['login'] : '').to_s
      send_file CzjExportJob.data_path(params['job_id']), :filename => meta['filename'], :type => meta['content_type'], :disposition => :attachment
    end
    post '/'+code+'/video-export/start' do
      halt 403 unless @user_info && @user_info['admin']
      verify_csrf_token!
      halt 404 unless $dict_info[code]['type'] == 'sign'

      selections = {
        "front" => params["front"] == "1",
        "front_all" => params["front_all"] == "1",
        "side" => params["side"] == "1",
        "side_all" => params["side_all"] == "1",
        "definition" => params["definition"] == "1",
        "examples" => params["examples"] == "1"
      }
      selections["front_all"] = false unless selections["front"]
      selections["side_all"] = false unless selections["side"]
      halt 422, "Select at least one video category" unless selections.values.any?

      filters = Rack::Utils.parse_nested_query(params["filters"].to_s)
      user_info = @user_info
      id = CzjExportJob.start_file(
        user: @user_info ? @user_info["login"] : "",
        filename: code + "-videos.zip",
        content_type: "application/zip",
        admin_only: true
      ) do |path|
        CzjVideoExport.new(dict, filters, user_info, selections).write(path)
      end
      content_type :json
      {"id" => id}.to_json
    end
    get '/'+code+'/csvreport' do
      content_type 'text/csv; charset=utf-8'
      attachment code+'report.csv'
      entries = REPORTS.get_report(dict, params, @user_info)['entries']
      if $dict_info[code]['type'] == 'sign'
        csv = CzjCsvReport.sign_csv(dict, code, entries)
      else
        csv = CzjCsvReport.write_csv(entries)
      end
      csv.join("\n")
    end
    get '/'+code+'/videoreport' do
      halt 404 unless can_edit_entries?

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
      halt 404 unless can_edit_entries?

      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      @report = dict.get_videoreport(params, params['start'].to_i, params['limit'].to_i)
      slim :videoreportresultlist, :layout=>false
    end
    get '/'+code+'/jsonvideoreport' do
      halt 404 unless can_edit_entries?

      content_type :json
      dict.get_videoreport(params).to_json
    end
    get '/'+code+'/csvvideoreport' do
      halt 404 unless can_edit_entries?

      content_type 'text/csv; charset=utf-8'
      attachment 'export.csv'
      csv = ['název;hesla;autor;zdroj;autor videa;datum']
      csv += dict.export_videoreport(params)
      csv.join("\n")
    end
  }
end
