namespace :schedule do
  desc "Run the GospelQuoteService"
  task :gospel_quote_service => :environment do
    require_relative 'gospel_quote_service'
    GospelQuoteService.new.main
  end
end
