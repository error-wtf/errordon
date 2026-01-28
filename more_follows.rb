# Have error follow more accounts
local_account = Account.find_local('error')

if local_account
  # Follow all resolved remote accounts
  Account.where.not(domain: nil).each do |remote|
    begin
      FollowService.new.call(local_account, remote)
      puts "Following #{remote.acct}"
    rescue => e
      puts "Skip #{remote.acct}: #{e.message[0..30]}"
    end
  end
end

puts "\nPulling latest statuses from followed accounts..."
# Trigger fetching of recent statuses
Account.where.not(domain: nil).limit(10).each do |account|
  begin
    ActivityPub::FetchRemoteAccountService.new.call(account.uri, only_key: false)
  rescue => e
    # ignore
  end
end

puts "\nFinal: #{Status.where(local: false).count} remote statuses"
