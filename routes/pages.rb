class CzjApp < Sinatra::Base
  helpers do
    def localized_template(name)
      locale = %w[en cs].unshift(I18n.locale.to_s).uniq.find do |l|
        File.file?(File.join(settings.root, 'views', "#{name}-#{l}.slim"))
      end || 'cs'
      "#{name}-#{locale}"
    end
  end

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
    page = localized_template('about')
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/help' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'help'
    page = localized_template('help')
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/helpsign' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'help'
    page = localized_template('helpsign')
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

  get '/contact' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'contact'
    page = localized_template('contact')
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end

   get '/citace' do
    @dict_info = $dict_info
    @search_params = {}
    @request = request
    @selected_page = 'citace'
    page = localized_template('citace')
    @cite_attr = CzjWebHelper.get_cite_attr('page', request.path_info, @selected_page)
    @cite_text = CzjWebHelper.build_cite(@cite_attr)
    slim page.to_sym
  end
end
