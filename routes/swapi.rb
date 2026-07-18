class CzjApp < Sinatra::Base
  get '/swapi/symbol_definition/:id.json' do
    data = $mongo['symbol'].find({'id'=>params['id']}).first
    if params['callback'].to_s == ''
      content_type :json
      data.to_json
    else
      params['callback'] + '(' + data.to_json.to_s + ')'
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
      data.to_json
    else
      params['callback'] + '(' + data.to_json.to_s + ')'
    end
  end

  get '/korpus' do
    content_type :json
    CzjKorpus.fetch(params['lemma'], $ske_api)
  end
end
