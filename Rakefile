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

  desc "Run the GospelSummaryService"
  task gospel_summary_service: :environment do
    require_relative './lib/gospel_summary_service'
    GospelSummaryService.new.main
  end

  desc "Run the MantraService"
  task mantra_service: :environment do
    require_relative './lib/mantra_service'
    MantraService.new.main
  end

  desc "Run the DailyApplicationService"
  task gospel_daily_application_service: :environment do
    require_relative './lib/gospel_daily_application_service'
    GoseplDailyApplicationService.new.main
  end

  desc "Follow users with the TwitterAutomationService"
  task follow_users: :environment do
    require_relative './lib/twitter_automation_service'
    TwitterAutomationService.new.follow_users
  end

  desc "Unfollow users with the TwitterAutomationService"
  task unfollow_users: :environment do
    require_relative './lib/twitter_automation_service'
    TwitterAutomationService.new.unfollow_users
  end
end
