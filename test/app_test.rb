require_relative "test_helper"

# Route smoke tests — only routes that don't query MongoDB.
class StaticPagesTest < AppTest
  def test_about_renders
    get "/about", "lang" => "cs"
    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Dictio"
  end

  def test_about_in_english
    get "/about", "lang" => "en"
    assert_predicate last_response, :ok?
  end
end
