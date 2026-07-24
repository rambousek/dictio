require 'net/http'
require 'net/https'
require 'openssl'

# SketchEngine concordance proxy for the /korpus endpoint
module CzjKorpus
  module_function

  # NOTE: lemma is embedded without URI escaping, matching historical behavior
  def concordance_url(lemma)
    'https://api.sketchengine.eu/bonito/run.cgi/first?corpname=preloaded%2Fcstenten19_mj2&iquery='+lemma.to_s+'&queryselector=iqueryrow&default_attr=word&fc_lemword_window_type=both&fc_lemword_wsize=5&gdex_enabled=1&viewmode=sentence&refs==doc.url&pagesize=50&format=json'
  end

  def fetch(lemma, apikey)
    newurl = concordance_url(lemma)
    $stdout.puts 'PROXY '+ newurl
    uri = URI(newurl)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri, {'Authorization'=>'Bearer '+apikey})
    response = http.request(request)
    response.body
  end
end
