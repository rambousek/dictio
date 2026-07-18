class CzjApp < Sinatra::Base
  (WRITE_DICTS+SIGN_DICTS).each{|code|
    dict = $dict_array[code]

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
        if words_array.size > 1
          m = CzjFuzzyMatch.multisyllabic_match(words_array, possible_matches)
          @resultinfo3 = m['resultinfo3']
        else
          m = CzjFuzzyMatch.single_word_match(@search, possible_matches, code)
          @resultinfo1 = m['resultinfo1']
          @resultinfo2 = m['resultinfo2']
        end
        if m['match']
          @search = m['match']
          @result = dict.translate2(code, params['target'], m['match'], params['type'], params['start'].to_i, params['limit'].to_i)
        end
      end
      #výpis výsledků hledání
      slim :transresultlist, layout: false
    end
  }
end
