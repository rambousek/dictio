require_relative "test_helper"
require "tmpdir"

class VideoExportTest < AppTest
  def setup
    @original_entries = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "entries.json")))
    @original_media = JSON.parse(File.read(File.join(FakeMongo::FIXDIR, "media.json")))
  end

  def teardown
    $mongo.load("entries", @original_entries)
    $mongo.load("media", @original_media)
  end

  def test_exports_main_videos_and_related_definition_and_example_videos
    $mongo.load("entries", [entry])
    $mongo.load("media", media)
    downloaded = []
    path = File.join(Dir.tmpdir, "video-export-test.zip")

    CzjVideoExport.new(
      $dict_array["czj"],
      Hash.new(""),
      nil,
      {"front" => true, "definition" => true, "examples" => true},
      downloader: lambda { |_dict, location, write_chunk|
        downloaded << location
        write_chunk.call("video data")
      }
    ).write(path)

    archive = File.binread(path)
    assert_equal ["A_main.mp4", "D_definition.mp4", "K_example.mp4"], downloaded.sort
    assert_includes archive, "A_main.mp4"
    assert_includes archive, "D_definition.mp4"
    assert_includes archive, "K_example.mp4"
    assert_equal "PK\x05\x06", archive[-22, 4]
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_all_existing_includes_non_main_front_video
    $mongo.load("entries", [entry])
    $mongo.load("media", media)
    downloaded = []
    path = File.join(Dir.tmpdir, "video-export-test.zip")

    CzjVideoExport.new(
      $dict_array["czj"],
      Hash.new(""),
      nil,
      {"front" => true, "front_all" => true},
      downloader: lambda { |_dict, location, write_chunk|
        downloaded << location
        write_chunk.call("video data")
      }
    ).write(path)

    assert_equal ["A_folder.mp4", "A_main.mp4", "A_other.mp4"], downloaded.sort
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_export_fails_when_archive_size_limit_is_exceeded
    $mongo.load("entries", [entry])
    downloaded = []
    path = File.join(Dir.tmpdir, "video-export-size-limit-test.zip")

    error = assert_raises(CzjVideoExport::LimitExceeded) do
      CzjVideoExport.new(
        $dict_array["czj"],
        Hash.new(""),
        nil,
        {"front" => true},
        downloader: lambda { |_dict, location, write_chunk|
          downloaded << location
          write_chunk.call("video data")
        },
        max_archive_size: 100
      ).write(path)
    end

    assert_equal "size_limit", error.code
    assert_equal ["A_main.mp4"], downloaded
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_export_fails_when_video_count_limit_is_exceeded
    $mongo.load("entries", [entry])
    $mongo.load("media", media)
    downloaded = []
    path = File.join(Dir.tmpdir, "video-export-count-limit-test.zip")

    error = assert_raises(CzjVideoExport::LimitExceeded) do
      CzjVideoExport.new(
        $dict_array["czj"],
        Hash.new(""),
        nil,
        {"front" => true, "definition" => true, "examples" => true},
        downloader: lambda { |_dict, location, write_chunk|
          downloaded << location
          write_chunk.call("video data")
        },
        max_videos: 1
      ).write(path)
    end

    assert_equal "video_count_limit", error.code
    assert_empty downloaded
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  def test_estimated_size_limit_rejects_before_downloading_videos
    $mongo.load("entries", [entry])
    $mongo.load("media", media)
    downloaded = []
    path = File.join(Dir.tmpdir, "video-export-estimated-size-limit-test.zip")

    error = assert_raises(CzjVideoExport::LimitExceeded) do
      CzjVideoExport.new(
        $dict_array["czj"],
        Hash.new(""),
        nil,
        {"front" => true, "definition" => true},
        downloader: lambda { |_dict, location, write_chunk|
          downloaded << location
          write_chunk.call("video data")
        },
        max_estimated_size: 5 * 1024**2
      ).write(path)
    end

    assert_equal "estimated_size_limit", error.code
    assert_empty downloaded
    refute File.exist?(path)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  private

  def entry
    {
      "id" => "export-test",
      "dict" => "czj",
      "lemma" => {"video_front" => "A_main.mp4", "video_side" => "B_main.mp4", "media_folder_id" => "folder1"},
      "meanings" => [
        {
          "text" => {"file" => {"@media_id" => "definition-id"}},
          "usages" => [{"text" => {"file" => {"@media_id" => "example-id"}}}]
        }
      ]
    }
  end

  def media
    [
      {"id" => "front-id", "dict" => "czj", "location" => "A_main.mp4", "type" => "sign_front", "entry_folder" => ["export-test"]},
      {"id" => "other-id", "dict" => "czj", "location" => "A_other.mp4", "type" => "sign_front", "entry_folder" => ["export-test"]},
      {"id" => "folder-id", "dict" => "czj", "location" => "A_folder.mp4", "type" => "sign_front", "media_folder_id" => "folder1"},
      {"id" => "side-id", "dict" => "czj", "location" => "B_main.mp4", "type" => "sign_side", "entry_folder" => ["export-test"]},
      {"id" => "definition-id", "dict" => "czj", "location" => "D_definition.mp4", "type" => "sign_definition"},
      {"id" => "example-id", "dict" => "czj", "location" => "K_example.mp4", "type" => "sign_usage_example"}
    ]
  end
end
