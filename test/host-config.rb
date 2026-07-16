# Test stand-in for the gitignored lib/host-config.rb — no real credentials.
# Mongo::Client connects lazily, so a nonexistent test DB is fine as long as
# the code under test never runs a query against it.
$mongoHost = ENV.fetch("TEST_MONGO", "mongodb://127.0.0.1:27017/dictio_test")
$environment = :test
$hostname = "example.org"
$session_secret = "0" * 64
$is_edit = false
$is_admin = false
$is_test = true
$files_user = "nobody"
$files_keys = []
$ske_api = ""
