# document composition for the /:dict/json/:id endpoint
module CzjEntryJson
  module_function

  def build_doc(dict, dict_array, code, params, add_rev)
    if params['history'].to_s != '' and params['historytype'].to_s != ''
      change = CzjHistory.get_history(params['history'])
      if params['historytype'].to_s == 'old'
        if change['full_entry_old']
          doc = change['full_entry_old']
        else
          doc = nil
        end
      else
        doc = change['full_entry']
      end
      doc = dict_array[code].full_entry(doc, false)
      doc = dict_array[code].add_rels(doc, false)
    else
      doc = dict.getdoc(params['id'], add_rev)
    end
    doc
  end

  def user_list(users, code)
    users.
      select{|x| x['lang'].nil? or x['lang'].length == 0 or x['lang'].include?(code)}.
      collect{|x| [x['login']]}
  end
end
