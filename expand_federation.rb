# Expand federation with more servers
# Resolve accounts from various popular Fediverse instances

accounts_to_resolve = [
  # German news/media
  'tagesschau@ard.social',
  'tagesschau@mastodon.social',
  'ZDF@zdf.social',
  'saborowski@ard.social',
  
  # Chaos Computer Club / chaos.social
  'ccc@chaos.social',
  'c3cert@chaos.social',
  'chaosradio@chaos.social',
  'fenon@chaos.social',
  
  # Tech
  'mozilla@mozilla.social',
  'linux@fosstodon.org',
  'opensource@fosstodon.org',
  
  # General popular
  'Gargron@mastodon.social',
  'admin@mastodon.online',
  'stux@mstdn.social'
]

puts "Resolving #{accounts_to_resolve.length} accounts..."
resolved = 0
failed = 0

accounts_to_resolve.each do |acct|
  begin
    puts "  #{acct}..."
    account = ResolveAccountService.new.call(acct, skip_webfinger: false)
    if account
      puts "    OK: #{account.acct} (ID: #{account.id})"
      resolved += 1
    else
      puts "    FAILED: Could not resolve"
      failed += 1
    end
  rescue => e
    puts "    ERROR: #{e.message[0..60]}"
    failed += 1
  end
end

puts "\n=== Results ==="
puts "Resolved: #{resolved}"
puts "Failed: #{failed}"
puts "Known instances: #{Instance.count}"
puts "Remote accounts: #{Account.where.not(domain: nil).count}"
puts "Remote statuses: #{Status.where(local: false).count}"

# List known domains
puts "\nKnown domains:"
Instance.pluck(:domain).sort.each { |d| puts "  - #{d}" }
