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

  SIGN_DICT_INFO = {"czj" => {"type" => "sign"}}
  SIGN_ENTRY = {"dict" => "czj", "id" => "18702", "lemma" => {"video_front" => "A_okno-x.mp4"}}

  def video_cite(location, kind)
    I18n.locale = "cs"
    media = {"location" => location}
    CzjWebHelper.build_video_cite(SIGN_DICT_INFO, SIGN_ENTRY, media, kind)
  end

  def expected_video_cite(location, phrase)
    "#{location} [online]. #{phrase}. In: <i>Dictio: Vícejazyčný slovník znakových jazyků</i>. " \
      "Brno: Masarykova univerzita, 2007. Výkladový slovník českého znakového jazyka, heslo czj-18702. " \
      "Cit. <i>#{DateTime.now.strftime("%-d. %-m. %Y")}</i>. " \
      "Dostupné z URL: https://www.dictio.info/czj/show/18702/#{location}."
  end

  def test_build_video_cite_lemma
    assert_equal expected_video_cite("A_okno-x.mp4", "Soubor s lexémem českého znakového jazyka"),
      video_cite("A_okno-x.mp4", "lemma")
  end

  def test_build_video_cite_definition
    assert_equal expected_video_cite("D_okno.mp4", "Soubor se sémantickou definicí lexému českého znakového jazyka"),
      video_cite("D_okno.mp4", "definition")
  end

  def test_build_video_cite_example
    assert_equal expected_video_cite("K_okno.mp4", "Soubor s kontextovým příkladem českého znakového jazyka"),
      video_cite("K_okno.mp4", "example")
  end

  def test_build_video_cite_appends_author_and_source
    I18n.locale = "cs"
    media = {"location" => "A_okno-x.mp4", "id_meta_author" => "Teiresiás MUNI", "id_meta_source" => "Sbírka XY"}
    cite = CzjWebHelper.build_video_cite(SIGN_DICT_INFO, SIGN_ENTRY, media, "lemma")
    assert cite.end_with?("A_okno-x.mp4. Autor: Teiresiás MUNI. Zdroj: Sbírka XY.")
  end

  def test_build_video_cite_without_media
    assert_equal "", CzjWebHelper.build_video_cite(SIGN_DICT_INFO, SIGN_ENTRY, nil, "lemma")
    assert_equal "", CzjWebHelper.build_video_cite(SIGN_DICT_INFO, SIGN_ENTRY, {"location" => ""}, "lemma")
  end

  def test_build_cite_video_page_detects_kind_from_filename
    I18n.locale = "cs"
    attr = CzjWebHelper.get_cite_attr("video", "/czj/show/18702/D_okno.mp4", nil,
      SIGN_DICT_INFO, SIGN_ENTRY, "czj", nil, nil, "D_okno.mp4")
    assert_includes CzjWebHelper.build_cite(attr), "Soubor se sémantickou definicí lexému českého znakového jazyka"
  end
end
