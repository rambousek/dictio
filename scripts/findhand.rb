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
  sws = []
  entry['lemma']['sw'].each{|sw|
    # puts sw['@fsw']
    sw['@fsw'].scan(/(S1[0-9a-f][0-9a-f].[0-7])|(S20[0-4].[0-7])|(S21[6789a-f])|(S22[0-9])/).each { |match|
      match.each { |mm|
        if mm
          sws << mm
        end
      }
    }
  }
  if sws.uniq.length > 1
    puts entry['id']
  end
end

