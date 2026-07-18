require_relative 'czj_mail'
require_relative 'czj_search_query'
require_relative 'czj_edit_media'
require_relative 'czj_dict_sw'

require_relative 'czj_entry'
require_relative 'czj_media_helpers'
require_relative 'czj_search'
require_relative 'czj_save'
require_relative 'czj_relations'
require_relative 'czj_dict_admin'
require_relative 'czj_video_report'
require_relative 'czj_history'
require_relative 'czj_users'
require_relative 'czj_import'
require_relative 'czj_wordlist'

# CZJDict represents a single dictionary (identified by +dictcode+) and is the
# main entry point for reading, searching, editing and importing dictionary
# entries. The bulk of the behaviour lives in the CzjXxx modules included
# below; this class just wires them together and holds shared state
# (@entrydb, @sw, @edit_media, ...) that those modules rely on.
class CZJDict < Object
  include CzjEntry
  include CzjMediaHelpers
  include CzjSearchMethods
  include CzjSave
  include CzjRelations
  include CzjDictAdmin
  include CzjVideoReport
  include CzjImport
  include CzjWordlist

  attr_accessor :dictcode, :write_dicts, :sign_dicts, :dict_info, :sw, :comments, :edit_media
  attr_reader :wordlist

  def initialize(dictcode)
    @dictcode = dictcode 
    @entrydb = $mongo['entries']
    @sw = CzjDictSw.new(self)
    @edit_media = CzjEditMedia.new(self)
    Thread.new { build_wordlist }
  end
end
