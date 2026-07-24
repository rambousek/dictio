class CzjApp < Sinatra::Base
  (WRITE_DICTS+SIGN_DICTS).each{|code|
    dict = $dict_array[code]

    get '/'+code+'/report' do
      @dictcode = code
      @target = ''
      @dict_info = $dict_info
      @params = params
      @report = REPORTS.get_report(dict, params, @user_info, 0, @report_limit)
      @duplicate = CzjAdminDuplicate.get_duplicate_counts
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
      # 200 even for unknown ids: the not_found handler would replace a 404 body with HTML
      {'status' => meta.nil? ? 'unknown' : meta['status']}.to_json
    end
    get '/'+code+'/export/download/:job_id' do
      meta = CzjExportJob.meta(params['job_id'])
      halt 404 if meta.nil? or meta['status'] != 'done'
      halt 403 if meta['user'] != (@user_info ? @user_info['login'] : '').to_s
      send_file CzjExportJob.data_path(params['job_id']), :filename => meta['filename'], :type => meta['content_type'], :disposition => :attachment
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
      dict.get_videoreport(params).to_json
    end
    get '/'+code+'/csvvideoreport' do
      content_type 'text/csv; charset=utf-8'
      attachment 'export.csv'
      csv = ['název;hesla;autor;zdroj;autor videa;datum']
      csv += dict.export_videoreport(params)
      csv.join("\n")
    end
  }
end
