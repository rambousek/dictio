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
end
