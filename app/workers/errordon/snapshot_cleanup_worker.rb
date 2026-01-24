# frozen_string_literal: true

module Errordon
  class SnapshotCleanupWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'pull', retry: 1, lock: :until_executed

    # Löscht AI-Analyse-Snapshots die:
    # - Älter als 14 Tage sind UND
    # - Keine Violation enthalten (SAFE oder REVIEW ohne Strike)
    #
    # Snapshots mit Violations werden länger behalten (für Rechtszwecke)

    def perform
      return unless NsfwProtectConfig.enabled?

      Rails.logger.info "[NSFW-Protect] Starting snapshot cleanup"

      stats = {
        deleted: 0,
        kept_violations: 0,
        errors: 0,
        started_at: Time.current
      }

      # Nur SAFE Snapshots die älter als delete_after sind löschen
      NsfwAnalysisSnapshot.expired.find_each do |snapshot|
        # Doppelcheck: Nie Violations löschen
        if snapshot.violation_detected? || snapshot.nsfw_protect_strike_id.present?
          stats[:kept_violations] += 1
          next
        end

        snapshot.destroy
        stats[:deleted] += 1
      rescue StandardError => e
        Rails.logger.error "[NSFW-Protect] Failed to delete snapshot #{snapshot.id}: #{e.message}"
        stats[:errors] += 1
      end

      stats[:finished_at] = Time.current
      stats[:duration_seconds] = (stats[:finished_at] - stats[:started_at]).to_i

      Rails.logger.info "[NSFW-Protect] Snapshot cleanup complete: " \
                        "deleted=#{stats[:deleted]}, " \
                        "kept=#{stats[:kept_violations]}, " \
                        "errors=#{stats[:errors]}, " \
                        "duration=#{stats[:duration_seconds]}s"

      stats
    end
  end
end
