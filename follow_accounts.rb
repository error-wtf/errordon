# Have error follow key accounts to pull in posts
local_account = Account.find_local('error')

if local_account
  # Follow accounts from key domains
  important_accounts = [
    'tagesschau@ard.social',
    'tagesschau@mastodon.social',
    'ZDF@zdf.social',
    'ccc@chaos.social',
    'c3cert@chaos.social',
    'chaosradio@chaos.social',
    'linux@fosstodon.org',
    'opensource@fosstodon.org',
    'stux@mstdn.social'
  ]

  important_accounts.each do |acct|
    remote = Account.find_by(username: acct.split('@')[0].downcase, domain: acct.split('@')[1])
    remote ||= Account.find_by(username: acct.split('@')[0], domain: acct.split('@')[1])
    
    if remote
      begin
        FollowService.new.call(local_account, remote)
        puts "Following: #{remote.acct}"
      rescue => e
        puts "Skip #{acct}: #{e.message[0..40]}"
      end
    else
      puts "Not found: #{acct}"
    end
  end
end

puts "\nTotal following: #{local_account.following_count}"
puts "Remote statuses: #{Status.where(local: false).count}"
