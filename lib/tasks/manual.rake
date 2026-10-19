namespace :manual do
  desc 'Import docs/manual into a Help Center portal per account, as drafts (ACCOUNT_ID limits it to one account)'
  task import: :environment do
    accounts = ENV['ACCOUNT_ID'].present? ? Account.where(id: ENV.fetch('ACCOUNT_ID')) : Account.all
    accounts.find_each do |account|
      result = Manual::HelpCenterImporter.new(account).perform
      puts "Account #{account.id}: #{result ? result.inspect : 'no administrator, skipped'}"
    end
  end
end
