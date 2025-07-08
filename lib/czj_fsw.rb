## Helper methods for FSW
module CzjFsw
  # Convert SW to FSW
  # @param [String] swstring SW notation string
  # @return [String] FSW notation string
  def self.getfsw(swstring)
    fsw = 'M500x500'
    swa = []
    swstring.split('_').each { |e|
      match = /([0-9]*)(\(.*\))?/.match(e)
      unless match[1].nil?
        info = { 'id' => match[1], 'x' => 0, 'y' => 0 }
        unless match[2].nil?
          if match[2].include?('x') and match[2].include?('y')
            match2 = /\(x([\-0-9]*)y([\-0-9]*)\)/.match(match[2])
            info['x'] = match2[1].to_i
            info['y'] = match2[2].to_i
          elsif match[2].include?('x')
            info['x'] = match[2].gsub(/[^0-9^-]/, '').to_i
          else
            info['y'] = match[2].gsub(/[^0-9^-]/, '').to_i
          end
        end
        swa << info
      end
    }
    swa.each { |info|
      doc = $mongo['symbol'].find({ 'id' => info['id'] }).first
      fsw += 'S' + doc['bs_code'].to_i.to_s(16) + (doc['fill'].to_i - 1).to_s(16) + (doc['rot'].to_i - 1).to_s(16) + (info['x'] + 500).to_s + 'x' + (info['y'] + 500).to_s
    }
    URI.open('http://sign.dictio.info/fsw/sign/normalize/' + fsw, &:read) or ''
  end

  # Convert FSW to SW
  # @param [String] fswstring FSW notation string
  # @return [String] SW notation string
  def self.fromfsw(fswstring)
    swa = []
    match = /M([0-9]*)x([0-9]*)(S.*)/.match(fswstring)
    unless match.nil? or match[1].nil? or match[2].nil? or match[3].nil?
      match[3].split('S').each { |fs|
        next if fs == ''
        bs = fs[0..2].to_i(16)
        fil = fs[3..3].to_i(16) + 1
        rot = fs[4..4].to_i(16) + 1
        res = $mongo['symbol'].find({ 'bs_code' => bs.to_s, 'fill' => fil.to_s, 'rot' => rot.to_s })
        next if res.first.nil?
        doc = res.first
        match2 = /([0-9]*)x([0-9]*)/.match(fs[5..-1])
        x = match2[1].to_i - 500
        y = match2[2].to_i - 500
        swpos = ''
        if x != 0 or y != 0
          swpos = '('
          swpos += 'x' + x.to_s if x != 0
          swpos += 'y' + y.to_s if y != 0
          swpos += ')'
        end
        swa << doc['id'] + swpos
      }
    end
    swa.join('_')
  end
end
