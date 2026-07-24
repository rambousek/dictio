# Bulk import workflow: file upload handling and running imports of sign/translation entries.
module CzjImport
  def self.handle_upload(filedata, dir)
    if not filedata.nil? and not filedata['filename'].nil? and filedata['filename'] != '' and not filedata['tempfile'].nil?
      fn = filedata['filename']
      fn = fn[0,2] + fn[2..-1].gsub('_','')
      filepath = dir + '/' + fn
      $stdout.puts filepath
      #zip?
      if filedata['filename'][-4..-1] == '.zip'
        system('unzip "' + filedata['tempfile'].path + '" -d "' + dir+'"')
        Dir.entries(dir).each{|dir_fn|
          if dir_fn.end_with?('mp4')
            File.rename(dir+"/"+dir_fn, dir+"/"+dir_fn[0,2] + dir_fn[2..-1].gsub('_',''))
          end
        }
      else
        FileUtils.cp(filedata['tempfile'].path, filepath)
      end
    end
  end

  def handle_upload_write(filedata, user, logid)
    logname = 'logs/czjimport'+logid+'.log'
    logfile = File.open(logname, 'w')
    logfile.puts Time.now.to_s
    logfile.puts user
    if not filedata.nil? and not filedata['filename'].nil? and filedata['filename'] != '' and not filedata['tempfile'].nil?
      filedata['tempfile'].each{|line|
        line = line.force_encoding('utf-8').gsub('"','').gsub("\xEF\xBB\xBF".force_encoding("UTF-8"), '')
        next if line.strip == ""
        info = line.strip.split(';')
        next if info.count < 2
        next if info[1] == ""
        next if info[0] == "ID"
        # got ID?
        entry = {}
        if info[0] != ""
          entry = getdoc(info[0])
        end
        if entry == {}
          if info[0] != ""
            eid = info[0]
          else
            eid = get_new_id
          end
          entry = {"id" => eid.to_s, "dict" => @dictcode, "type" => "write", "lemma" => {}}
          if info[1] != ""
            entry["lemma"]["title"] = info[1].to_s
          end
          entry["lemma"]["created_at"] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
          logfile.puts 'new entry ' + @dictcode + ' ' + eid.to_s + ' ' + info[1].to_s
        else
          eid = entry["id"]
          logfile.puts 'update entry ' + @dictcode + ' ' + eid.to_s 
        end
        unless entry['lemma']['grammar_note']
          entry['lemma']['grammar_note'] = []
        end
        if entry['lemma']['grammar_note'].length == 0
          entry['lemma']['grammar_note'] << {}
        end
        if info[2] != ""
          entry['lemma']['grammar_note'][0]['@slovni_druh'] = info[2]
        end
        unless entry["meanings"]
          entry["meanings"] = []
        end
        if info[3] != "" and info[3] =~ /[0-9]+-[0-9]+/
          found_mean = false
          entry["meanings"].each{|m|
            if m["id"] == info[3]
              found_mean = true
              m['updated_at'] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
              m['text'] = {"_text" => info[4].to_s}
              m['source'] = info[5].to_s
              if info[6].to_s != ""
                new_usg = {"id" => m["id"].to_s+"_us0", "text" => {"_text" => info[6].to_s}, "source" => info[7].to_s}
                unless m['usages']
                  m['usages'] = []
                end
                m['usages'].push(new_usg)
              end
            end
          }
          unless found_mean
            new_mean = { "id" => info[3].to_s, "number" => info[3].to_s.split("-")[1], "text" => { "_text" => info[4].to_s }, "source" => info[5].to_s, "usages" => [] }
            new_mean["updated_at"] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
            if info[6].to_s != ""
              new_usg = { "id" => info[3].to_s + "_us0", "text" => { "_text" => info[6].to_s }, "source" => info[7].to_s }
              new_mean["usages"].push(new_usg)
            end
            entry["meanings"].push(new_mean)
          end
        else
          mnum = 0
          mid = 0
          entry["meanings"].each{|m|
            if m["number"].to_i > mnum
              mnum = m["number"].to_i
            end
            if m["id"].split("-")[1].to_i > mid
              mid = m["id"].split("-")[1].to_i
            end
          }
          mnum += 1
          mid += 1
          new_mean = {"id" => eid.to_s+"-"+mid.to_s, "number" => mnum, "text" => {"_text" => info[4].to_s}, "source" => info[5].to_s, "usages" => []}
          new_mean["updated_at"] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
          if info[6].to_s != ""
            new_usg = {"id" => eid.to_s+"-"+mid.to_s+"_us0", "text" => {"_text" => info[6].to_s}, "source" => info[7].to_s}
            new_mean["usages"].push(new_usg)
          end
          entry["meanings"].push(new_mean)
        end
        entry["lemma"]["updated_at"] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        $stderr.puts entry
        @entrydb.find({'dict': @dictcode, 'id': eid}).delete_many
        @entrydb.insert_one(entry)
      }
    end
    logfile.puts 'finished'
    logfile.close
  end

  def self.get_import_files(dir)
    importfiles = []
    meta = {}
    gotmeta = false
    if File.exist?(File.join(dir, 'meta.csv'))
      gotmeta = true
      fmeta = File.open(File.join(dir, 'meta.csv'))
      fmeta.each{|lm|
        ma = lm.strip.split(';')
        mrow = {}
        mrow['eid'] = ma[0] if ma[0].to_s != ''
        mrow['orient'] = ma[3] if ma[3].to_s != ''
        mrow['autor'] = ma[4] if ma[4].to_s != ''
        mrow['video'] = ma[5] if ma[5].to_s != ''
        mrow['zdroj'] = ma[6] if ma[6].to_s != ''
        mrow['preklad'] = ma[7] if ma[7].to_s != ''
        if ma[1].to_s != ''
          videofile = ma[1].to_s.gsub(/[^-^\._[[:alnum:]]]/, '')
          meta[videofile] = mrow
        end
        if ma[2].to_s != ''
          videofile = ma[2].to_s.gsub(/[^-^\._[[:alnum:]]]/, '')
          meta[videofile] = mrow
        end
        if ma[8].to_s != ''
          videofile = ma[8].to_s.gsub(/[^-^\._[[:alnum:]]]/, '')
          meta[videofile] = mrow
        end
        if ma[9].to_s != ''
          videofile = ma[9].to_s.gsub(/[^-^\._[[:alnum:]]]/, '')
          meta[videofile] = mrow
        end
      }
    end
    Dir.entries(dir).each{|fn|
      if fn.end_with?('mp4')
        label = CzjEditMedia.norm_name(fn)[0]
        data = {
          'filename'=> fn,
          'label' => label,
          'trans' => label.split('==')[0]
        }
        if meta.key?(fn)
          data['trans'] = meta[fn]['preklad'] if meta[fn].key?('preklad')
          data['eid'] = meta[fn]['eid'] if meta[fn].key?('eid')
          data['orient'] = meta[fn]['orient'] if meta[fn].key?('orient')
          data['autor'] = meta[fn]['autor'] if meta[fn].key?('autor')
          data['video'] = meta[fn]['video'] if meta[fn].key?('video')
          data['zdroj'] = meta[fn]['zdroj'] if meta[fn].key?('zdroj')
        end
        importfiles << data
      end
    }
    [importfiles.sort { |a, b| [a['label'], a['filename']] <=> [b['label'], b['filename']] }, gotmeta]
  end

  def import_run(data, targetdict, not_createrel, user, logid)
    $stdout.puts logid
    $stdout.puts data
    $stdout.puts user
    $stdout.puts not_createrel
    logname = 'logs/czjimport'+logid+'.log'
    logfile = File.open(logname, 'w')
    logfile.puts Time.now.to_s
    logfile.puts data
    logfile.puts user

    trans = []
    used_trans = []
    sign = {}
    videos = {}
    data['files'].each{|_,h|
      h.update(h) {|_, v| v.to_s.strip.gsub("\xEF\xBB\xBF".force_encoding('UTF-8'), '')}
      # list sign entries
      if sign[h['label'].strip].nil?
        if h.key?('eid') and h['eid'] != ''
          sign[h['label'].strip] = {'id'=>h['eid'], 'new'=>false, 'video'=>[]}
        else
          newid = get_new_id
          sign[h['label'].strip] = {'id'=>newid, 'new'=>true, 'video'=>[]}
        end
      end
      sign[h['label'].strip]['video'] << h['file'].strip

      # list translations
      if not_createrel
        sign[h['label'].strip]['trans'] = h['trans'].strip
      else
        if targetdict and not used_trans.include?(h['trans'].strip)
          tranid = targetdict.get_new_id
          trans << {'id'=>tranid, 'title'=>h['trans'].strip, 'rel'=>h['label'].strip}
          sign[h['label'].strip]['trans'] = tranid
          used_trans << h['trans'].strip
        end
      end

      # save video metadata
      media = {}
      media['dict'] = @dictcode
      media['location'] = h['file'].strip
      media['original_file_name'] = h['file'].strip
      media['label'] = h['label'].to_s
      case h['file'][0]
      when 'A'
        media['type'] = 'sign_front'
        media['main_for_entry'] = sign[h['label'].strip]['id']
      when 'B'
        media['type'] = 'sign_side'
        media['main_for_entry'] = sign[h['label'].strip]['id']
      when 'D'
        media['type'] = 'sign_definition'
      when 'K'
        media['type'] = 'sign_usage_example'
      when 'G'
        media['type'] = 'sign_grammar'
      when 'S'
        media['type'] = 'sign_style'
      else
        media['type'] = ''
      end
      media['status'] = 'hidden'
      media['orient'] = 'P'
      media['orient'] = h['orient'] if h.key?('orient') and h['orient'] != ''
      media['id_meta_copyright'] = h['video'] if h.key?('video')
      media['id_meta_author'] = h['zdroj'] if h.key?('zdroj')
      media['id_meta_source'] = h['autor'] if h.key?('autor')
      media['created_at'] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      vid = @edit_media.save_media(media)
      videos[h['file'].strip] = vid
    }

    $stdout.puts trans
    $stdout.puts sign
    $stdout.puts videos

    # prepare write entries
    write_entries = []
    if targetdict and not not_createrel
      trans.each{|t|
        logfile.puts 'new entry ' + data['targetdict'] + ' ' + t['id'].to_s + ' - ' + t['title']
        entry = {
          'id' => t['id'].to_s,
          'dict' => data['targetdict'],
          'lemma' => {
            'title' => t['title'],
            'completeness' => '0',
            'status' => 'hidden',
            'title_dia' => t['title'],
            'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            'lemma_type' => 'single'
          },
          'type' => 'write',
          'meanings' => [
            {
              'id' => t['id'].to_s + '-1',
              'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
              'relation' => [
                {
                  'target' => data['srcdict'],
                  'meaning_id' => sign[t['rel'].to_s]['id'].to_s + '-1',
                  'type' => 'translation',
                  'status' => 'hidden'
                }
              ]
            }
          ]
        }

        write_entries << entry
      }

      logfile.puts 'writing text entries to db'
      $mongo['entries'].insert_many(write_entries)
    end
    $stdout.puts write_entries

    # prepare sign entries
    sign_entries = []
    sign_to_delete = []
    sign.each{|_, h|
      next if sign_to_delete.member?(h['id'])
      unless h['new']
        entry = getdoc(h['id'])
        if entry == {}
          h['new'] = true
        else
          logfile.puts 'update entry ' + data['srcdict'] + ' ' + h['id'].to_s
          sign_to_delete << h['id']
        end
      end
      if h['new']
        logfile.puts 'new entry ' + data['srcdict'] + ' ' + h['id'].to_s 
        entry = {
          'id' => h['id'].to_s,
          'dict' => @dictcode,
          'type' => 'sign',
          'lemma' => {
            'completeness' => '0',  
            'status' => 'hidden',
            'pracskupina' => 'vut_me',
            'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            'lemma_type' => 'single'
          },
          'meanings' => []
        }
      end
      # add videos
      h['video'].sort.each{|f|
        mid = 0
        uid = 0
        case f[0]
        when 'A'
          entry['lemma']['video_front'] = f
        when 'B'
          entry['lemma']['video_side'] = f
        when 'D'
          mid += 1
          newm = {
            'id' => h['id'].to_s + '-' + mid.to_s,
            'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            'text' => {'file' => {'@media_id' => videos[f].to_s}}
          }
          if mid == 1
            newm['usages'] = []
          end
          entry['meanings'] << newm
        when 'K'
          if entry['meanings'].length == 0
            entry['meanings'] << {
              'id' => h['id'].to_s + '-1',
              'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
              'usages' => []
            }
          end
          uid += 1
          newu = {
            'id' => h['id'].to_s + '-1_us' + uid.to_s,
            'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            'text' => {'file' => {'@media_id' => videos[f].to_s}}
          }
          unless entry['meanings'][0].has_key?('usages')
            entry['meanings'][0]['usages'] = []
          end
          entry['meanings'][0]['usages'] << newu
        else
          # type code here
        end
      }

        # no meanings?
        if entry['meanings'].length == 0
          entry['meanings'] << {
            'id' => h['id'].to_s + '-1',
            'created_at' => Time.now.strftime("%Y-%m-%d %H:%M:%S")
          }
        end
        if targetdict
          # add translation
          if not_createrel
            entry['meanings'][0]['relation'] = [
              {
                'target' => data['targetdict'],
                'meaning_id' => h['trans'].to_s,
                'type' => 'translation',
                'status' => 'hidden'
              }
            ]
          else
            entry['meanings'][0]['relation'] = [
              {
                'target' => data['targetdict'],
                'meaning_id' => h['trans'].to_s + '-1',
                'type' => 'translation',
                'status' => 'hidden'
              }
            ]
          end
        end

      sign_entries << entry
    }
    $stdout.puts sign_entries
    $mongo['entries'].find({'dict'=>@dictcode, 'id': {'$in': sign_to_delete}}).delete_many
    logfile.puts 'writing sign entries to db'
    $mongo['entries'].insert_many(sign_entries)

    # upload files
    logfile.puts 'uploading files'
    videos.each{|file, _|
      fpath = data['dir'] + '/' + file
      $stdout.puts file
      $stdout.puts fpath
      logfile.puts file
      Net::SSH.start("files.dictio.info", $files_user, :key_data=>$files_keys){|ssh|
        ssh.scp.upload!(fpath, '/home/adam/upload/'+@dictcode+'/'+file)
        command = '/home/adam/mkthumb.sh "'+file+'" "'+@dictcode+'"'
        $stdout.puts command
        ssh.exec(command)
      }
    }

    # cache relations
    logfile.puts 'caching relations'
    sign_entries.each{|en| cache_relations(en, false)}
    write_entries.each{|en| cache_relations(en, false)}

    logfile.puts 'finished'
    logfile.close
  end

end
