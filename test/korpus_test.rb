require "minitest/autorun"
require_relative "../lib/czj_korpus"

class KorpusTest < Minitest::Test
  def test_concordance_url_embeds_lemma
    url = CzjKorpus.concordance_url("slovo")
    assert_includes url, "iquery=slovo&"
    assert url.start_with?("https://api.sketchengine.eu/bonito/run.cgi/first?")
    assert_includes url, "format=json"
  end

  def test_concordance_url_does_not_escape
    # documents current behavior: lemma is embedded raw, no URI escaping
    assert_includes CzjKorpus.concordance_url("a b"), "iquery=a b&"
  end
end
