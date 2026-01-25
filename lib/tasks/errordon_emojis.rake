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
      { shortcode: 'neon', file: 'neon.svg', category: 'Matrix' },
      { shortcode: 'synthwave', file: 'synthwave.svg', category: 'Matrix' },
      { shortcode: 'hologram', file: 'hologram.svg', category: 'Matrix' },
      
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
      { shortcode: 'tor', file: 'tor.svg', category: 'Hacker' },
      { shortcode: 'vpn', file: 'vpn.svg', category: 'Hacker' },
      { shortcode: 'ssh', file: 'ssh.svg', category: 'Hacker' },
      { shortcode: 'darknet', file: 'darknet.svg', category: 'Hacker' },
      { shortcode: 'exploit', file: 'exploit.svg', category: 'Hacker' },
      { shortcode: 'overflow', file: 'overflow.svg', category: 'Hacker' },
      { shortcode: 'injection', file: 'injection.svg', category: 'Hacker' },
      { shortcode: 'phishing', file: 'phishing.svg', category: 'Hacker' },
      
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
      { shortcode: 'hacker_cat', file: 'hacker_cat.svg', category: 'Nerd' },
      { shortcode: 'night_owl', file: 'night_owl.svg', category: 'Nerd' },
      { shortcode: 'headphones', file: 'headphones.svg', category: 'Nerd' },
      
      # Coding/Programming
      { shortcode: 'python', file: 'python.svg', category: 'Coding' },
      { shortcode: 'javascript', file: 'javascript.svg', category: 'Coding' },
      { shortcode: 'rust', file: 'rust.svg', category: 'Coding' },
      { shortcode: 'docker', file: 'docker.svg', category: 'Coding' },
      { shortcode: 'linux', file: 'linux.svg', category: 'Coding' },
      { shortcode: 'vim', file: 'vim.svg', category: 'Coding' },
      { shortcode: 'emacs', file: 'emacs.svg', category: 'Coding' },
      { shortcode: 'api', file: 'api.svg', category: 'Coding' },
      { shortcode: 'json', file: 'json.svg', category: 'Coding' },
      { shortcode: 'regex', file: 'regex.svg', category: 'Coding' },
      { shortcode: 'null', file: 'null.svg', category: 'Coding' },
      { shortcode: 'undefined', file: 'undefined.svg', category: 'Coding' },
      { shortcode: 'commit', file: 'commit.svg', category: 'Coding' },
      { shortcode: 'merge', file: 'merge.svg', category: 'Coding' },
      { shortcode: 'branch', file: 'branch.svg', category: 'Coding' },
      { shortcode: 'pull_request', file: 'pull_request.svg', category: 'Coding' },
      { shortcode: 'opensource', file: 'opensource.svg', category: 'Coding' },
      { shortcode: 'foss', file: 'foss.svg', category: 'Coding' },
      { shortcode: 'debug', file: 'debug.svg', category: 'Coding' },
      { shortcode: 'segfault', file: 'segfault.svg', category: 'Coding' },
      { shortcode: 'bash', file: 'bash.svg', category: 'Coding' },
      { shortcode: 'zsh', file: 'zsh.svg', category: 'Coding' },
      { shortcode: 'root', file: 'root.svg', category: 'Coding' },
      { shortcode: 'chmod', file: 'chmod.svg', category: 'Coding' },
      { shortcode: 'ping', file: 'ping.svg', category: 'Coding' },
      { shortcode: '404', file: '404.svg', category: 'Coding' },
      { shortcode: '500', file: '500.svg', category: 'Coding' },
      { shortcode: '200', file: '200.svg', category: 'Coding' },
      
      # Hardware
      { shortcode: 'cpu', file: 'cpu.svg', category: 'Hardware' },
      { shortcode: 'ram', file: 'ram.svg', category: 'Hardware' },
      { shortcode: 'gpu', file: 'gpu.svg', category: 'Hardware' },
      { shortcode: 'server', file: 'server.svg', category: 'Hardware' },
      { shortcode: 'database', file: 'database.svg', category: 'Hardware' },
      { shortcode: 'raspberry_pi', file: 'raspberry_pi.svg', category: 'Hardware' },
      { shortcode: 'arduino', file: 'arduino.svg', category: 'Hardware' },
      { shortcode: 'usb', file: 'usb.svg', category: 'Hardware' },
      { shortcode: 'ethernet', file: 'ethernet.svg', category: 'Hardware' },
      
      # Coffee & Energy
      { shortcode: 'coffee', file: 'coffee.svg', category: 'Coffee' },
      { shortcode: 'espresso', file: 'espresso.svg', category: 'Coffee' },
      { shortcode: 'latte', file: 'latte.svg', category: 'Coffee' },
      { shortcode: 'energy_drink', file: 'energy_drink.svg', category: 'Coffee' },
      { shortcode: 'pizza', file: 'pizza.svg', category: 'Coffee' },
      
      # CCC / Chaos
      { shortcode: 'ccc', file: 'ccc.svg', category: 'CCC' },
      { shortcode: 'chaos', file: 'chaos.svg', category: 'CCC' },
      { shortcode: 'hackspace', file: 'hackspace.svg', category: 'CCC' },
      { shortcode: 'soldering', file: 'soldering.svg', category: 'CCC' },
      
      # Cyberpunk / Gaming
      { shortcode: 'cyborg', file: 'cyborg.svg', category: 'Cyberpunk' },
      { shortcode: 'ai', file: 'ai.svg', category: 'Cyberpunk' },
      { shortcode: 'neural', file: 'neural.svg', category: 'Cyberpunk' },
      { shortcode: 'blockchain', file: 'blockchain.svg', category: 'Cyberpunk' },
      { shortcode: 'crypto', file: 'crypto.svg', category: 'Cyberpunk' },
      { shortcode: 'vr', file: 'vr.svg', category: 'Cyberpunk' },
      { shortcode: 'retro', file: 'retro.svg', category: 'Cyberpunk' },
      { shortcode: 'pixel', file: 'pixel.svg', category: 'Cyberpunk' },
      { shortcode: 'arcade', file: 'arcade.svg', category: 'Cyberpunk' },
      { shortcode: 'gamepad', file: 'gamepad.svg', category: 'Cyberpunk' },
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
      matrix_code red_pill blue_pill skull_matrix matrix_cat glitch neon synthwave hologram
      hacker terminal binary encrypt access_granted access_denied anonymous wifi_hack firewall sudo
      tor vpn ssh darknet exploit overflow injection phishing
      nerd keyboard code bug cyber_eye robot coffee_code git loading hacker_cat night_owl headphones
      python javascript rust docker linux vim emacs api json regex null undefined
      commit merge branch pull_request opensource foss debug segfault bash zsh root chmod ping
      404 500 200
      cpu ram gpu server database raspberry_pi arduino usb ethernet
      coffee espresso latte energy_drink pizza
      ccc chaos hackspace soldering
      cyborg ai neural blockchain crypto vr retro pixel arcade gamepad
    ]

    puts "Removing Errordon custom emojis..."
    
    deleted = CustomEmoji.where(shortcode: shortcodes, domain: nil).destroy_all
    puts "Deleted #{deleted.count} emojis"

    # Clean up empty categories
    CustomEmojiCategory.where(name: %w[Matrix Hacker Nerd Coding Hardware Coffee CCC Cyberpunk]).each do |cat|
      cat.destroy if cat.custom_emojis.count.zero?
    end
  end
end
