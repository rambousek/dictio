# User account management and settings.
require "digest"

module CzjUsers
  extend self

  REGISTRATION_TOKEN_TTL = 24 * 60 * 60
  PASSWORD_ITERATIONS = 210_000

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

  def get_users
    res = []
    $mongo['users'].find({}, :sort => {'login' => 1}).each{|us|
      res << us
    }
    res
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
