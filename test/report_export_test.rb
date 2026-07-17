require_relative "test_helper"
require "json"

# CSV and JSON report exports for sign dictionaries (fixture data: czj/38 has
# main front/side videos with orient "pr" plus extra videos in more_video,
# czj/10000 has a front video with orient "lr").
class ReportExportTest < AppTest
  def test_csvreport_has_orient_in_fourth_column
    get "/czj/csvreport", "idsf" => "38"
    assert_predicate last_response, :ok?
    lines = last_response.body.split("\n")
    assert_equal %w[ID video\ čelní video\ boční orient překlady], lines[0].split(";")[0, 5]
    row = lines.find { |l| l.start_with?("38;") }.split(";")
    assert_equal "A_pohadkaMUOZ231122204.mp4", row[1]
    assert_equal "P", row[3]
  end

  def test_csvreport_orient_left
    get "/czj/csvreport", "idsf" => "10000"
    row = last_response.body.split("\n").find { |l| l.start_with?("10000;") }.split(";")
    assert_equal "A_velryba1.mp4", row[1]
    assert_equal "L", row[3]
  end

  def test_json_export_orient_fields
    get "/czj/export", "idsf" => "38"
    assert_predicate last_response, :ok?
    doc = JSON.parse(last_response.body).find { |e| e["ID"] == "38" }
    assert_equal "A_pohadkaMUOZ231122204.mp4", doc["video_front"]
    assert_equal "P", doc["video_front_orient"]
    assert_equal "B_pohadkaMUOZ231122204.mp4", doc["video_side"]
    assert_equal "P", doc["video_side_orient"]
    orients = doc["more_video"].to_h { |v| [v["video"], v["video_orient"]] }
    assert_equal({"A_pohadkyMUOZ191127017.mp4" => "L",
                  "B_pohadkyMUOZ191127017.mp4" => "L",
                  "pohadka1.mp4" => "P"}, orients)
  end

  def test_json_export_orient_left
    get "/czj/export", "idsf" => "10000"
    doc = JSON.parse(last_response.body).find { |e| e["ID"] == "10000" }
    assert_equal "L", doc["video_front_orient"]
    assert_equal "L", doc["video_side_orient"]
  end
end
