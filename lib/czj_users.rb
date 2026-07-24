# User account management and settings.
module CzjUsers
  extend self

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
      user_data['edit_synonym'] = false
      user_data['edit_trans'] = false
      user_data['edit_dict'] = []
      user_data['edit_synonym'] = true if new_info['edit_synonym'].to_s == 'on'
      user_data['edit_trans'] = true if new_info['edit_trans'].to_s == 'on'
      $dict_info.each{|code, _|
        user_data['edit_dict'] << code if new_info['edit_dict_'+code].to_s == 'on'
      }
      $mongo['users'].find({'login': user_info['login']}).delete_many
      $mongo['users'].insert_one(user_data)
      true
    end
  end
end
