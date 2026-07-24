require_relative "test_helper"
require "json"
require_relative "../lib/czj_entry_json"

class EntryJsonTest < Minitest::Test
  def test_user_list_filters_by_dict_lang
    users = [
      {"login" => "all", "lang" => nil},
      {"login" => "empty", "lang" => []},
      {"login" => "czj-only", "lang" => ["czj"]},
      {"login" => "other", "lang" => ["asl"]}
    ]
    assert_equal [["all"], ["empty"], ["czj-only"]], CzjEntryJson.user_list(users, "czj")
  end
end

# integration: live-doc path through the route with fixture data
class EntryJsonRouteTest < AppTest
  def test_json_endpoint_serves_fixture_entry
    get "/czj/json/38"
    assert_predicate last_response, :ok?
    doc = JSON.parse(last_response.body)
    assert_equal "38", doc["id"].to_s
    assert doc["lemma"], "doc should contain lemma"
  end
end
