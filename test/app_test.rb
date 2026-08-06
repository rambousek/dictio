require_relative "test_helper"

# Route smoke tests — only routes that don't query MongoDB.
class StaticPagesTest < AppTest
  LOCALES = %w[cs de en sk ua].freeze

  # routes/pages.rb picks the template by interpolating the locale
  # (page = 'help-' + I18n.locale.to_s), so a missing or syntactically broken
  # per-language variant only surfaces when that language is requested.
  PAGES = %w[/about /help /helpsign /contact].freeze

  PAGES.each do |page|
    define_method(:"test_#{page.delete("/")}_renders_in_every_locale") do
      LOCALES.each do |locale|
        get page, "lang" => locale
        assert_predicate last_response, :ok?, "#{page} failed for lang=#{locale}"
        assert_includes last_response.body, "Dictio"
      end
    end
  end
end
