# Administrative operations: entry deletion/id generation, untranslated-relation reports.
module CzjDictAdmin
  def delete_doc(entry_id)
    $mongo['relation'].find({'source_dict': @dictcode, 'source_id': entry_id}).delete_many
    $mongo['relation'].find({'target': @dictcode, 'target_id': entry_id}).delete_many
    @entrydb.find({'dict'=>@dictcode, 'id'=>entry_id}).delete_many
  end

  #get new max id
  def get_new_id
    cursor = @entrydb.find({'dict' => @dictcode}, {:projection => {'id':1}, :collation => {'locale' => 'cs', 'numericOrdering'=>true}, :sort => {'id' => -1}})
    cursor = cursor.limit(1)
    newid = 1
    cursor.each{|r|
      newid = r['id'].to_i + 1
    }
    doc = {'dict' => @dictcode, 'id' => newid.to_s, 'empty' => true}
    @entrydb.insert_one(doc)
    newid
  end

  def get_relation_notrans(user = '')
    res = {'notrans' => [], 'count'=>0}
    @entrydb.find({'meanings.relation': {'$elemMatch': {'notrans': true, 'target': @dictcode}}}).each{|re|
      re['meanings'].each{|rm|
        if rm['relation']
          rm['relation'].each{|rr|
            if rr['notrans'] and rr['notrans'] == true and rr['target'] == @dictcode and (user == '' or rr['notransuser'].start_with?(user+' '))
              ren = {'id' => re['id'], 'dict' => re['dict']}
              ren['relation'] = {'meaning' => rm['id'], 'target' => rr['target'], 'trans' => rr['meaning_id'], 'notransuser' => rr['notransuser']}
              comm = @comments.get_comments(re['dict'], re['id'], 'meaning'+rm['id']+'rel'+rr['target']+rr['meaning_id'])[:comments]
              ren['comment'] = comm[0] if comm.size > 0
              res['notrans'] << ren
            end
          }
        end
      }
    }
    res
  end

  def get_relation_notrans2(user = '')
    res = {'notrans' => [], 'count'=>0}
    @entrydb.find({'dict': @dictcode, 'meanings.relation.notrans': true}).each{|re|
      re['meanings'].each{|rm|
        if rm['relation']
          rm['relation'].each{|rr|
            if rr['notrans'] and rr['notrans'] == true and (user == '' or rr['notransuser'].start_with?(user+' '))
              ren = {'id' => re['id'], 'dict' => re['dict']}
              ren['relation'] = {'meaning' => rm['id'], 'target' => rr['target'], 'trans' => rr['meaning_id'], 'notransuser' => rr['notransuser']}
              comm = @comments.get_comments(re['dict'], re['id'], 'meaning'+rm['id']+'rel'+rr['target']+rr['meaning_id'])[:comments]
              ren['comment'] = comm[0] if comm.size > 0
              res['notrans'] << ren
            end
          }
        end
      }
    }
    res
  end

end
