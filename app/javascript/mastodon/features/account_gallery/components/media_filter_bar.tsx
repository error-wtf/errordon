import type { FC } from 'react';

import { FormattedMessage } from 'react-intl';

interface MediaFilterBarProps {
  excludeReblogs: boolean;
  onlyWithAlt: boolean;
  onlyPublic: boolean;
  onToggleExcludeReblogs: () => void;
  onToggleOnlyWithAlt: () => void;
  onToggleOnlyPublic: () => void;
}

export const MediaFilterBar: FC<MediaFilterBarProps> = ({
  excludeReblogs,
  onlyWithAlt,
  onlyPublic,
  onToggleExcludeReblogs,
  onToggleOnlyWithAlt,
  onToggleOnlyPublic,
}) => {
  return (
    <div className='media-filter-bar'>
      <button
        className={`filter-chip ${excludeReblogs ? 'active' : ''}`}
        onClick={onToggleExcludeReblogs}
        type='button'
      >
        <FormattedMessage
          id='account.media_filter.originals_only'
          defaultMessage='Originals only'
        />
      </button>
      <button
        className={`filter-chip ${onlyWithAlt ? 'active' : ''}`}
        onClick={onToggleOnlyWithAlt}
        type='button'
      >
        <FormattedMessage
          id='account.media_filter.with_alt_text'
          defaultMessage='With alt text'
        />
      </button>
      <button
        className={`filter-chip ${onlyPublic ? 'active' : ''}`}
        onClick={onToggleOnlyPublic}
        type='button'
      >
        <FormattedMessage
          id='account.media_filter.public_only'
          defaultMessage='Public only'
        />
      </button>
    </div>
  );
};
