# frozen_string_literal: true

module Api
  module V1
    module Errordon
      # =============================================================================
      # GDPR SELF-SERVICE API
      # =============================================================================
      #
      # Provides GDPR Article 15-22 self-service endpoints:
      # - GET  /api/v1/errordon/gdpr/status    - Check deletion status
      # - GET  /api/v1/errordon/gdpr/data      - Request data summary
      # - POST /api/v1/errordon/gdpr/delete    - Request deletion
      # - POST /api/v1/errordon/gdpr/cancel    - Cancel deletion request
      #
      # All endpoints require authentication and rate limiting for security.
      # =============================================================================

      class GdprController < Api::BaseController
        before_action :require_user!
        before_action :set_account

        # Rate limiting for security (prevent abuse)
        RATE_LIMIT_REQUESTS = 5
        RATE_LIMIT_PERIOD = 1.hour

        # GET /api/v1/errordon/gdpr/status
        # Returns current GDPR status (deletion pending, data stats, etc.)
        def status
          render json: {
            account_id: @account.id,
            username: @account.username,
            gdpr_rights: gdpr_rights_info,
            deletion_status: ::Errordon::GdprDeletionService.deletion_status(@account),
            data_summary: data_summary
          }
        end

        # GET /api/v1/errordon/gdpr/data
        # Returns summary of stored personal data (GDPR Art. 15)
        def data
          render json: {
            article: 'GDPR Article 15 - Right of Access',
            account: account_data,
            statistics: data_statistics,
            export_available: true,
            export_url: '/settings/exports'
          }
        end

        # POST /api/v1/errordon/gdpr/delete
        # Request account deletion (GDPR Art. 17)
        def delete
          # Verify password for security
          unless valid_password?
            render json: { error: 'Invalid password' }, status: :unauthorized
            return
          end

          result = ::Errordon::GdprDeletionService.request_deletion(
            @account,
            request_ip: request.remote_ip,
            reason: params[:reason]
          )

          if result[:success]
            sign_out current_user
            render json: {
              success: true,
              message: 'Account deletion scheduled',
              audit_id: result[:audit_id],
              due_date: result[:due_date],
              article: 'GDPR Article 17 - Right to Erasure'
            }
          else
            render json: { error: result[:error] }, status: :unprocessable_entity
          end
        end

        # POST /api/v1/errordon/gdpr/cancel
        # Cancel pending deletion (within grace period)
        def cancel
          result = ::Errordon::GdprDeletionService.cancel_deletion(@account)

          if result[:success]
            render json: {
              success: true,
              message: 'Deletion cancelled',
              account_status: 'active'
            }
          else
            render json: { error: result[:error] }, status: :unprocessable_entity
          end
        end

        private

        def set_account
          @account = current_user.account
        end

        def valid_password?
          return true if current_user.encrypted_password.blank?

          current_user.valid_password?(params[:password])
        end

        def gdpr_rights_info
          {
            right_of_access: {
              article: 15,
              description: 'You can request a copy of all your personal data',
              endpoint: '/settings/exports'
            },
            right_to_rectification: {
              article: 16,
              description: 'You can correct your personal data',
              endpoint: '/settings/profile'
            },
            right_to_erasure: {
              article: 17,
              description: 'You can request deletion of your account',
              endpoint: '/settings/delete',
              processing_time: '30 days'
            },
            right_to_data_portability: {
              article: 20,
              description: 'You can export your data in machine-readable format',
              endpoint: '/settings/exports'
            }
          }
        end

        def data_summary
          {
            statuses: @account.statuses.count,
            media_attachments: @account.media_attachments.count,
            followers: @account.followers.count,
            following: @account.following.count,
            account_age_days: (Date.current - @account.created_at.to_date).to_i
          }
        end

        def account_data
          {
            username: @account.username,
            display_name: @account.display_name,
            email: current_user.email,
            created_at: @account.created_at,
            last_sign_in: current_user.last_sign_in_at,
            locale: current_user.locale
          }
        end

        def data_statistics
          {
            statuses_count: @account.statuses.count,
            media_attachments_count: @account.media_attachments.count,
            media_storage_bytes: @account.media_attachments.sum(:file_file_size),
            followers_count: @account.followers.count,
            following_count: @account.following.count,
            favourites_count: Favourite.where(account: @account).count,
            bookmarks_count: Bookmark.where(account: @account).count
          }
        end
      end
    end
  end
end
