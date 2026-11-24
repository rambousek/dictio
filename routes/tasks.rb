class CzjApp < Sinatra::Base
  helpers do
    def assigned_tasks_for_current_user
      return [] unless @user_info

      $mongo["tasks"].find(
        {"assigned_login" => @user_info["login"].to_s},
        :sort => {"created_at" => -1}
      ).to_a
    end

    def require_task_access!
      halt 404 unless protected_host?
      halt 403 unless @user_info
    end

    def require_task_creation_access!
      require_task_access!
      halt 403 unless can_edit_entries?
    end

    def find_task_for_user!(id)
      task = $mongo["tasks"].find({"_id" => id.to_s}).first
      halt 404 unless task
      current_login = @user_info["login"].to_s
      allowed = task["created_by"].to_s == current_login || task["assigned_login"].to_s == current_login || @user_info["admin"]
      halt 403 unless allowed
      task
    end

    def refresh_task_entry_count!(task)
      dict = $dict_array[task["dict"]]
      return nil unless dict
      query_string = task["report_url"].to_s.split("?", 2)[1].to_s
      report_params = Rack::Utils.parse_nested_query(query_string)
      report = REPORTS.get_report(dict, report_params, @user_info, 0, 1)
      count = report["resultcount"].to_i
      $mongo["tasks"].update_one(
        {"_id" => task["_id"]},
        {"$set" => {"entry_count" => count}}
      )
      task["entry_count"] = count
    end

    def refresh_assigned_task_counts_for_user!(login)
      $mongo["tasks"].find({"assigned_login" => login.to_s}).each do |task|
        begin
          refresh_task_entry_count!(task)
        rescue StandardError => error
          $stderr.puts "task count refresh failed for #{task["_id"]}: #{error.message}"
        end
      end
    end

    def refresh_assigned_task_counts_if_due!
      return unless @user_info

      now = Time.now.to_i
      last_refresh = session[:task_count_refresh_at].to_i
      return if now - last_refresh < 300

      session[:task_count_refresh_at] = now
      refresh_assigned_task_counts_for_user!(@user_info["login"])
    end

    def prepare_task_form(task)
      @task = task
      @dict_info = $dict_info
      @dictcode = task["dict"]
      @target = ""
      @organizations = Array(CzjUsers.get_users).map { |user| user["organization"].to_s.strip }.reject(&:empty?).uniq.sort_by(&:downcase)
      assigned_login = task["assigned_login"].to_s
      @assigned_user = Array(CzjUsers.get_users).find { |user| user["login"].to_s == assigned_login } unless assigned_login.empty?
    end
  end

  get "/tasks" do
    require_task_access!
    current_login = @user_info["login"].to_s
    task_query = if @user_info["admin"]
                   {}
                 else
                   {"$or" => [{"created_by" => current_login}, {"assigned_login" => current_login}]}
                 end
    @tasks = $mongo["tasks"].find(task_query, :sort => {"created_at" => -1}).to_a
    @task_users = Array(CzjUsers.get_users).to_h do |user|
      [user["login"].to_s, [user["login"], user["name"]].compact.reject(&:empty?).join(" - ")]
    end
    @dict_info = $dict_info
    @dictcode = nil
    @target = ""
    slim :tasks
  end

  post "/tasks" do
    require_task_creation_access!
    verify_csrf_token!
    dict = params["dict"].to_s
    halt 404 unless $dict_info.key?(dict)
    report_url = params["report_url"].to_s
    halt 422 unless report_url.start_with?("/#{dict}/report") && !report_url.start_with?("//")

    entry_count = params["entry_count"].to_s.match?(/\A\d+\z/) ? params["entry_count"].to_i : 0
    task_id = BSON::ObjectId.new.to_s
    task = {
      "_id" => task_id,
      "dict" => dict,
      "report_url" => report_url,
      "title" => "",
      "entry_count" => entry_count,
      "created_by" => @user_info["login"].to_s,
      "created_at" => Time.now,
      "organization" => "",
      "assigned_login" => ""
    }
    $mongo["tasks"].insert_one(task)
    redirect to("/tasks/#{task_id}")
  end

  post "/tasks/:id/refresh-count" do
    require_task_access!
    verify_csrf_token!
    task = find_task_for_user!(params["id"])
    halt 404 unless refresh_task_entry_count!(task)
    redirect to("/tasks/#{task["_id"]}?count_updated=true")
  end

  get "/tasks/:id" do
    require_task_access!
    task = find_task_for_user!(params["id"])
    prepare_task_form(task)
    slim :task
  end

  post "/tasks/:id" do
    require_task_access!
    verify_csrf_token!
    task = find_task_for_user!(params["id"])
    title = params["title"].to_s.strip
    organization = params["organization"].to_s.strip
    assigned_login = params["assigned_login"].to_s.strip
    if !assigned_login.empty? && !Array(CzjUsers.get_users).any? { |user| user["login"].to_s == assigned_login }
      halt 422, "Unknown user"
    end
    $mongo["tasks"].update_one(
      {"_id" => task["_id"]},
      {"$set" => {"title" => title, "organization" => organization, "assigned_login" => assigned_login}}
    )
    redirect to("/tasks/#{task["_id"]}?saved=true")
  end
end
