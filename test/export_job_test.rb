require_relative "test_helper"

# Background export: /:code/export/start spawns a thread, the frontend polls
# /:code/export/status/:id and downloads from /:code/export/download/:id.
class ExportJobTest < AppTest
  def wait_for_status(id, tries = 50)
    status = nil
    tries.times do
      get "/cs/export/status/#{id}"
      status = JSON.parse(last_response.body)["status"]
      break if status != "running"
      sleep 0.1
    end
    status
  end

  def test_full_cycle_matches_synchronous_export
    get "/cs/export/start"
    assert_predicate last_response, :ok?
    id = JSON.parse(last_response.body)["id"]
    assert_match(/\A\h{16}\z/, id)

    assert_equal "done", wait_for_status(id)

    get "/cs/export/download/#{id}"
    assert_predicate last_response, :ok?
    assert_includes last_response.headers["Content-Disposition"], "cs-export.json"
    entries = JSON.parse(last_response.body)
    refute_empty entries

    get "/cs/export"
    assert_equal JSON.parse(last_response.body), entries
  end

  def test_status_of_unknown_job
    get "/cs/export/status/deadbeefdeadbeef"
    assert_predicate last_response, :ok?
    assert_equal "unknown", JSON.parse(last_response.body)["status"]
  end

  def test_invalid_job_id_is_rejected
    get "/cs/export/status/..%2f..%2fetc%2fpasswd"
    refute_predicate last_response, :ok?
    get "/cs/export/download/not-a-job-id"
    assert_equal 404, last_response.status
  end

  def test_download_requires_matching_user
    id = CzjExportJob.start(user: "someone_else", filename: "x.json", content_type: "application/json") { "[]" }
    50.times do
      break if CzjExportJob.meta(id)["status"] != "running"
      sleep 0.1
    end
    get "/cs/export/download/#{id}"
    assert_equal 403, last_response.status
  end

  def test_failed_job_reports_error
    id = CzjExportJob.start(user: "", filename: "x.json", content_type: "application/json") { raise "boom" }
    assert_equal "error", wait_for_status(id)
    get "/cs/export/download/#{id}"
    assert_equal 404, last_response.status
  end
end
