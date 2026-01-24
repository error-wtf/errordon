# frozen_string_literal: true

class Api::V1::Errordon::GdprController < Api::BaseController
  before_action :require_user!

  # GET /api/v1/errordon/gdpr/export
  # Art. 15 DSGVO: Auskunftsrecht
  # Exportiert alle personenbezogenen Daten des Nutzers
  def export
    export_data = Errordon::GdprComplianceService.export_user_data(current_account.id)
    
    render json: {
      success: true,
      legal_notice: {
        right: 'Art. 15 DSGVO - Auskunftsrecht',
        description: 'Sie haben das Recht, Auskunft über Ihre gespeicherten personenbezogenen Daten zu erhalten.',
        contact: 'datenschutz@' + Rails.configuration.x.local_domain
      },
      data: export_data
    }
  end

  # DELETE /api/v1/errordon/gdpr/delete
  # Art. 17 DSGVO: Recht auf Löschung ("Recht auf Vergessenwerden")
  def delete
    # Prüfe ob Account gelöscht werden kann
    if current_account.nsfw_protect_strikes.where(strike_type: :csam).exists?
      return render json: {
        success: false,
        error: 'account_under_investigation',
        message: 'Ihr Account enthält Daten, die aufgrund gesetzlicher Pflichten (§184b StGB) ' \
                 'aufbewahrt werden müssen. Kontaktieren Sie den Datenschutzbeauftragten.',
        legal_basis: 'Art. 17 Abs. 3 lit. b DSGVO - Rechtliche Verpflichtung',
        contact: 'datenschutz@' + Rails.configuration.x.local_domain
      }, status: :forbidden
    end

    result = Errordon::GdprComplianceService.delete_user_data(
      current_account.id,
      preserve_for_investigation: false
    )

    render json: {
      success: true,
      legal_notice: {
        right: 'Art. 17 DSGVO - Recht auf Löschung',
        description: 'Ihre personenbezogenen Daten wurden gemäß Ihrem Antrag gelöscht oder anonymisiert.'
      },
      deleted_items: result[:items_deleted],
      timestamp: result[:timestamp]
    }
  end

  # GET /api/v1/errordon/gdpr/info
  # Informationen über Datenverarbeitung
  def info
    render json: {
      data_controller: {
        name: Setting.site_title,
        domain: Rails.configuration.x.local_domain,
        contact: 'datenschutz@' + Rails.configuration.x.local_domain
      },
      
      data_processing: {
        content_moderation: {
          purpose: 'Automatische Erkennung illegaler Inhalte (Pornografie, Hassrede, CSAM)',
          legal_basis: 'Art. 6 Abs. 1 lit. f DSGVO (Berechtigtes Interesse)',
          retention: '1 Jahr für reguläre Verstöße',
          categories: ['IP-Adresse', 'Hochgeladene Medien', 'KI-Analyse-Ergebnisse']
        },
        
        csam_reporting: {
          purpose: 'Meldung von Kindesmissbrauchsdarstellungen an Strafverfolgungsbehörden',
          legal_basis: 'Art. 6 Abs. 1 lit. c DSGVO (Rechtliche Verpflichtung nach §184b StGB)',
          retention: '5 Jahre (gesetzliche Aufbewahrungspflicht)',
          categories: ['IP-Adresse', 'Account-Daten', 'Beweismaterial']
        },
        
        security_logging: {
          purpose: 'Schutz der Plattform vor Missbrauch und Angriffen',
          legal_basis: 'Art. 6 Abs. 1 lit. f DSGVO (Berechtigtes Interesse)',
          retention: '7 Tage für IP-Adressen',
          categories: ['IP-Adresse', 'User-Agent', 'Zeitstempel']
        }
      },

      your_rights: {
        access: {
          article: 'Art. 15 DSGVO',
          description: 'Auskunft über gespeicherte Daten',
          endpoint: '/api/v1/errordon/gdpr/export'
        },
        erasure: {
          article: 'Art. 17 DSGVO',
          description: 'Löschung Ihrer personenbezogenen Daten',
          endpoint: '/api/v1/errordon/gdpr/delete',
          limitations: 'Ausgenommen bei rechtlicher Aufbewahrungspflicht'
        },
        rectification: {
          article: 'Art. 16 DSGVO',
          description: 'Berichtigung unrichtiger Daten',
          contact: 'datenschutz@' + Rails.configuration.x.local_domain
        },
        restriction: {
          article: 'Art. 18 DSGVO',
          description: 'Einschränkung der Verarbeitung',
          contact: 'datenschutz@' + Rails.configuration.x.local_domain
        },
        portability: {
          article: 'Art. 20 DSGVO',
          description: 'Datenübertragbarkeit',
          endpoint: '/api/v1/errordon/gdpr/export'
        },
        complaint: {
          article: 'Art. 77 DSGVO',
          description: 'Beschwerderecht bei der Aufsichtsbehörde',
          authority: 'Landesbeauftragte/r für Datenschutz Ihres Bundeslandes'
        }
      },

      retention_periods: Errordon::GdprComplianceService::RETENTION_PERIODS.transform_values do |v|
        v.nil? ? 'unbegrenzt (anonymisiert)' : "#{v.to_i / 1.day} Tage"
      end,

      automated_decisions: {
        ai_moderation: {
          exists: true,
          description: 'Automatische Analyse hochgeladener Inhalte mittels KI',
          impact: 'Kann zur Sperrung des Accounts führen',
          human_review: 'Bei allen automatischen Entscheidungen ist eine manuelle Überprüfung möglich',
          contest: 'Widerspruch per E-Mail an datenschutz@' + Rails.configuration.x.local_domain
        }
      }
    }
  end

  # GET /api/v1/errordon/gdpr/retention
  # Zeigt Aufbewahrungsfristen für den aktuellen Account
  def retention
    account = current_account
    
    strikes_info = account.nsfw_protect_strikes.map do |strike|
      retention_end = strike.strike_type&.to_sym == :csam ?
        strike.created_at + Errordon::GdprComplianceService::RETENTION_PERIODS[:csam_data] :
        strike.created_at + Errordon::GdprComplianceService::RETENTION_PERIODS[:regular_strikes]
      
      {
        id: strike.id,
        type: strike.strike_type,
        created_at: strike.created_at.iso8601,
        data_deletion_date: retention_end.iso8601,
        ip_anonymization_date: (strike.created_at + Errordon::GdprComplianceService::RETENTION_PERIODS[:ip_addresses]).iso8601,
        ip_already_anonymized: strike.ip_address.nil?
      }
    end

    render json: {
      account_id: account.id,
      strikes: strikes_info,
      ip_retention_policy: {
        duration_days: Errordon::GdprComplianceService::RETENTION_PERIODS[:ip_addresses].to_i / 1.day,
        description: 'IP-Adressen werden nach 7 Tagen automatisch anonymisiert'
      },
      next_cleanup: '04:00 UTC täglich'
    }
  end
end
