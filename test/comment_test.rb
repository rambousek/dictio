require_relative "test_helper"

# CzjComment#count_assigned against injected koment docs (FakeMongo).
class CommentTest < Minitest::Test
  def comment(dict, assign, solved = nil)
    doc = {"dict" => dict, "entry" => "1", "box" => "lemma", "text" => "x",
           "user" => "eva", "time" => "2026-07-30 10:00", "assign" => assign}
    doc["solved"] = solved unless solved.nil?
    doc
  end

  def setup
    @comments = CzjComment.new
  end

  def teardown
    $mongo.load("koment", []) # standard:disable Style/GlobalVars
  end

  def test_count_assigned_groups_unsolved_by_dict
    $mongo.load("koment", [ # standard:disable Style/GlobalVars
      comment("cs", "deb"),
      comment("cs", "deb", ""),
      comment("czj", "deb"),
      comment("cs", "eva"),
      comment("cs", "deb", "1")
    ])
    assert_equal({"cs" => 2, "czj" => 1}, @comments.count_assigned("deb"))
  end

  def test_count_assigned_empty_login
    $mongo.load("koment", [comment("cs", "")]) # standard:disable Style/GlobalVars
    assert_empty @comments.count_assigned("")
  end
end
