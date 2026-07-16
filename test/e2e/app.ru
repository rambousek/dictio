# Rack config that boots the app against the fixture-backed FakeMongo,
# for Playwright end-to-end tests. Run from the repo root:
#   bundle exec rackup test/e2e/app.ru -p 9393
ENV["RACK_ENV"] = "test"

require_relative "../mongo_fake"
$mongo = FakeMongo.new # standard:disable Style/GlobalVars

require_relative "../../czjapp"

run CzjApp
