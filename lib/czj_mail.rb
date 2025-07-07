## Support method for email sending
require 'mail'

module CzjMail
  # @param [String] to_addr
  # @param [String] subject
  # @param [String] text
  # @param [String] from
  # @return [Mail::Message]
  def self.send_mail(to_addr, subject, text, from = "dictio@teiresias.muni.cz")
    mail = Mail.new do
      subject subject
      body text
      to to_addr
      from "DICTIO <" + from + ">"
    end
    mail.delivery_method :smtp, address: "relay.muni.cz", port: 25
    mail.deliver
  end

  # @param [String] template
  # @param [Hash] data
  # @return [[String, String]]
  def self.prepare_mail_text(template, data)
    path = File.join("mails", template + ".txt")
    if File.exist?(path)
      text = File.read(path).split("\n")
      subject = text[0].sub("Subject: ", "")
      message = text[1..-1].join("\n")
      message.gsub!('#{user}', data['login'])
      message.gsub!('#{email}', data['email'])
      message.gsub!('#{pass}', data['password'])
      perms = []
      perms_en = []
      skupiny = []
      skupiny_en = []
      data['editor'].each { |perm|
        perms.append(I18n.t('admin.users.editor.' + perm, :locale => 'cs'))
        perms_en.append(I18n.t('admin.users.editor.' + perm, :locale => 'en'))
      }
      data['revizor'].each { |perm|
        perms.append(I18n.t('admin.users.revizor.' + perm, :locale => 'cs'))
        perms_en.append(I18n.t('admin.users.revizor.' + perm, :locale => 'en'))
      }
      data['skupina'].each { |perm|
        skupiny.append(I18n.t('admin.group.' + perm, :locale => 'cs'))
        skupiny_en.append(I18n.t('admin.group.' + perm, :locale => 'en'))
      }
      message.gsub!('#{perms}', perms.join(', '))
      message.gsub!('#{skupiny}', skupiny.join(', '))
      message.gsub!('#{perms_en}', perms_en.join(', '))
      message.gsub!('#{skupiny_en}', skupiny_en.join(', '))
      [subject, message]
    else
      ["", ""]
    end
  end
end
