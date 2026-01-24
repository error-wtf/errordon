# frozen_string_literal: true

namespace :errordon do
  desc 'Import Errordon custom emojis (Matrix/Hacker/Nerd themed)'
  task import_emojis: :environment do
    emoji_dir = Rails.public_path.join('emoji', 'errordon')
    
    unless Dir.exist?(emoji_dir)
      puts "Error: Emoji directory not found at #{emoji_dir}"
      exit 1
    end

    # Define Errordon custom emojis with their shortcodes and categories
    emojis = [
      # Matrix themed
      { shortcode: 'matrix_code', file: 'matrix_code.svg', category: 'Matrix' },
      { shortcode: 'red_pill', file: 'red_pill.svg', category: 'Matrix' },
      { shortcode: 'blue_pill', file: 'blue_pill.svg', category: 'Matrix' },
      { shortcode: 'skull_matrix', file: 'skull_matrix.svg', category: 'Matrix' },
      { shortcode: 'matrix_cat', file: 'matrix_cat.svg', category: 'Matrix' },
      { shortcode: 'glitch', file: 'glitch.svg', category: 'Matrix' },
      
      # Hacker themed
      { shortcode: 'hacker', file: 'hacker.svg', category: 'Hacker' },
      { shortcode: 'terminal', file: 'terminal.svg', category: 'Hacker' },
      { shortcode: 'binary', file: 'binary.svg', category: 'Hacker' },
      { shortcode: 'encrypt', file: 'encrypt.svg', category: 'Hacker' },
      { shortcode: 'access_granted', file: 'access_granted.svg', category: 'Hacker' },
      { shortcode: 'access_denied', file: 'access_denied.svg', category: 'Hacker' },
      { shortcode: 'anonymous', file: 'anonymous.svg', category: 'Hacker' },
      { shortcode: 'wifi_hack', file: 'wifi_hack.svg', category: 'Hacker' },
      { shortcode: 'firewall', file: 'firewall.svg', category: 'Hacker' },
      { shortcode: 'sudo', file: 'sudo.svg', category: 'Hacker' },
      
      # Nerd/Dev themed
      { shortcode: 'nerd', file: 'nerd.svg', category: 'Nerd' },
      { shortcode: 'keyboard', file: 'keyboard.svg', category: 'Nerd' },
      { shortcode: 'code', file: 'code.svg', category: 'Nerd' },
      { shortcode: 'bug', file: 'bug.svg', category: 'Nerd' },
      { shortcode: 'cyber_eye', file: 'cyber_eye.svg', category: 'Nerd' },
      { shortcode: 'robot', file: 'robot.svg', category: 'Nerd' },
      { shortcode: 'coffee_code', file: 'coffee_code.svg', category: 'Nerd' },
      { shortcode: 'git', file: 'git.svg', category: 'Nerd' },
      { shortcode: 'loading', file: 'loading.svg', category: 'Nerd' },
    ]

    created = 0
    skipped = 0
    errors = 0

    puts "Importing Errordon custom emojis..."
    puts "=" * 50

    emojis.each do |emoji_data|
      file_path = emoji_dir.join(emoji_data[:file])
      
      unless File.exist?(file_path)
        puts "  [SKIP] #{emoji_data[:shortcode]} - file not found: #{emoji_data[:file]}"
        skipped += 1
        next
      end

      # Check if emoji already exists
      existing = CustomEmoji.find_by(shortcode: emoji_data[:shortcode], domain: nil)
      if existing
        puts "  [SKIP] :#{emoji_data[:shortcode]}: - already exists"
        skipped += 1
        next
      end

      # Find or create category
      category = CustomEmojiCategory.find_or_create_by!(name: emoji_data[:category])

      # Create the emoji
      begin
        emoji = CustomEmoji.new(
          shortcode: emoji_data[:shortcode],
          domain: nil,
          category: category,
          visible_in_picker: true
        )
        
        emoji.image = File.open(file_path)
        emoji.save!
        
        puts "  [OK] :#{emoji_data[:shortcode]}: (#{emoji_data[:category]})"
        created += 1
      rescue => e
        puts "  [ERROR] :#{emoji_data[:shortcode]}: - #{e.message}"
        errors += 1
      end
    end

    puts "=" * 50
    puts "Import complete!"
    puts "  Created: #{created}"
    puts "  Skipped: #{skipped}"
    puts "  Errors:  #{errors}"
  end

  desc 'Remove all Errordon custom emojis'
  task remove_emojis: :environment do
    shortcodes = %w[
      matrix_code red_pill blue_pill skull_matrix matrix_cat glitch
      hacker terminal binary encrypt access_granted access_denied anonymous wifi_hack firewall sudo
      nerd keyboard code bug cyber_eye robot coffee_code git loading
    ]

    puts "Removing Errordon custom emojis..."
    
    deleted = CustomEmoji.where(shortcode: shortcodes, domain: nil).destroy_all
    puts "Deleted #{deleted.count} emojis"

    # Clean up empty categories
    CustomEmojiCategory.where(name: %w[Matrix Hacker Nerd]).each do |cat|
      cat.destroy if cat.custom_emojis.count.zero?
    end
  end
end
