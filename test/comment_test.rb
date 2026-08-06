require_relative "test_helper"

# CzjComment#count_assigned and CzjReport#get_comment_report against injected
# koment docs (FakeMongo).
class CommentTest < Minitest::Test
  def comment(dict, assign, solved = nil, user = "eva")
    doc = {"dict" => dict, "entry" => "3881", "box" => "lemma", "text" => "x",
           "user" => user, "time" => "2026-07-30 10:00", "assign" => assign}
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

  def report(params)
    CzjApp::REPORTS.get_comment_report($dict_array["cs"], params) # standard:disable Style/GlobalVars
  end

  def load_report_comments
    $mongo.load("koment", [ # standard:disable Style/GlobalVars
      comment("cs", "deb", nil, "eva"),
      comment("cs", "eva", nil, "eva"),
      comment("cs", "deb", nil, "petr"),
      comment("cs", "deb", "1", "eva"),
      comment("czj", "deb", nil, "eva")
    ])
  end

  def test_comment_report_filters_by_author
    load_report_comments
    result = report("user" => "eva")
    assert_equal 2, result["resultcount"]
    assert_equal ["eva"], result["comments"].map { |k| k["user"] }.uniq
  end

  def test_comment_report_author_and_assign_combined
    load_report_comments
    result = report("user" => "eva", "assign" => "deb")
    assert_equal 1, result["resultcount"]
    assert_equal "deb", result["comments"][0]["assign"]
  end

  def test_comment_report_empty_author_not_filtered
    load_report_comments
    assert_equal 3, report("user" => "")["resultcount"]
    assert_equal 3, report({})["resultcount"]
  end
end
