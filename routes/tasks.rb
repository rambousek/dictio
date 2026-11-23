class CzjApp < Sinatra::Base
  helpers do
    def require_task_access!
      halt 404 unless protected_host?
      halt 403 unless @user_info && can_edit_entries?
    end

    def find_task_for_user!(id)
      task = $mongo["tasks"].find({"_id" => id.to_s}).first
      halt 404 unless task
      halt 403 unless task["created_by"].to_s == @user_info["login"].to_s || @user_info["admin"]
      task
    end

    def prepare_task_form(task)
      @task = task
      @dict_info = $dict_info
      @dictcode = task["dict"]
      @target = ""
      @organizations = Array(CzjUsers.get_users).map { |user| user["organization"].to_s.strip }.reject(&:empty?).uniq.sort_by(&:downcase)
      @task_users = Array(CzjUsers.get_users)
    end
  end

  post "/tasks" do
    require_task_access!
    verify_csrf_token!
    dict = params["dict"].to_s
    halt 404 unless $dict_info.key?(dict)
    report_url = params["report_url"].to_s
    halt 422 unless report_url.start_with?("/#{dict}/report") && !report_url.start_with?("//")

    task_id = BSON::ObjectId.new.to_s
    task = {
      "_id" => task_id,
      "dict" => dict,
      "report_url" => report_url,
      "created_by" => @user_info["login"].to_s,
      "created_at" => Time.now,
      "organization" => "",
      "assigned_login" => ""
    }
    $mongo["tasks"].insert_one(task)
    redirect to("/tasks/#{task_id}")
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
    organization = params["organization"].to_s.strip
    assigned_login = params["assigned_login"].to_s.strip
    if !assigned_login.empty? && !Array(CzjUsers.get_users).any? { |user| user["login"].to_s == assigned_login }
      halt 422, "Unknown user"
    end
    $mongo["tasks"].update_one(
      {"_id" => task["_id"]},
      {"$set" => {"organization" => organization, "assigned_login" => assigned_login}}
    )
    redirect to("/tasks/#{task["_id"]}?saved=true")
  end
end
