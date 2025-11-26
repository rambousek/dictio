#!/usr/bin/ruby

require 'rubygems'
require 'mongo'
require 'json'
require 'bson'
require 'open-uri'

Mongo::Logger.logger.level = Logger::WARN
mongohost = ''
$mongo = Mongo::Client.new(mongohost)

$mongo['entries'].find({
  'dict': 'czj',
  'lemma.sw': {
    '$elemMatch': {
      '$or': [
        {'@fsw': {'$regex': 'S1...[0-7]'}},
        {'@fsw': {'$regex': 'S20[0-4].[0-7]'}},
        {'@fsw': {'$regex': 'S21[6789a-f]'}},
        {'@fsw': {'$regex': 'S22[0-9]'}},
      ]
    }
  }
 }).each do |entry|
  inc = false
  fsw = []
  entry['lemma']['sw'].each{|sw|
    sws = []
    # puts sw['@fsw']
    sw['@fsw'].scan(/(S1[0-9a-f][0-9a-f].[0-7])|(S20[0-4].[0-7])|(S21[6789a-f])|(S22[0-9])/).each { |match|
      match.each { |mm|
        if mm
          sws << mm[0,4]
        end
      }
    }
    if sws.uniq.length > 1
      inc = true
    end
    fsw << sw['@fsw']
  }
  tr = []
  entry['meanings'].each{|me|
    me['relation'].each{|rel|
      if rel['target'] == 'cs' and rel['status'] == 'published'
        if rel['meaning_id'].include?('-')
          rid = rel['meaning_id'].split('-')[0]
          $mongo['entries'].find({ 'dict': 'cs', 'id': rid}).each{|ren|
            tr << ren['lemma']['title']
          }
        else
          tr << rel['meaning_id']
        end
      end
    }
  }
  if inc
    puts entry['id'] + ';' + tr.join(',') +  ';' + fsw.join(',')
  end
end

