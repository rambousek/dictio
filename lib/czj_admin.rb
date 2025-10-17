## Main class for admin backend
class CzjAdmin < Object
  attr_reader :info_count, :duplicate
  def initialize
    @info_count = CzjAdminInfo
    @duplicate = CzjAdminDuplicate
  end
end
