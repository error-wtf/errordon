# frozen_string_literal: true

namespace :errordon do
  namespace :video_cleanup do
    desc 'Show stats for video cleanup (eligible videos, potential space savings)'
    task stats: :environment do
      stats = Errordon::VideoCleanupService.stats

      puts ''
      puts '=== Errordon Video Cleanup Stats ==='
      puts ''
      puts "Configuration:"
      puts "  Enabled:           #{stats[:config][:enabled]}"
      puts "  Days threshold:    #{stats[:config][:days_threshold]} days"
      puts "  Min size:          #{stats[:config][:min_original_size_mb]} MB"
      puts "  Batch size:        #{stats[:config][:batch_size]}"
      puts "  Dry run:           #{stats[:config][:dry_run]}"
      puts ''
      puts "Videos:"
      puts "  Total videos:      #{stats[:total_videos]}"
      puts "  Already shrunk:    #{stats[:already_shrunk]}"
      puts "  Eligible:          #{stats[:eligible_for_cleanup]}"
      puts "  Eligible size:     #{stats[:eligible_size_mb]} MB"
      puts "  Threshold date:    #{stats[:threshold_date]}"
      puts ''
      
      if stats[:eligible_for_cleanup] > 0
        estimated_savings = (stats[:eligible_size_mb] * 0.4).round(2)
        puts "Estimated savings:   ~#{estimated_savings} MB (40% average reduction)"
      end
      puts ''
    end

    desc 'Run video cleanup in dry-run mode (no actual changes)'
    task dry_run: :environment do
      puts ''
      puts '=== Errordon Video Cleanup (DRY RUN) ==='
      puts ''

      stats = Errordon::VideoCleanupService.run!(dry_run: true)

      puts ''
      puts "Results:"
      puts "  Processed:     #{stats[:processed]}"
      puts "  Skipped:       #{stats[:skipped]}"
      puts "  Failed:        #{stats[:failed]}"
      puts "  Est. savings:  #{stats[:space_saved_mb]} MB"
      puts "  Duration:      #{stats[:duration_seconds]}s"
      puts ''
      puts 'No changes were made (dry run mode)'
      puts ''
    end

    desc 'Run video cleanup (shrink old videos to 480p)'
    task run: :environment do
      puts ''
      puts '=== Errordon Video Cleanup ==='
      puts ''

      unless Errordon::VideoCleanupService.enabled?
        puts 'Video cleanup is disabled.'
        puts 'Set ERRORDON_VIDEO_CLEANUP_ENABLED=true to enable.'
        exit 1
      end

      stats = Errordon::VideoCleanupService.stats
      puts "Found #{stats[:eligible_for_cleanup]} eligible videos (#{stats[:eligible_size_mb]} MB)"
      puts ''

      if stats[:eligible_for_cleanup] == 0
        puts 'No videos to clean up.'
        exit 0
      end

      print 'Continue? [y/N] '
      confirm = $stdin.gets.chomp.downcase
      
      unless confirm == 'y'
        puts 'Aborted.'
        exit 0
      end

      puts ''
      puts 'Starting cleanup...'
      puts ''

      result = Errordon::VideoCleanupService.run!

      puts ''
      puts "Results:"
      puts "  Processed:     #{result[:processed]}"
      puts "  Skipped:       #{result[:skipped]}"
      puts "  Failed:        #{result[:failed]}"
      puts "  Space saved:   #{result[:space_saved_mb]} MB"
      puts "  Duration:      #{result[:duration_seconds]}s"
      puts ''
    end

    desc 'Run video cleanup without confirmation (for cron)'
    task run_unattended: :environment do
      return unless Errordon::VideoCleanupService.enabled?

      Rails.logger.info '[Errordon VideoCleanup] Starting unattended cleanup'
      
      result = Errordon::VideoCleanupService.run!

      Rails.logger.info "[Errordon VideoCleanup] Completed: " \
                        "processed=#{result[:processed]}, " \
                        "saved=#{result[:space_saved_mb]}MB"
    end

    desc 'Shrink a specific video by ID'
    task :shrink, [:attachment_id] => :environment do |_t, args|
      attachment_id = args[:attachment_id]

      unless attachment_id
        puts 'Usage: rake errordon:video_cleanup:shrink[ATTACHMENT_ID]'
        exit 1
      end

      attachment = MediaAttachment.find_by(id: attachment_id)

      unless attachment
        puts "Media attachment #{attachment_id} not found"
        exit 1
      end

      unless attachment.video?
        puts "Media attachment #{attachment_id} is not a video"
        exit 1
      end

      puts ''
      puts "Video: #{attachment_id}"
      puts "  Size:     #{(attachment.file_file_size / 1.megabyte.to_f).round(2)} MB"
      puts "  Created:  #{attachment.created_at}"
      puts "  Shrunk:   #{attachment.errordon_shrunk? ? 'Yes' : 'No'}"
      puts ''

      print 'Shrink this video? [y/N] '
      confirm = $stdin.gets.chomp.downcase

      unless confirm == 'y'
        puts 'Aborted.'
        exit 0
      end

      puts ''
      puts 'Shrinking...'

      service = Errordon::VideoCleanupService.new(attachment)
      result = service.call

      if result[:success]
        puts ''
        puts "Success!"
        puts "  Original: #{(result[:original_size] / 1.megabyte.to_f).round(2)} MB"
        puts "  New size: #{(result[:new_size] / 1.megabyte.to_f).round(2)} MB"
        puts "  Saved:    #{(result[:space_saved] / 1.megabyte.to_f).round(2)} MB"
      else
        puts ''
        puts "Failed: #{result[:error] || result[:reason]}"
        exit 1
      end
      puts ''
    end
  end
end
