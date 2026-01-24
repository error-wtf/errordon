# frozen_string_literal: true

# Errordon Theme Configuration
# Matrix-style cyberpunk theme for Errordon

Rails.application.config.to_prepare do
  # Default theme setting
  # Options: 'default', 'matrix', 'light'
  Errordon::THEME = ENV.fetch('ERRORDON_THEME', 'matrix').freeze

  # Theme configuration
  Errordon::THEME_CONFIG = {
    matrix: {
      name: 'Matrix',
      description: 'Cyberpunk hacker style with green glow',
      body_class: 'theme-matrix',
      colors: {
        primary: '#00ff00',
        background: '#000000',
        text: '#ffffff'
      }
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

  Rails.logger.info "[Errordon] Theme: #{Errordon::THEME}"
end
