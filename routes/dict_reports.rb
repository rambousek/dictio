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
      if $dict_info[code]['type'] == 'sign'
	      csv = ['ID;video čelní;video boční;orient;překlady;překlady text;fsw;synonyma;varianty;sl.druh;sl.druh2;sl.druh3']
        REPORTS.get_report(dict, params, @user_info)['entries'].each{|rep|
          ri = [rep['id']]
          ri << rep['lemma']['video_front'].to_s
          ri << rep['lemma']['video_side'].to_s
          if rep['lemma']['video_front'].to_s == ''
            ri << ''
          else
            ri << CzjApiHelper.video_orient(dict.get_media_location(rep['lemma']['video_front'].to_s, code))
          end
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
        REPORTS.get_report(dict, params, @user_info)['entries'].each{|rep|
          if rep['meanings'] and rep['meanings'].size > 0
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
