# Resolve popular accounts to start federation
accounts_to_resolve = [
  'Gargron@mastodon.social',
  'Mastodon@mastodon.social',
  'chaos@chaos.social'
]

accounts_to_resolve.each do |acct|
  begin
    puts "Resolving #{acct}..."
    account = ResolveAccountService.new.call(acct)
    if account
      puts "  Success: #{account.acct} (ID: #{account.id})"
    else
      puts "  Failed to resolve"
    end
  rescue => e
    puts "  Error: #{e.message}"
  end
end

# Check instance count
puts "\nTotal known instances: #{Instance.count}"
puts "Total remote accounts: #{Account.where.not(domain: nil).count}"
