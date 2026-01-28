# Bootstrap federation by resolving accounts and following some
# This pulls in posts from the federated timeline

# More popular accounts to resolve
accounts_to_resolve = [
  'stux@mstdn.social',
  'nixCraft@mastodon.social',
  'fediverse@mastodon.social',
  'feditips@mstdn.social',
  'joinmastodon@mastodon.social'
]

puts "Resolving more accounts..."
accounts_to_resolve.each do |acct|
  begin
    account = ResolveAccountService.new.call(acct, skip_webfinger: false)
    puts "  #{acct}: #{account ? 'OK' : 'FAILED'}"
  rescue => e
    puts "  #{acct}: Error - #{e.message[0..50]}"
  end
end

# Have the local admin follow Gargron to pull in posts
local_account = Account.find_local('error')
if local_account
  gargron = Account.find_by(username: 'Gargron', domain: 'mastodon.social')
  if gargron
    begin
      FollowService.new.call(local_account, gargron)
      puts "\n@error is now following @Gargron@mastodon.social!"
    rescue => e
      puts "\nFollow failed: #{e.message}"
    end
  end
end

puts "\nFinal stats:"
puts "  Known instances: #{Instance.count}"
puts "  Remote accounts: #{Account.where.not(domain: nil).count}"
puts "  Remote statuses: #{Status.where(local: false).count}"
