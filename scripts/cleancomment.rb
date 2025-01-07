#!/usr/bin/ruby

require 'rubygems'
require 'mongo'
require 'json'
require 'bson'
require 'open-uri'

Mongo::Logger.logger.level = Logger::WARN
$mongo = Mongo::Client.new(['localhost'], :database => 'dictio')


def getone(dict, id)
  data = $mongo['entries'].find({'id': id, 'dict': dict, 'empty': {'$exists': false}}).first
  return data
end

# return true = delete koment
def checkdeletebox(box, entry)
  entrys = entry.to_s
  case box
    when 'boxlemma','gramdesc','styldesc','boxcolloc','swfieldset','hamnbox'
      return false
    when /^video(.*)/
      if not entrys.include?('"' + $1 + '"')
        return true
      end
    when /[0-9]_us[0-9]/
      if not entrys.include?('"' + box + '"')
        return true
      end
    when /^meaning(.*)rel(..)(.*)/
      if not entry['meanings']
        return true
      end
      if not entry['meanings'].find{|hash| hash['id'] == $1}
        return true
      end
      mean = entry['meanings'].select{|hash| hash['id'] == $1}[0]
      if not mean['relation']
        return true
      end
      if not mean['relation'].find{|hash| hash['meaning_id'] == $3 and hash['target'] == $2}
        return true
      end
    when /^vyznam(.*)vazby/
      if not entry['meanings']
        return true
      end
      if not entry['meanings'].find{|hash| hash['id'] == $1}
        return true
      end
      if not entry['meanings'].select{|hash| hash['id'] == $1}[0]['relation']
        return true
      end
    when /^vyznam(.*)/
      if not entry['meanings']
        return true
      end
      if not entry['meanings'].find{|hash| hash['id'] == $1}
        return true
      end
    else
      puts box
  end
  return false
end

def deletekoment(id)
  $mongo['koment'].find({'_id':BSON::ObjectId.from_string(id)}).delete_many
end

$mongo['koment'].find().each{|kom|
  entry = getone(kom['dict'], kom['entry'])
  if entry.nil?
    deletekoment(kom['_id'])
  else
    if checkdeletebox(kom['box'], entry)
      deletekoment(kom['_id'])
    end
  end
}

