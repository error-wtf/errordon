import type React from 'react';
import { useState, useEffect, useCallback } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

const messages = defineMessages({
  title: { id: 'errordon.admin.quotas.title', defaultMessage: 'Storage Quotas' },
  totalStorage: { id: 'errordon.admin.quotas.total_storage', defaultMessage: 'Total Storage Used' },
  activeUsers: { id: 'errordon.admin.quotas.active_users', defaultMessage: 'Active Uploaders' },
  pendingTranscodes: { id: 'errordon.admin.quotas.pending_transcodes', defaultMessage: 'Pending Transcodes' },
  quotaUsage: { id: 'errordon.admin.quotas.quota_usage', defaultMessage: 'Avg. Quota Usage' },
  username: { id: 'errordon.admin.quotas.username', defaultMessage: 'Username' },
  storageUsed: { id: 'errordon.admin.quotas.storage_used', defaultMessage: 'Storage Used' },
  quota: { id: 'errordon.admin.quotas.quota', defaultMessage: 'Quota' },
  usage: { id: 'errordon.admin.quotas.usage', defaultMessage: 'Usage' },
  actions: { id: 'errordon.admin.quotas.actions', defaultMessage: 'Actions' },
  increaseQuota: { id: 'errordon.admin.quotas.increase_quota', defaultMessage: 'Increase' },
  viewMedia: { id: 'errordon.admin.quotas.view_media', defaultMessage: 'View' },
});

interface UserQuota {
  id: string;
  username: string;
  displayName: string;
  storageUsed: number;
  storageQuota: number;
  uploadCount: number;
  lastUpload: string;
}

interface QuotaStats {
  totalStorageUsed: number;
  totalStorageLimit: number;
  activeUploaders: number;
  pendingTranscodes: number;
  avgQuotaUsage: number;
}

const formatBytes = (bytes: number): string => {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
};

const QuotaProgressBar: React.FC<{ percentage: number }> = ({ percentage }) => {
  const getColorClass = () => {
    if (percentage < 50) return 'errordon-admin-quotas__progress-bar--low';
    if (percentage < 80) return 'errordon-admin-quotas__progress-bar--medium';
    return 'errordon-admin-quotas__progress-bar--high';
  };

  return (
    <div className='errordon-admin-quotas__progress'>
      <div
        className={`errordon-admin-quotas__progress-bar ${getColorClass()}`}
        style={{ width: `${Math.min(percentage, 100)}%` }}
      />
    </div>
  );
};

const StatCard: React.FC<{
  label: string;
  value: string | number;
  change?: { value: number; positive: boolean };
}> = ({ label, value, change }) => (
  <div className='errordon-admin-quotas__stat-card'>
    <div className='errordon-admin-quotas__stat-card__label'>{label}</div>
    <div className='errordon-admin-quotas__stat-card__value'>{value}</div>
    {change && (
      <div
        className={`errordon-admin-quotas__stat-card__change errordon-admin-quotas__stat-card__change--${change.positive ? 'positive' : 'negative'}`}
      >
        {change.positive ? '↑' : '↓'} {Math.abs(change.value)}%
      </div>
    )}
  </div>
);

export const AdminQuotas: React.FC = () => {
  const intl = useIntl();
  const [stats, setStats] = useState<QuotaStats | null>(null);
  const [users, setUsers] = useState<UserQuota[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Fetch quota data from API
    const fetchData = async () => {
      try {
        // In production, these would be real API calls
        // For now, we'll use placeholder data structure
        setStats({
          totalStorageUsed: 0,
          totalStorageLimit: 1099511627776, // 1TB
          activeUploaders: 0,
          pendingTranscodes: 0,
          avgQuotaUsage: 0,
        });
        setUsers([]);
        setLoading(false);
      } catch (error) {
        console.error('Failed to fetch quota data:', error);
        setLoading(false);
      }
    };

    void fetchData();
  }, []);

  const handleIncreaseQuota = useCallback((userId: string) => {
    console.log('Increase quota for user:', userId);
    // API call to increase quota
  }, []);

  const handleViewMedia = useCallback((userId: string) => {
    console.log('View media for user:', userId);
    // Navigate to user media view
  }, []);

  if (loading) {
    return (
      <div className='errordon-admin-quotas'>
        <FormattedMessage
          id='errordon.admin.quotas.loading'
          defaultMessage='Loading quota data...'
        />
      </div>
    );
  }

  return (
    <div className='errordon-admin-quotas'>
      <div className='errordon-admin-quotas__header'>
        <h2>{intl.formatMessage(messages.title)}</h2>
      </div>

      <div className='errordon-admin-quotas__stats'>
        <StatCard
          label={intl.formatMessage(messages.totalStorage)}
          value={stats ? formatBytes(stats.totalStorageUsed) : '0 B'}
        />
        <StatCard
          label={intl.formatMessage(messages.activeUsers)}
          value={stats?.activeUploaders ?? 0}
        />
        <StatCard
          label={intl.formatMessage(messages.pendingTranscodes)}
          value={stats?.pendingTranscodes ?? 0}
        />
        <StatCard
          label={intl.formatMessage(messages.quotaUsage)}
          value={`${stats?.avgQuotaUsage ?? 0}%`}
        />
      </div>

      <table className='errordon-admin-quotas__table'>
        <thead>
          <tr>
            <th>{intl.formatMessage(messages.username)}</th>
            <th>{intl.formatMessage(messages.storageUsed)}</th>
            <th>{intl.formatMessage(messages.quota)}</th>
            <th>{intl.formatMessage(messages.usage)}</th>
            <th>{intl.formatMessage(messages.actions)}</th>
          </tr>
        </thead>
        <tbody>
          {users.length === 0 ? (
            <tr>
              <td colSpan={5} style={{ textAlign: 'center' }}>
                <FormattedMessage
                  id='errordon.admin.quotas.no_users'
                  defaultMessage='No users with media uploads'
                />
              </td>
            </tr>
          ) : (
            users.map((user) => {
              const usagePercent = (user.storageUsed / user.storageQuota) * 100;
              return (
                <tr key={user.id}>
                  <td>
                    <strong>@{user.username}</strong>
                    <br />
                    <small>{user.displayName}</small>
                  </td>
                  <td>{formatBytes(user.storageUsed)}</td>
                  <td>{formatBytes(user.storageQuota)}</td>
                  <td>
                    <QuotaProgressBar percentage={usagePercent} />
                    <small>{usagePercent.toFixed(1)}%</small>
                  </td>
                  <td>
                    <div className='errordon-admin-quotas__actions'>
                      <button
                        className='secondary'
                        onClick={() => handleViewMedia(user.id)}
                      >
                        {intl.formatMessage(messages.viewMedia)}
                      </button>
                      <button
                        className='primary'
                        onClick={() => handleIncreaseQuota(user.id)}
                      >
                        {intl.formatMessage(messages.increaseQuota)}
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
};

export default AdminQuotas;
