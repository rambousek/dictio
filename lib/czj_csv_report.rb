require_relative "czj_api_helper"

# CSV assembly for the /:dict/csvreport export (moved verbatim from the route)
module CzjCsvReport
  module_function

  def sign_csv(dict, code, entries)
    csv = ['ID;video čelní;video boční;orient;překlady;překlady text;fsw;synonyma;varianty;sl.druh;sl.druh2;sl.druh3']
    entries.each{|rep|
      ri = [rep['id']]
      ri << rep['lemma']['video_front'].to_s
      ri << rep['lemma']['video_side'].to_s
      if rep['lemma']['video_front'].to_s == ''
        ri << ''
      else
        ri << CzjApiHelper.video_orient(dict.get_media_location(rep['lemma']['video_front'].to_s, code))
      end
      rels = []
      relst = []
      if rep['meanings']
        rep['meanings'].each{|rm|
          if rm['relation']
            rm['relation'].each{|rel|
              if rel['type'] == 'translation'
                rels << rel['target'] + ':' + rel['meaning_id']
                if rel['entry'] and rel['entry']['lemma'] and rel['entry']['lemma']['title']
                  relst << rel['target'] + ':' + rel['entry']['lemma']['title'].to_s
                end
              end
            }
          end
        }
      end
      ri << rels.join(',')
      ri << relst.join(',')
      if rep['lemma']['swmix']
        sws = []
        rep['lemma']['swmix'].each{|sw|
          sws << sw['@fsw']
        }
        ri << sws.join(',')
      elsif rep['lemma']['sw']
        sws = []
        rep['lemma']['sw'].each{|sw|
          sws << sw['@fsw']
        }
        ri << sws.join(',')
      end
      # synonyma
      syns = []
      if rep['meanings']
      rep['meanings'].each{|rm|
        if rm['relation']
          rm['relation'].select{|rel| rel['type'] == 'synonym'}.each{|rr|
            syns << rr['meaning_id'].split('-')[0]
          }
        end
      }
      end
      ri << syns.join(',')
      # varianty
      vars = []
      if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0]['variant']
        rep['lemma']['grammar_note'][0]['variant'].each{|var|
          vars << var['_text'] if var['_text']
        }
      end
      if rep['lemma']['style_note'] and rep['lemma']['style_note'][0]['variant']
        rep['lemma']['style_note'][0]['variant'].each{|var|
          vars << var['_text'] if var['_text']
        }
      end
      ri << vars.join(',')
      # slovni druh
      pos = ''
      pos2 = ''
      pos3 = ''
      if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0]
        if rep['lemma']['grammar_note'][0]['@slovni_druh']
          pos = rep['lemma']['grammar_note'][0]['@slovni_druh']
        end
        if rep['lemma']['grammar_note'][0]['@skupina']
          pos2 = rep['lemma']['grammar_note'][0]['@skupina']
        end
        if rep['lemma']['grammar_note'][0]['@skupina2']
          pos3 = rep['lemma']['grammar_note'][0]['@skupina2']
        end
      end
      ri << pos
      ri << pos2
      ri << pos3

      csv << ri.join(';')
    }
    csv
  end

  def write_csv(entries)
    csv = ['ID;lemma;slovní druh;význam ID;definice;zdroj definice;*příklad ID;*příklad;*zdroj příkladu;překlady;překlady text']
    entries.each{|rep|
      if rep['meanings'] and rep['meanings'].size > 0
        rep['meanings'].each{|rm|
          ri = [rep['id']]
          ri << rep['lemma']['title']
          ri << rep['lemma']['grammar_note'][0]['@slovni_druh'].to_s if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0]
          ri << rm['id']
          ri << rm['text']['_text'].to_s.gsub("\n"," ") if rm['text']
          ri << rm['id']['source']
          ri << []
          ri << []
          ri << []
          rels = []
          relst = []
          if rm['relation']
            rm['relation'].each{|rel|
              if rel['type'] == 'translation'
                rels << rel['target'] + ':' + rel['meaning_id']
                if rel['entry'] and rel['entry']['lemma'] and rel['entry']['lemma']['title']
                  relst << rel['target'] + ':' + rel['entry']['lemma']['title'].to_s
                end
              end
            }
          end
          ri << rels.join(',')
          ri << relst.join(',')
          csv << ri.join(';')
        }
      else
        ri = [rep['id']]
        ri << rep['lemma']['title']
        ri << rep['lemma']['grammar_note'][0]['@slovni_druh'].to_s if rep['lemma']['grammar_note'] and rep['lemma']['grammar_note'][0]
        csv << ri.join(';')
      end
    }
    csv
  end
end
