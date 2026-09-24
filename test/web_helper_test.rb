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
  WRITE_DICT_INFO = {"cs" => {"type" => "write"}}
  WRITE_ENTRY = {"dict" => "cs", "id" => "62072", "lemma" => {"title" => "okno"}}

  def app_version
    $app_version # standard:disable Style/GlobalVars
  end

  def cite_date
    DateTime.now.strftime("%-d. %-m. %Y")
  end

  def video_cite(location, kind, meaning = nil)
    I18n.locale = "cs"
    CzjWebHelper.build_video_cite(SIGN_DICT_INFO, SIGN_ENTRY, {"location" => location}, kind, meaning)
  end

  def test_build_cite_page_has_version
    I18n.locale = "cs"
    attr = CzjWebHelper.get_cite_attr("page", "/", "index")
    assert_equal "<i>Dictio: Vícejazyčný slovník znakových jazyků</i> [online]. Verze #{app_version}. " \
      "Brno: Masarykova univerzita, 2007- . Cit. #{cite_date}. Dostupné z URL: https://www.dictio.info/.",
      CzjWebHelper.build_cite(attr)
  end

  def test_build_video_cite_lemma
    assert_equal "A_okno-x.mp4 [online]. Soubor s lexémem českého znakového jazyka. " \
      "In: <i>Dictio: Vícejazyčný slovník znakových jazyků</i>. Verze #{app_version}. " \
      "Brno: Masarykova univerzita, 2007- . Výkladový slovník českého znakového jazyka, heslo czj-18702. " \
      "Cit. #{cite_date}. Dostupné z URL: https://www.dictio.info/czj/show/18702/A_okno-x.mp4.",
      video_cite("A_okno-x.mp4", "lemma")
  end

  def test_build_video_cite_definition
    assert_equal "KOLEKTIV AUTORŮ. D_okno.mp4. " \
      "In: <i>Dictio: Vícejazyčný slovník znakových jazyků</i>. Verze #{app_version}. " \
      "Brno: Masarykova univerzita, 2007- . Výkladový slovník českého znakového jazyka, heslo czj-18702, význam 1. " \
      "Cit. #{cite_date}. Dostupné z URL: https://www.dictio.info/czj/show/18702/D_okno.mp4.",
      video_cite("D_okno.mp4", "definition", "1")
  end

  def test_build_video_cite_example
    assert_includes video_cite("K_okno.mp4", "example", "1"),
      "KOLEKTIV AUTORŮ. K_okno.mp4. In: "
    assert_includes video_cite("K_okno.mp4", "example", "1"),
      "heslo czj-18702, význam 1, příklady. Cit."
  end

  def test_build_video_cite_without_media
    assert_equal "", CzjWebHelper.build_video_cite(SIGN_DICT_INFO, SIGN_ENTRY, nil, "lemma")
    assert_equal "", CzjWebHelper.build_video_cite(SIGN_DICT_INFO, SIGN_ENTRY, {"location" => ""}, "lemma")
  end

  def test_build_cite_video_page_detects_kind_from_filename
    I18n.locale = "cs"
    attr = CzjWebHelper.get_cite_attr("video", "/czj/show/18702/D_okno.mp4", nil,
      SIGN_DICT_INFO, SIGN_ENTRY, "czj", nil, nil, "D_okno.mp4")
    assert CzjWebHelper.build_cite(attr).start_with?("KOLEKTIV AUTORŮ. D_okno.mp4. In: ")
  end

  def test_build_part_cite_write_meaning
    I18n.locale = "cs"
    assert_equal "<i>Dictio: Vícejazyčný slovník znakových jazyků</i>. Verze #{app_version}. " \
      "Brno: Masarykova univerzita, 2007- . Výkladový slovník češtiny, heslo okno, význam 1. " \
      "Cit. #{cite_date}. Dostupné z URL: https://www.dictio.info/cs/search/text/okno/62072.",
      CzjWebHelper.build_part_cite(WRITE_DICT_INFO, WRITE_ENTRY, "1")
  end

  def test_build_part_cite_write_examples
    I18n.locale = "cs"
    assert_includes CzjWebHelper.build_part_cite(WRITE_DICT_INFO, WRITE_ENTRY, "1", true),
      "Výkladový slovník češtiny, heslo okno, význam 1, příklady. Cit."
  end

  def test_build_part_cite_sign_meaning
    I18n.locale = "cs"
    cite = CzjWebHelper.build_part_cite(SIGN_DICT_INFO, SIGN_ENTRY, "2")
    assert_includes cite, "heslo czj-18702, význam 2. Cit."
    assert cite.end_with?("Dostupné z URL: https://www.dictio.info/czj/show/18702.")
  end
end
