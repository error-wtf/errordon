# frozen_string_literal: true

# Errordon Privacy Preset
# Strict privacy-first defaults inspired by chaos.social
#
# Configure via ENV variables:
#   ERRORDON_PRIVACY_PRESET=strict  (or 'standard' for Mastodon defaults)
#
# Individual overrides:
#   ERRORDON_DEFAULT_VISIBILITY=unlisted|public|private
#   ERRORDON_DEFAULT_DISCOVERABLE=false|true
#   ERRORDON_DEFAULT_INDEXABLE=false|true
#   ERRORDON_DEFAULT_HIDE_NETWORK=true|false

Rails.application.config.to_prepare do
  preset = ENV.fetch('ERRORDON_PRIVACY_PRESET', 'strict')

  if preset == 'strict'
    # Apply strict privacy defaults to User model
    User.class_eval do
      after_initialize :apply_errordon_privacy_defaults, if: :new_record?

      def apply_errordon_privacy_defaults
        # Default post visibility
        self.settings ||= {}
        self.settings['default_privacy'] ||= ENV.fetch('ERRORDON_DEFAULT_VISIBILITY', 'unlisted')

        # Account settings (applied via account association)
        return unless account.present? && account.new_record?

        account.discoverable = ENV.fetch('ERRORDON_DEFAULT_DISCOVERABLE', 'false') == 'true'
        account.indexable = ENV.fetch('ERRORDON_DEFAULT_INDEXABLE', 'false') == 'true'
        account.hide_collections = ENV.fetch('ERRORDON_DEFAULT_HIDE_NETWORK', 'true') == 'true'
      end
    end

    Rails.logger.info '[Errordon] Privacy preset: STRICT mode enabled'
    Rails.logger.info "[Errordon] Default visibility: #{ENV.fetch('ERRORDON_DEFAULT_VISIBILITY', 'unlisted')}"
    Rails.logger.info "[Errordon] Default discoverable: #{ENV.fetch('ERRORDON_DEFAULT_DISCOVERABLE', 'false')}"
    Rails.logger.info "[Errordon] Default indexable: #{ENV.fetch('ERRORDON_DEFAULT_INDEXABLE', 'false')}"
    Rails.logger.info "[Errordon] Default hide_network: #{ENV.fetch('ERRORDON_DEFAULT_HIDE_NETWORK', 'true')}"
  else
    Rails.logger.info '[Errordon] Privacy preset: STANDARD mode (Mastodon defaults)'
  end
end
