module SearchHelper
    require 'rexml/document'
  
    def log_search_not_found(search_value)
      xml_file_path = Rails.root.join('log', 'search_log.xml')
  
      begin
        # Otevření nebo vytvoření XML souboru
        xml_doc = if File.exist?(xml_file_path)
                    REXML::Document.new(File.read(xml_file_path))
                  else
                    REXML::Document.new.tap do |doc|
                      doc.add_element('searches')
                    end
                  end
  
        # Získání kořene dokumentu
        root = xml_doc.root || xml_doc.add_element('searches')
  
        # Najít existující záznam
        existing_entry = root.elements.to_a('search').find { |e| e.attributes['value'] == search_value }
  
        if existing_entry
          # Zvýšení četnosti
          existing_entry.attributes['count'] = existing_entry.attributes['count'].to_i + 1
        else
          # Přidání nového záznamu
          root.add_element('search', { 'value' => search_value, 'count' => 1 })
        end
  
        # Zápis změn zpět do souboru
        File.open(xml_file_path, 'w') do |file|
          xml_doc.write(file, 2)
        end
      rescue => e
        Rails.logger.error("Error logging search: #{e.message}")
      end
    end
  end