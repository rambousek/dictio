ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../czjapp"

# Base class for tests that make requests against the app.
class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    CzjApp
  end
end
