class CzjApp < Sinatra::Base
  get '/' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    stat = $mongo['entryStat'].find({}, :sort=>{'dateField'=>-1}).first
    @count_entry = stat['entries'][0]['count']
    @count_rels = ((stat['rel'][0]['count'].to_i+stat['usgrel'][0]['count'].to_i)/2).round
    @params = params
    @top_searched, @top_displayed = CzjUsageStat.homepage_top
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, 'index')
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim :home
  end

  get '/about' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'about'
    page = 'about-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/help' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'help'
    page = 'help-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/helpsign' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'help'
    page = 'helpsign-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/contact' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'contact'
    page = 'contact-'+I18n.locale.to_s
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end
end
