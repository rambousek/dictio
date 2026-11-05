# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"

# Disk-backed background export jobs. State lives in tmp/exports/ because
# puma runs several worker processes — the status/download request usually
# lands on a different worker than the one running the job, so nothing may
# be kept in process memory.
module CzjExportJob
  DIR = File.join(Dir.getwd, "tmp", "exports")
  MAX_AGE = 24 * 60 * 60
  ID_RE = /\A\h{16}\z/

  # Runs the given block in a background thread, storing its string result
  # on disk. Returns the job id immediately.
  def self.start(user:, filename:, content_type:, &block)
    FileUtils.mkdir_p(DIR)
    cleanup
    id = SecureRandom.hex(8)
    write_meta(id,
      "status" => "running",
      "user" => user.to_s,
      "filename" => filename,
      "content_type" => content_type,
      "created" => Time.now.to_i)
    Thread.new do
      meta = read_meta(id)
      begin
        File.write(data_path(id), block.call)
        write_meta(id, meta.merge("status" => "done"))
      rescue => e
        warn "export job #{id} failed: #{e.message}\n" + e.backtrace.join("\n")
        write_meta(id, meta.merge("status" => "error"))
      end
    end
    id
  end

  # Runs a background export that writes its result directly to disk.
  def self.start_file(user:, filename:, content_type:, admin_only: false, &block)
    FileUtils.mkdir_p(DIR)
    cleanup
    id = SecureRandom.hex(8)
    write_meta(id,
      "status" => "running",
      "user" => user.to_s,
      "filename" => filename,
      "content_type" => content_type,
      "admin_only" => admin_only,
      "created" => Time.now.to_i)
    Thread.new do
      meta = read_meta(id)
      begin
        block.call(data_path(id))
        raise "Export produced no file" unless File.file?(data_path(id))

        write_meta(id, meta.merge("status" => "done"))
      rescue => e
        File.delete(data_path(id)) if File.exist?(data_path(id))
        warn "export job #{id} failed: #{e.message}\n" + e.backtrace.join("\n")
        error = e.respond_to?(:code) ? e.code : nil
        write_meta(id, meta.merge("status" => "error", "error" => error))
      end
    end
    id
  end

  # @return [Hash, nil] job metadata, nil for unknown/invalid id
  def self.meta(id)
    return nil unless ID_RE.match?(id.to_s)
    read_meta(id)
  end

  def self.data_path(id)
    File.join(DIR, id + ".data")
  end

  def self.meta_path(id)
    File.join(DIR, id + ".meta.json")
  end

  def self.read_meta(id)
    JSON.parse(File.read(meta_path(id)))
  rescue Errno::ENOENT
    nil
  end

  # Rename is atomic, so a concurrent status request never sees a half-written file.
  def self.write_meta(id, meta)
    tmp = meta_path(id) + ".tmp"
    File.write(tmp, meta.to_json)
    File.rename(tmp, meta_path(id))
  end

  def self.cleanup
    Dir.glob(File.join(DIR, "*")).each do |file|
      File.delete(file) if File.file?(file) && File.mtime(file) < Time.now - MAX_AGE
    rescue Errno::ENOENT
    end
  end
end
