## Generate admin reports
class CzjReport
  attr_accessor :sign_dicts

  # find not solved comments by dictionary
  # @param [CZJDict] dict Dictionary object
  # @param [Hash] params
  def get_comment_report(dict, params)
    report = {'comments' => [], 'resultcount' => 0}
    query = {'$and' => [
      {'dict' => dict.dictcode},
      {'$or' => [
        {'solved' => ''},
        {'solved' => {'$exists' => false}}
      ]}
    ]}

    if params.include?('assign')
      case params['assign']
      when '_ass'
        query['$and'] << {'assign' => {'$exists'=>true, '$ne' => ''}}
      when '_not'
        query['$and'] << {'$or' => [
          {'assign' => ''},
          {'assign' => {'$exists' => false}}
        ]}
      when ''
      else
        query['$and'] << {'assign' => params['assign']}
      end
    end
    $stdout.puts query
    if params.include?('entry') and params['entry'] != ''
      query['entry'] = params['entry']
    end
    report['query'] = query
    cursor = $mongo['koment'].find(
      query,
      :collation => {'locale' => 'cs', 'numericOrdering'=>true},
      :sort => {'entry' => 1, 'assign' => 1}
    )
    report['resultcount'] = cursor.count_documents

    cursor.each{|kom|
      entry = dict.getone(kom['dict'], kom['entry'])
      {'video' => 'video ', 'vyznam' => 'význam '}.map{|k,v| kom['box'].sub!(k, v)}
      unless entry.nil?
        if @sign_dicts.include?(kom['dict'])
          kom['video'] = ''
          if entry['lemma'] and entry['lemma']['video_front']
            kom['video'] = entry['lemma']['video_front']
          end
        else
          kom['lemma'] = ''
          if entry['lemma'] and entry['lemma']['title']
            kom['lemma'] = entry['lemma']['title']
          end
        end
      end
      report['comments'] << kom
    }
    report
  end

end
