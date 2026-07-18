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
    response.body
  end
end
