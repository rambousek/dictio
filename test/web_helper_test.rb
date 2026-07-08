require_relative "test_helper"

class WebHelperTest < Minitest::Test
  def test_get_cite_attr_for_page
    attr = CzjWebHelper.get_cite_attr("page", "/about", "about")
    assert_equal "page", attr["data"]["page-type"]
    assert_equal "about", attr["data"]["page-name"]
    assert_equal "https://www.dictio.info/about", attr["data"]["page-url"]
  end

  def test_get_cite_attr_for_write_entry
    dict_info = {"cs" => {"type" => "write"}}
    entry = {"dict" => "cs", "id" => "42", "lemma" => {"title" => "pes"}}
    attr = CzjWebHelper.get_cite_attr("show", "/cs/show/42", nil, dict_info, entry)
    assert_equal "write", attr["data"]["lang-type"]
    assert_equal "pes", attr["data"]["lemma"]
  end

  def test_build_cite_show
    I18n.locale = "cs"
    attr = CzjWebHelper.get_cite_attr("show", "/cs/show/42", nil,
      {"cs" => {"type" => "write"}},
      {"dict" => "cs", "id" => "42", "lemma" => {"title" => "pes"}})
    cite = CzjWebHelper.build_cite(attr)
    assert_includes cite, "pes"
    assert_includes cite, "https://www.dictio.info/cs/show/42"
  end
end
