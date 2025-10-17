## Main class for admin backend
class CzjAdmin < Object
  attr_reader :info_count
  def initialize
    @info_count = CzjAdminInfo
  end
end
