require_relative "test_helper"
require_relative "../lib/czj_history"

# FakeMongo is read-only, so record inserts through a stand-in $mongo
class RecordingCollection
  attr_reader :inserted

  def initialize
    @inserted = []
  end

  def insert_one(doc)
    @inserted << doc
  end
end

class RecordingMongo
  def initialize
    @collections = {}
  end

  def [](name)
    @collections[name] ||= RecordingCollection.new
  end
end

class HistoryTest < Minitest::Test
  def with_recording_mongo
    real = $mongo # standard:disable Style/GlobalVars
    fake = RecordingMongo.new
    $mongo = fake # standard:disable Style/GlobalVars
    yield fake
  ensure
    $mongo = real # standard:disable Style/GlobalVars
  end

  def test_save_delete_info_records_deleted_entry
    with_recording_mongo do |mongo|
      olddoc = {"dict" => "czj", "id" => "7097", "lemma" => {"text" => "test"}}
      CzjHistory.save_delete_info("czj", "7097", olddoc, "tester")

      records = mongo["history"].inserted
      assert_equal 1, records.size
      rec = records.first
      assert_equal "czj", rec["dict"]
      assert_equal "7097", rec["entry"]
      assert_equal "tester", rec["user"]
      assert_equal "delete", rec["action"]
      assert_equal olddoc, rec["full_entry_old"]
      assert_nil rec["full_entry"]
      refute_empty rec["detail"].to_s
      refute_empty rec["timestamp"].to_s
    end
  end

  def test_save_history_info_keeps_new_entry
    with_recording_mongo do |mongo|
      newdoc = {"dict" => "czj", "id" => "7097", "track_changes" => "změna"}
      CzjHistory.save_history_info("czj", "7097", newdoc, {"id" => "7097"}, "tester")

      rec = mongo["history"].inserted.first
      assert_equal "změna", rec["detail"]
      assert_nil rec["action"]
      refute_nil rec["full_entry"]
      refute rec["full_entry"].key?("track_changes")
    end
  end
end
