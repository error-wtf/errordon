# Add popular Mastodon relays for federation
relays = [
  'https://relay.mastodon.host/inbox',
  'https://relay.toot.io/inbox'
]

relays.each do |url|
  r = Relay.find_or_create_by(inbox_url: url)
  r.update(state: :pending)
  puts "Relay added: #{url} (state: #{r.state})"
end

puts "Total relays: #{Relay.count}"
