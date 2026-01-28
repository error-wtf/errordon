# frozen_string_literal: true

# Errordon Theme Configuration
# Matrix-style cyberpunk theme for Errordon

Rails.application.config.to_prepare do
  # Default theme setting
  # Options: 'default', 'matrix', 'light'
  Errordon::THEME = ENV.fetch('ERRORDON_THEME', 'matrix').freeze

  # Matrix color variant (admin-configurable during install)
  # Options: 'green', 'red', 'blue', 'purple'
  Errordon::MATRIX_COLOR = ENV.fetch('MATRIX_COLOR', 'green').freeze

  # Validate color
  valid_colors = %w[green red blue purple]
  unless valid_colors.include?(Errordon::MATRIX_COLOR)
    Rails.logger.warn "[Errordon] Invalid MATRIX_COLOR '#{Errordon::MATRIX_COLOR}', defaulting to 'green'"
    Errordon::MATRIX_COLOR = 'green'.freeze
  end

  # Color palette definitions
  Errordon::MATRIX_COLORS = {
    green: {
      name: 'Green',
      description: 'Classic Matrix green',
      primary: '#00ff00',
      dark: '#00cc00',
      rgb: '0, 255, 0'
    },
    red: {
      name: 'Red',
      description: 'Aggressive red Matrix',
      primary: '#ff0000',
      dark: '#cc0000',
      rgb: '255, 0, 0'
    },
    blue: {
      name: 'Blue',
      description: 'Cyber blue Matrix',
      primary: '#00bfff',
      dark: '#0099cc',
      rgb: '0, 191, 255'
    },
    purple: {
      name: 'Purple',
      description: 'Cyberpunk purple Matrix',
      primary: '#bf00ff',
      dark: '#9900cc',
      rgb: '191, 0, 255'
    }
  }.freeze

  # Theme configuration
  Errordon::THEME_CONFIG = {
    matrix: {
      name: 'Matrix',
      description: 'Cyberpunk hacker style with customizable color',
      body_class: 'theme-matrix',
      colors: Errordon::MATRIX_COLORS[Errordon::MATRIX_COLOR.to_sym] || Errordon::MATRIX_COLORS[:green]
    },
    default: {
      name: 'Default',
      description: 'Standard Mastodon dark theme',
      body_class: '',
      colors: {
        primary: '#6364ff',
        background: '#191b22',
        text: '#ffffff'
      }
    },
    light: {
      name: 'Light',
      description: 'Light mode theme',
      body_class: 'theme-mastodon-light',
      colors: {
        primary: '#6364ff',
        background: '#ffffff',
        text: '#000000'
      }
    }
  }.freeze

  Rails.logger.info "[Errordon] Theme: #{Errordon::THEME}, Color: #{Errordon::MATRIX_COLOR}"
end
