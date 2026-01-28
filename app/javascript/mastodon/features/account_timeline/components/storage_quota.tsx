import { useEffect, useState, useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import { me } from 'mastodon/initial_state';
import { apiRequest } from 'mastodon/api';

interface StorageQuotaData {
  storage: {
    used: number;
    used_human: string;
    quota: number;
    quota_human: string;
    available: number;
    available_human: string;
    percent: number;
    at_limit: boolean;
    can_upload: boolean;
  };
  fair_share: {
    active_users: number;
    pool_total: number;
    pool_total_human: string;
    max_percent: number;
    notice: string;
  };
  can_upload: boolean;
  at_limit: boolean;
  exempt: boolean;
}

export const StorageQuota: React.FC<{ accountId: string }> = ({ accountId }) => {
  const [quota, setQuota] = useState<StorageQuotaData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Only show for own account
  const isOwnAccount = accountId === me;

  const fetchQuota = useCallback(async () => {
    if (!isOwnAccount) return;

    try {
      setLoading(true);
      const response = await apiRequest<StorageQuotaData>('GET', '/api/v1/errordon/storage_quota');
      setQuota(response);
      setError(null);
    } catch (e) {
      setError('Failed to load storage quota');
      console.error('StorageQuota fetch error:', e);
    } finally {
      setLoading(false);
    }
  }, [isOwnAccount]);

  useEffect(() => {
    fetchQuota();
  }, [fetchQuota]);

  if (!isOwnAccount) {
    return null;
  }

  if (loading) {
    return (
      <div className='storage-quota storage-quota--loading'>
        <FormattedMessage id='storage_quota.loading' defaultMessage='Loading storage info...' />
      </div>
    );
  }

  if (error || !quota) {
    return null;
  }

  const { storage, fair_share, exempt } = quota;
  const progressBarClass = storage.at_limit
    ? 'storage-quota__bar--full'
    : storage.percent > 80
    ? 'storage-quota__bar--warning'
    : '';

  return (
    <div className='storage-quota'>
      <div className='storage-quota__header'>
        <h4>
          <FormattedMessage id='storage_quota.title' defaultMessage='Storage Quota' />
        </h4>
        {exempt && (
          <span className='storage-quota__badge storage-quota__badge--exempt'>
            <FormattedMessage id='storage_quota.exempt' defaultMessage='Exempt' />
          </span>
        )}
      </div>

      <div className='storage-quota__progress'>
        <div
          className={`storage-quota__bar ${progressBarClass}`}
          style={{ width: `${Math.min(storage.percent, 100)}%` }}
        />
      </div>

      <div className='storage-quota__stats'>
        <div className='storage-quota__stat'>
          <span className='storage-quota__label'>
            <FormattedMessage id='storage_quota.used' defaultMessage='Used' />
          </span>
          <span className='storage-quota__value'>{storage.used_human}</span>
        </div>

        <div className='storage-quota__stat'>
          <span className='storage-quota__label'>
            <FormattedMessage id='storage_quota.available' defaultMessage='Available' />
          </span>
          <span className='storage-quota__value'>{storage.available_human}</span>
        </div>

        <div className='storage-quota__stat'>
          <span className='storage-quota__label'>
            <FormattedMessage id='storage_quota.quota' defaultMessage='Quota' />
          </span>
          <span className='storage-quota__value'>{storage.quota_human}</span>
        </div>
      </div>

      {storage.at_limit && (
        <div className='storage-quota__warning'>
          <FormattedMessage
            id='storage_quota.at_limit'
            defaultMessage='You have reached your storage limit. Delete some media to upload more.'
          />
        </div>
      )}

      <div className='storage-quota__fair-share'>
        <p className='storage-quota__notice'>{fair_share.notice}</p>
        {fair_share.active_users > 1 && (
          <p className='storage-quota__info'>
            <FormattedMessage
              id='storage_quota.fair_share_info'
              defaultMessage='Storage is shared fairly among {count} active users. Your quota may change as users join or leave.'
              values={{ count: fair_share.active_users }}
            />
          </p>
        )}
      </div>
    </div>
  );
};
