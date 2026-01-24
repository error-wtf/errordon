import { useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

interface MediaFilterBarProps {
  excludeReblogs: boolean;
  onToggleExcludeReblogs: () => void;
}

export const MediaFilterBar: React.FC<MediaFilterBarProps> = ({
  excludeReblogs,
  onToggleExcludeReblogs,
}) => {
  const handleToggle = useCallback(() => {
    onToggleExcludeReblogs();
  }, [onToggleExcludeReblogs]);

  return (
    <div className='media-filter-bar'>
      <button
        className={`filter-chip ${excludeReblogs ? 'active' : ''}`}
        onClick={handleToggle}
        type='button'
      >
        <FormattedMessage
          id='account.media_filter.originals_only'
          defaultMessage='Originals only'
        />
      </button>
    </div>
  );
};
