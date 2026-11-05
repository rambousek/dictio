class CzjApp < Sinatra::Base
  helpers do
    def word_lists
      @word_lists ||= CzjWordLists.new
    end

    def prepare_word_lists_page(dictcode)
      @dict_info = $dict_info
      @dictcode = dictcode
      @target = ''
      @request = request
      @search_params = {}
    end

    def require_word_lists_host!
      halt 404 unless protected_host?
      protected!
    end
  end

  get '/wordlists' do
    require_word_lists_host!
    prepare_word_lists_page(@default_dict)
    @wordlists = word_lists.list_for(@user_info['login'])
    @wordlist_error = params['error']
    slim :wordlists
  end

  post '/wordlists' do
    require_word_lists_host!
    verify_csrf_token!
    wordlist = word_lists.create(@user_info['login'], params['name'], params['dict'])
    redirect '/wordlists?error=invalid' unless wordlist
    redirect "/wordlists/#{wordlist['_id']}"
  end

  post '/wordlists/add-entry' do
    require_word_lists_host!
    verify_csrf_token!
    wordlist = word_lists.find_owned(params['wordlist_id'], @user_info['login'])
    halt 404 unless wordlist && wordlist['dict'] == params['dict'].to_s
    result = word_lists.add_entry(wordlist['_id'], @user_info['login'], params['entry_id'])
    error = case result
            when :added then nil
            when :duplicate then 'duplicate'
            when :entry_not_found then 'entry_not_found'
            when :invalid_id then 'invalid_id'
            else 'not_found'
            end
    suffix = error ? "?error=#{error}" : '?wordlist_added=true'
    redirect "/#{wordlist['dict']}/show/#{params['entry_id']}#{suffix}"
  end

  get '/wordlists/:id' do
    require_word_lists_host!
    @wordlist = word_lists.find_owned(params['id'], @user_info['login'])
    halt 404 unless @wordlist
    prepare_word_lists_page(@wordlist['dict'])
    @entries = word_lists.entries_for(@wordlist)
    @wordlist_error = params['error']
    slim :wordlist
  end

  post '/wordlists/:id/update' do
    require_word_lists_host!
    verify_csrf_token!
    wordlist = word_lists.update(
      params['id'],
      @user_info['login'],
      name: params['name'],
      sort_mode: params['sort_mode'],
      second_language: params['second_language'],
      is_public: params['is_public'] == 'true'
    )
    redirect "/wordlists/#{params['id']}?error=invalid" unless wordlist
    redirect "/wordlists/#{wordlist['_id']}"
  end

  post '/wordlists/:id/name' do
    require_word_lists_host!
    verify_csrf_token!
    wordlist = word_lists.update_name(params['id'], @user_info['login'], params['name'])
    redirect "/wordlists/#{params['id']}?error=invalid" unless wordlist
    redirect "/wordlists/#{wordlist['_id']}"
  end

  post '/wordlists/:id/delete' do
    require_word_lists_host!
    verify_csrf_token!
    word_lists.delete(params['id'], @user_info['login'])
    redirect '/wordlists'
  end

  post '/wordlists/:id/entries' do
    require_word_lists_host!
    verify_csrf_token!
    results = word_lists.add_entries(params['id'], @user_info['login'], params['entry_id'])
    halt 404 unless results
    query = {
      "added" => results[:added],
      "duplicate" => results[:duplicate],
      "missing" => results[:entry_not_found],
      "invalid" => results[:invalid_id]
    }
    redirect "/wordlists/#{params['id']}?#{Rack::Utils.build_query(query)}"
  end

  post '/wordlists/:id/entries/:entry_id/remove' do
    require_word_lists_host!
    verify_csrf_token!
    word_lists.remove_entry(params['id'], @user_info['login'], params['entry_id'])
    redirect "/wordlists/#{params['id']}"
  end

  post '/wordlists/:id/entries/:entry_id/move/:direction' do
    require_word_lists_host!
    verify_csrf_token!
    word_lists.move_entry(params['id'], @user_info['login'], params['entry_id'], params['direction'])
    redirect "/wordlists/#{params['id']}"
  end

  get '/wordlist/:share_token' do
    halt 404 if protected_host?
    @wordlist = word_lists.find_public(params['share_token'])
    halt 404 unless @wordlist
    prepare_word_lists_page(@wordlist['dict'])
    @entries = word_lists.entries_for(@wordlist)
    slim :wordlist_public
  end
end
