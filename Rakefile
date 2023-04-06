# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

namespace :schedule do
  desc "Run the GospelQuoteService"
  task gospel_quote_service: :environment do
    require_relative './lib/gospel_quote_service'
    GospelQuoteService.new.main
  end
end
