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
    @show_new_wordlist_form = params['create'] == 'true'
    slim :wordlists
  end

  get '/wordlists/users' do
    require_word_lists_host!
    query = params['query'].to_s.strip.downcase
    halt 400 if query.length < 2
    content_type :json
    users = CzjUsers.get_users.filter_map do |user|
      login = user['login'].to_s
      name = user['name'].to_s
      next if login == @user_info['login'].to_s
      next unless login.downcase.include?(query) || name.downcase.include?(query)

      {"login" => login, "name" => name}
    end
    users.first(20).to_json
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
    wordlist = word_lists.find_accessible(params['wordlist_id'], @user_info['login'])
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
    @wordlist = word_lists.find_accessible(params['id'], @user_info['login'])
    halt 404 unless @wordlist
    @wordlist_owner = word_lists.owned_by?(@wordlist, @user_info['login'])
    prepare_word_lists_page(@wordlist['dict'])
    @entries = word_lists.entries_for(@wordlist)
    @wordlist_error = params['error']
    @sharing_updated = params['shared'] == 'true'
    @ownership_transferred = params['transferred'] == 'true'
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

  post '/wordlists/:id/sharing' do
    require_word_lists_host!
    verify_csrf_token!
    result = word_lists.update_sharing(params['id'], @user_info['login'], params['shared_with'])
    halt 404 if result == :not_found
    redirect "/wordlists/#{params['id']}?error=invalid_users" if result == :invalid_users
    redirect "/wordlists/#{params['id']}?shared=true"
  end

  post '/wordlists/:id/transfer' do
    require_word_lists_host!
    verify_csrf_token!
    result = word_lists.transfer_ownership(params['id'], @user_info['login'], params['new_owner_login'])
    halt 404 if result == :not_found
    redirect "/wordlists/#{params['id']}?error=invalid_owner" if result == :invalid_owner
    redirect "/wordlists/#{params['id']}?transferred=true"
  end

  post '/wordlists/:id/delete' do
    require_word_lists_host!
    verify_csrf_token!
    wordlist = word_lists.find_accessible(params['id'], @user_info['login'])
    halt 404 unless wordlist
    halt 403 unless word_lists.owned_by?(wordlist, @user_info['login'])
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
