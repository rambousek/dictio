# frozen_string_literal: true

require "net/http"
require "uri"
require "zlib"

class CzjVideoExport
  MAX_ARCHIVE_SIZE = 1024**3
  MAX_ESTIMATED_SIZE = 750 * 1024**2
  MAX_VIDEOS = 2_000
  FRONT_SIDE_AVERAGE_SIZE = 3 * 1024**2 / 2
  DEFINITION_EXAMPLE_AVERAGE_SIZE = 4 * 1024**2

  class LimitExceeded < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code)
    end
  end

  def initialize(dict, filters, user_info, selections, downloader: nil,
                 max_archive_size: MAX_ARCHIVE_SIZE, max_estimated_size: MAX_ESTIMATED_SIZE,
                 max_videos: MAX_VIDEOS)
    @dict = dict
    @filters = filters
    @user_info = user_info
    @selections = selections
    @downloader = downloader || method(:download_video)
    @max_archive_size = max_archive_size
    @max_estimated_size = max_estimated_size
    @max_videos = max_videos
  end

  def write(path)
    media = selected_videos
    raise LimitExceeded.new("estimated_size_limit") if estimated_size(media) > @max_estimated_size

    zip = ZipWriter.new(path, max_size: @max_archive_size, max_entries: @max_videos)
    begin
      media.each do |video|
        location = video["location"].to_s
        zip.add(location) { |write_chunk| @downloader.call(@dict.dictcode, location, write_chunk) }
      end
      zip.close
    rescue
      zip.abort
      raise
    end
  end

  private

  def selected_videos
    query, = REPORTS.get_search_cond(@dict, @filters, @user_info)
    selected = {}
    $mongo["entries"].find(
      {"$and" => query},
      :collation => {"locale" => "cs", "numericOrdering" => true},
      :sort => {"id" => 1}
    ).each do |entry|
      selected_media(entry).each do |media|
        location = media["location"].to_s
        next unless valid_location?(location)

        existing = selected[location]
        if existing.nil? || estimated_size([media]) > estimated_size([existing])
          selected[location] = media
        end
        raise LimitExceeded.new("video_count_limit") if selected.length > @max_videos
      end
    end
    selected.values
  end

  def estimated_size(media)
    media.sum do |video|
      case video["type"]
      when "sign_front", "sign_side"
        FRONT_SIDE_AVERAGE_SIZE
      when "sign_definition", "sign_usage_example"
        DEFINITION_EXAMPLE_AVERAGE_SIZE
      else
        DEFINITION_EXAMPLE_AVERAGE_SIZE
      end
    end
  end

  def selected_media(entry)
    found = {}
    lemma = entry["lemma"] || {}

    all_types = []
    if @selections["front"]
      if @selections["front_all"]
        all_types << "sign_front"
      else
        add_media(found, [{"location" => lemma["video_front"], "type" => "sign_front"}])
      end
    end
    if @selections["side"]
      if @selections["side_all"]
        all_types << "sign_side"
      else
        add_media(found, [{"location" => lemma["video_side"], "type" => "sign_side"}])
      end
    end
    add_media(found, media_by_type(entry, all_types)) unless all_types.empty?

    if @selections["definition"] || @selections["examples"]
      linked_media = Hash.new { |hash, type| hash[type] = [] }
      (entry["meanings"] || []).each do |meaning|
        if @selections["definition"]
          linked_media["sign_definition"].concat(media_ids(meaning["text"]))
        end
        if @selections["examples"]
          (meaning["usages"] || []).each do |usage|
            linked_media["sign_usage_example"].concat(media_ids(usage["text"]))
          end
        end
      end
      media_ids = linked_media.values.flatten.uniq
      unless media_ids.empty?
        media = $mongo["media"].find({
          "dict" => @dict.dictcode,
          "id" => {"$in" => media_ids},
          "type" => {"$in" => linked_media.keys}
        }).to_a
        add_media(found, media)
      end
    end

    found.values
  end

  def media_by_type(entry, types)
    clauses = [{"entry_folder" => entry["id"].to_s}]
    folder_id = entry.dig("lemma", "media_folder_id").to_s
    clauses << {"media_folder_id" => folder_id} unless folder_id.empty?
    $mongo["media"].find({
      "dict" => @dict.dictcode,
      "type" => {"$in" => types},
      "$or" => clauses
    }).to_a
  end

  def add_media(found, media)
    media.each do |item|
      location = item["location"].to_s
      found[location] = item if valid_location?(location)
    end
  end

  def media_ids(text)
    return [] unless text.is_a?(Hash)

    files = text["file"]
    files = [files] if files.is_a?(Hash)
    return [] unless files.is_a?(Array)

    files.filter_map do |file|
      file["@media_id"] if file.is_a?(Hash)
    end
  end

  def valid_location?(location)
    !location.empty? && location != "." && location != ".." &&
      !location.include?("/") && !location.include?("\\") && !location.match?(/[\x00-\x1f\x7f]/)
  end

  def download_video(dict_code, location, write_chunk)
    uri = URI("https://files.dictio.info/video#{dict_code}/#{URI::DEFAULT_PARSER.escape(location)}")
    request = Net::HTTP::Get.new(uri)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true, :open_timeout => 10, :read_timeout => 60) do |http|
      http.request(request) do |response|
        raise "Video download failed (HTTP #{response.code}): #{location}" unless response.is_a?(Net::HTTPSuccess)

        response.read_body { |chunk| write_chunk.call(chunk) }
      end
    end
  end

  class ZipWriter
    END_OF_CENTRAL_DIRECTORY_SIZE = 22
    CENTRAL_DIRECTORY_HEADER_SIZE = 46
    DATA_DESCRIPTOR_SIZE = 16

    def initialize(path, max_size:, max_entries:)
      @file = File.open(path, "wb")
      @entries = []
      @central_size = 0
      @max_size = max_size
      @max_entries = max_entries
    end

    def add(name)
      name_bytes = name.encode(Encoding::UTF_8).b
      raise "ZIP entry name is too long" if name_bytes.bytesize > 0xffff
      raise LimitExceeded.new("video_count_limit") if @entries.length >= @max_entries

      offset = @file.pos
      @file.write([0x04034b50, 20, 0x808, 0, 0, 0x21, 0, 0, 0, name_bytes.bytesize, 0].pack("VvvvvvVVVvv"))
      @file.write(name_bytes)

      crc = 0
      size = 0
      reserved_directory_size = @central_size + CENTRAL_DIRECTORY_HEADER_SIZE +
        name_bytes.bytesize + END_OF_CENTRAL_DIRECTORY_SIZE
      yield lambda { |chunk|
        size += chunk.bytesize
        if @file.pos + chunk.bytesize + DATA_DESCRIPTOR_SIZE + reserved_directory_size > @max_size
          raise LimitExceeded.new("size_limit")
        end

        crc = Zlib.crc32(chunk, crc)
        @file.write(chunk)
      }

      @file.write([0x08074b50, crc, size, size].pack("VVVV"))
      @entries << [name_bytes, crc, size, offset]
      @central_size += CENTRAL_DIRECTORY_HEADER_SIZE + name_bytes.bytesize
    end

    def close
      central_offset = @file.pos
      if central_offset + @central_size + END_OF_CENTRAL_DIRECTORY_SIZE > @max_size
        raise LimitExceeded.new("size_limit")
      end

      @entries.each do |name, crc, size, offset|
        @file.write([
          0x02014b50, 20, 20, 0x808, 0, 0, 0x21, crc, size, size,
          name.bytesize, 0, 0, 0, 0, 0, offset
        ].pack("VvvvvvvVVVvvvvvVV"))
        @file.write(name)
      end
      @file.write([0x06054b50, 0, 0, @entries.length, @entries.length, @central_size, central_offset, 0].pack("VvvvvVVv"))
      @file.close
    end

    def abort
      @file.close unless @file.closed?
    end
  end
end
