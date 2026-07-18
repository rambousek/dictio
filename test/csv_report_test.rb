require "minitest/autorun"
require_relative "../lib/czj_csv_report"

# Pure-data tests for the csvreport CSV assembly (no Mongo needed).
class CsvReportTest < Minitest::Test
  # minimal stand-in for CZJDict: only get_media_location is used by sign_csv
  class StubDict
    def initialize(orient) = @orient = orient

    def get_media_location(_video, _code) = {"orient" => @orient}
  end

  def sign_entry
    {
      "id" => "42",
      "lemma" => {
        "video_front" => "vf.mp4",
        "video_side" => "vs.mp4",
        "swmix" => [{"@fsw" => "M500x500"}],
        "grammar_note" => [{"@slovni_druh" => "subst", "@skupina" => "obj",
                            "variant" => [{"_text" => "var1"}]}],
        "style_note" => [{"variant" => [{"_text" => "var2"}]}]
      },
      "meanings" => [
        {"relation" => [
          {"type" => "translation", "target" => "cs", "meaning_id" => "7-1",
           "entry" => {"lemma" => {"title" => "kocka"}}},
          {"type" => "synonym", "meaning_id" => "9-2"}
        ]}
      ]
    }
  end

  def test_sign_csv_row
    csv = CzjCsvReport.sign_csv(StubDict.new("lr"), "czj", [sign_entry])
    assert_equal 2, csv.size
    assert csv[0].start_with?("ID;video čelní")
    cols = csv[1].split(";")
    assert_equal "42", cols[0]
    assert_equal "vf.mp4", cols[1]
    assert_equal "vs.mp4", cols[2]
    assert_equal "L", cols[3], "orient column from CzjApiHelper.video_orient"
    assert_equal "cs:7-1", cols[4]
    assert_equal "cs:kocka", cols[5]
    assert_equal "M500x500", cols[6]
    assert_equal "9", cols[7], "synonym meaning_id prefix"
    assert_equal "var1,var2", cols[8]
    assert_equal "subst", cols[9]
    assert_equal "obj", cols[10]
  end

  def test_sign_csv_no_front_video_empty_orient
    entry = sign_entry
    entry["lemma"]["video_front"] = ""
    csv = CzjCsvReport.sign_csv(StubDict.new("lr"), "czj", [entry])
    assert_equal "", csv[1].split(";")[3]
  end

  def test_write_csv_meaning_rows
    entry = {
      "id" => "5",
      "lemma" => {"title" => "slovo", "grammar_note" => [{"@slovni_druh" => "verb"}]},
      "meanings" => [
        {"id" => "5-1", "text" => {"_text" => "definice\nna radky"},
         "relation" => [{"type" => "translation", "target" => "czj", "meaning_id" => "8-1",
                         "entry" => {"lemma" => {"title" => "ZNAK"}}}]}
      ]
    }
    csv = CzjCsvReport.write_csv([entry])
    assert_equal 2, csv.size
    row = csv[1]
    assert_includes row, "5;slovo;verb;5-1;definice na radky"
    assert_includes row, "czj:8-1"
    assert_includes row, "czj:ZNAK"
  end

  def test_write_csv_entry_without_meanings
    entry = {"id" => "6", "lemma" => {"title" => "bez"}, "meanings" => []}
    csv = CzjCsvReport.write_csv([entry])
    assert_equal ["6;bez"], csv[1..]
  end
end
