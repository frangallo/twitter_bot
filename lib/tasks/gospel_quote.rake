namespace :gospel_quote do
  desc 'Fetch gospel, generate quote and image, and post it on Twitter'
  task post: :environment do
    GospelQuoteService.new.main
  end
end
