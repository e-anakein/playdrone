class Crawler::Category < Crawler::Base
  def crawl
    session.queryCategories.to_ruby['categories'].each { |c| process c }
  end

  def process(category, parent=nil)
    cat = ::Category.new(:category_id => category['categoryId'],
                         :title       => category['title'],
                         :app_type    => parse_app_type(category['appType']),
                         :parent      => parent)
    cat.upsert

    if category['subCategories']
      category['subCategories'].each { |c| process c, cat }
    end
  end

  def parse_app_type(app_type)
    case app_type
    when 0 then :none
    when 1 then :app
    when 2 then :ringtone
    when 3 then :wallpaper
    when 4 then :game
    else :unkown
    end
  end
end
