require_relative "test_helper"
require "cgi"

class QuoteTest < AppTest
  def quotes
    last_response.body.scan(/data-quote="([^"]*)"/).flatten.map { |q| CGI.unescapeHTML(q) }
  end

  def test_sign_entry_detail_has_part_quotes
    get "/czj/show/38", "lang" => "cs"
    assert_predicate last_response, :ok?
    assert quotes.any? { |q| q.include?("Soubor s lexémem") }, "lemma video quote"
    assert quotes.any? { |q| q.start_with?("KOLEKTIV AUTORŮ. D") && q.include?("heslo czj-38, význam 1.") }, "definition quote"
    assert quotes.any? { |q| q.start_with?("KOLEKTIV AUTORŮ. K") && q.include?(", příklady.") }, "example quote"
    assert quotes.any? { |q| q.include?("heslo czj-38, význam 1. Cit.") && q.end_with?("/czj/show/38.") }, "meaning quote"
  end

  def test_write_entry_detail_has_part_quotes
    get "/cs/show/3881", "lang" => "cs"
    assert_predicate last_response, :ok?
    assert_includes quotes.join("\n"), "heslo vosk, význam 1. Cit."
    assert_includes quotes.join("\n"), "heslo vosk, význam 1, příklady. Cit."
    assert_includes quotes.join("\n"), "https://www.dictio.info/cs/search/text/vosk/3881."
  end

  def test_search_entry_has_part_quotes
    get "/czj/searchentry/38", "lang" => "cs"
    assert_predicate last_response, :ok?
    assert quotes.any? { |q| q.start_with?("KOLEKTIV AUTORŮ. D") }
    get "/cs/searchentry/3881", "lang" => "cs"
    assert quotes.any? { |q| q.include?(", příklady.") }
  end

  def test_grammar_block_is_not_quotable
    get "/czj/show/38", "lang" => "cs"
    refute quotes.any? { |q| q.include?("Formální popis") }
  end

  def test_part_cite_button_and_modal_labels
    get "/czj/show/38", "lang" => "cs"
    body = last_response.body
    assert_includes body, "Citovat jen část hesla"
    assert_includes body, 'data-page-title="Citace této stránky"'
    assert_includes body, 'data-part-title="Citace části hesla"'
    assert_includes body, 'data-hint="Vyberte část hesla, kterou chcete citovat."'
  end
end
