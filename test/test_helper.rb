ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/mock"
require "rack/test"

# Install the fixture-backed Mongo fake before the app boots (czjapp.rb only
# creates a real client when $mongo is unset).
require_relative "mongo_fake"
$mongo = FakeMongo.new # standard:disable Style/GlobalVars

require_relative "../czjapp"

# Base class for tests that make requests against the app.
class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    CzjApp
  end

  def csrf_token_from_response
    input = last_response.body.scan(/<input\b[^>]*>/).find do |tag|
      tag.include?('name="csrf_token"')
    end
    input && input[/\bvalue="([^"]*)"/, 1]
  end
end
