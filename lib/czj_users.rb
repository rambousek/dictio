# User account management and settings.
require "digest"
require "json"
require "net/http"
require "uri"

module CzjUsers
  extend self

  REGISTRATION_TOKEN_TTL = 24 * 60 * 60
  REGISTRATION_EMAIL_LIMIT = 3
  REGISTRATION_EMAIL_WINDOW = 24 * 60 * 60
  PASSWORD_RESET_TOKEN_TTL = 60 * 60
  PASSWORD_ITERATIONS = 210_000

  def turnstile_site_key
    ENV.fetch("CLOUDFLARE_TURNSTILE_SITE_KEY", "").strip
  end

  def turnstile_configured?
    !turnstile_site_key.empty? && !ENV.fetch("CLOUDFLARE_TURNSTILE_SECRET_KEY", "").strip.empty?
  end

  def verify_turnstile(token, hostname:)
    return false unless turnstile_configured? && !token.to_s.empty?

    uri = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      "secret" => ENV.fetch("CLOUDFLARE_TURNSTILE_SECRET_KEY"),
      "response" => token.to_s
    )
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 3) do |http|
      http.request(request)
    end
    return false unless response.is_a?(Net::HTTPSuccess)

    result = JSON.parse(response.body)
    result["success"] == true && result["hostname"].to_s.downcase == hostname.to_s.downcase &&
      result["action"] == "register"
  rescue StandardError => e
    $stderr.puts "Cloudflare Turnstile verification failed: #{e.class}"
    false
  end

  def registration_rate_limited?(email, now: Time.now)
    normalized_email = email.to_s.strip.downcase
    return false if normalized_email.empty?

    window_start = (now.to_i / REGISTRATION_EMAIL_WINDOW) * REGISTRATION_EMAIL_WINDOW
    email_hash = Digest::SHA256.hexdigest(normalized_email)
    bucket_id = "#{email_hash}:#{window_start}"
    limits = $mongo["registration_limits"]
    limits.update_one(
      {"_id" => bucket_id},
      {
        "$inc" => {"count" => 1},
        "$setOnInsert" => {"expires_at" => Time.at(window_start + REGISTRATION_EMAIL_WINDOW)}
      },
      upsert: true
    )
    limits.find({"_id" => bucket_id}).first["count"].to_i > REGISTRATION_EMAIL_LIMIT
  end

  def ensure_indexes
    $mongo["users"].indexes.create_one({"activation_expires_at" => 1}, expire_after: 0)
    $mongo["registration_limits"].indexes.create_one({"expires_at" => 1}, expire_after: 0)
  rescue StandardError => e
    $stderr.puts "registration indexes setup failed: #{e.message}"
  end

  def password_digest(password)
    salt = SecureRandom.hex(16)
    digest = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, PASSWORD_ITERATIONS, 32, "sha256").unpack1("H*")
    "pbkdf2_sha256$#{PASSWORD_ITERATIONS}$#{salt}$#{digest}"
  end

  def password_valid?(password, stored_password)
    if stored_password.to_s.start_with?("pbkdf2_sha256$")
      algorithm, iterations, salt, expected = stored_password.split("$", 4)
      return false unless algorithm == "pbkdf2_sha256" && iterations.to_i == PASSWORD_ITERATIONS &&
                          salt.to_s.match?(/\A[0-9a-f]{32}\z/) && expected.to_s.match?(/\A[0-9a-f]{64}\z/)

      actual = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations.to_i, 32, "sha256").unpack1("H*")
      Rack::Utils.secure_compare(actual, expected)
    else
      stored_password = stored_password.to_s
      stored_password.length >= 2 && password.crypt(stored_password[0, 2]) == stored_password
    end
  end

  def register_user(login:, password:, password_confirmation:, name:, email:, organization: "")
    login = login.to_s.strip
    name = name.to_s.strip
    email = email.to_s.strip.downcase
    organization = organization.to_s.strip
    return :invalid_login unless login.match?(/\A[a-zA-Z0-9_.-]{3,32}\z/)
    return :invalid_name if name.empty? || name.length > 200
    return :invalid_email if email.length > 254 || !email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    return :short_password if password.to_s.length < 10
    return :long_password if password.to_s.length > 1024
    return :password_mismatch unless password == password_confirmation

    users = $mongo["users"]
    existing_login = users.find({"login" => login}).first
    existing_email = users.find({"email" => email}).first
    if existing_email && existing_email["login"] != login
      return :email_taken
    end
    if existing_login && (existing_login["email_verified"] != false || existing_login["email"].to_s.downcase != email)
      return :login_taken
    end

    token = SecureRandom.urlsafe_base64(32)
    user = {
      "login" => login,
      "password" => password_digest(password),
      "name" => name,
      "email" => email,
      "organization" => organization,
      "email_verified" => false,
      "activation_token_hash" => Digest::SHA256.hexdigest(token),
      "activation_expires_at" => Time.now + REGISTRATION_TOKEN_TTL,
      "skupina" => [],
      "copy" => "",
      "autor" => "",
      "zdroj" => "",
      "admin" => false,
      "editor" => [],
      "revizor" => [],
      "lang" => [],
      "default_dict" => "",
      "default_lang" => "cs",
      "edit_dict" => [],
      "edit_synonym" => false,
      "edit_trans" => false
    }

    if existing_login
      users.update_one({"login" => login}, {"$set" => user})
    else
      users.insert_one(user)
    end
    {"login" => login, "email" => email, "token" => token}
  end

  def activate_user(token)
    return false if token.to_s.empty?

    user = $mongo["users"].find(
      {"activation_token_hash" => Digest::SHA256.hexdigest(token.to_s)}
    ).first
    return false unless user && user["email_verified"] == false
    return false unless user["activation_expires_at"].is_a?(Time) &&
                        user["activation_expires_at"] > Time.now

    result = $mongo["users"].update_one(
      {"login" => user["login"], "email_verified" => false},
      {"$set" => {
        "email_verified" => true,
        "activation_token_hash" => nil,
        "activation_expires_at" => nil
      }}
    )
    result.matched_count.positive?
  end

  def create_password_reset(email)
    normalized_email = email.to_s.strip.downcase
    return nil if normalized_email.empty?

    user = $mongo["users"].find({}).find do |candidate|
      candidate["email"].to_s.downcase == normalized_email &&
        candidate["email_verified"] != false
    end
    return nil unless user

    token = SecureRandom.urlsafe_base64(32)
    expires_at = Time.now + PASSWORD_RESET_TOKEN_TTL
    result = $mongo["users"].update_one(
      {"login" => user["login"]},
      {"$set" => {
        "password_reset_token_hash" => Digest::SHA256.hexdigest(token),
        "password_reset_expires_at" => expires_at
      }}
    )
    return nil unless result.matched_count.positive?

    {"login" => user["login"], "email" => user["email"], "token" => token}
  end

  def reset_password(token, password, password_confirmation)
    return :invalid_token if token.to_s.empty?
    return :short_password if password.to_s.length < 10
    return :long_password if password.to_s.length > 1024
    return :password_mismatch unless password == password_confirmation

    token_hash = Digest::SHA256.hexdigest(token.to_s)
    user = $mongo["users"].find({"password_reset_token_hash" => token_hash}).first
    return :invalid_token unless user &&
      user["password_reset_expires_at"].is_a?(Time) &&
      user["password_reset_expires_at"] > Time.now &&
      user["email_verified"] != false

    result = $mongo["users"].update_one(
      {
        "login" => user["login"],
        "password_reset_token_hash" => token_hash,
        "password_reset_expires_at" => user["password_reset_expires_at"]
      },
      {"$set" => {
        "password" => password_digest(password),
        "password_reset_token_hash" => nil,
        "password_reset_expires_at" => nil
      }}
    )
    result.matched_count.positive? ? true : :invalid_token
  end

  def get_users
    res = []
    $mongo['users'].find({}, :sort => {'login' => 1}).each{|us|
      res << us
    }
    res
  end

  def wordlist_counts(logins)
    logins = Array(logins).map(&:to_s).reject(&:empty?).uniq
    return {} if logins.empty?

    $mongo["wordlists"].aggregate([
      {"$match" => {"owner_login" => {"$in" => logins}}},
      {"$group" => {"_id" => "$owner_login", "count" => {"$sum" => 1}}}
    ]).to_h { |row| [row["_id"], row["count"].to_i] }
  end

  def save_user(data)
    if data['login'].to_s != ''
      user = $mongo['users'].find({'login': data['login']}).first
      %w[email_verified activation_token_hash activation_expires_at].each do |field|
        data[field] = user[field] if user && user.key?(field)
      end
      subject = ""
      if data['password'].to_s == '' and user != nil
        subject, message = CzjMail::prepare_mail_text('changeuser', data)
        data['password'] = user['password']
      elsif data['password'].to_s != ''
        if user.nil?
          subject, message = CzjMail::prepare_mail_text('newuser', data)
        else
          subject, message = CzjMail::prepare_mail_text('newpass', data)
        end
        data['password'] = data['password'].crypt((Random.rand(1900)+100).to_s(16)[0,2])
      else
        data['password'] = (Random.rand(19000000)+200000000).to_s(16)
        subject, message = CzjMail::prepare_mail_text('newuser', data)
        data['password'] = data['password'].crypt((Random.rand(1900)+100).to_s(16)[0,2])
      end
      $mongo['users'].find({'login': data['login']}).delete_many
      $mongo['users'].insert_one(data)
      if subject != ""
        CzjMail::send_mail(data['email'], subject, message)
      end
      true
    else
      'chybí login'
    end
  end

  def delete_user(login)
    if login.to_s != ''
      user = $mongo['users'].find({'login': login.to_s}).first
      subject, message = CzjMail::prepare_mail_text('deluser', user)
      $mongo['users'].find({'login': login.to_s}).delete_many
      CzjMail::send_mail(user["email"], subject, message)
      true
    else
      'chybí login'
    end
  end

  def save_user_setting(user_info, new_info)
    user_data = $mongo['users'].find({'login': user_info['login']}).first
    if user_data.nil?
      false
    else
      if new_info['password'].to_s != ''
        user_data['password'] = new_info['password'].crypt((Random.rand(1900)+100).to_s(16)[0,2])
      end
      user_data['default_lang'] = new_info['default_lang'].to_s
      user_data['default_dict'] = new_info['default_dict'].to_s
      user_data['email'] = new_info['email'].to_s
      user_data['name'] = new_info['name'].to_s
      user_data['organization'] = new_info['organization'].to_s.strip
      user_data['edit_synonym'] = false
      user_data['edit_trans'] = false
      user_data['edit_dict'] = []
      user_data['edit_synonym'] = true if new_info['edit_synonym'].to_s == 'on'
      user_data['edit_trans'] = true if new_info['edit_trans'].to_s == 'on'
      $dict_info.each{|code, _|
        user_data['edit_dict'] << code if new_info['edit_dict_'+code].to_s == 'on'
      }
      updated_fields = user_data.reject { |key, _value| key == '_id' }
      result = $mongo['users'].update_one(
        {'login': user_info['login']},
        {'$set' => updated_fields}
      )
      result.matched_count.positive?
    end
  end
end
