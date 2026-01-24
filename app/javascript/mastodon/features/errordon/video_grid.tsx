import type React from 'react';
import { useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import PlayArrowIcon from '@/material-icons/400-24px/play_arrow-fill.svg?react';
import { Icon } from 'mastodon/components/icon';

interface VideoItem {
  id: string;
  thumbnailUrl: string;
  duration: number;
  title?: string;
  accountName?: string;
  createdAt: string;
  onClick?: () => void;
}

const formatDuration = (seconds: number): string => {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  return `${minutes}:${secs.toString().padStart(2, '0')}`;
};

export const VideoGridItem: React.FC<VideoItem> = ({
  thumbnailUrl,
  duration,
  title,
  accountName,
  onClick,
}) => {
  const handleClick = useCallback(() => {
    onClick?.();
  }, [onClick]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onClick?.();
      }
    },
    [onClick]
  );

  return (
    <div
      className='errordon-video-grid__item'
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      role='button'
      tabIndex={0}
    >
      <img
        src={thumbnailUrl}
        alt={title || 'Video thumbnail'}
        className='errordon-video-grid__thumbnail'
        loading='lazy'
      />
      <div className='errordon-video-grid__overlay' />
      <div className='errordon-video-grid__play'>
        <Icon id='play' icon={PlayArrowIcon} />
      </div>
      <span className='errordon-video-grid__duration'>
        {formatDuration(duration)}
      </span>
      {(title || accountName) && (
        <div className='errordon-video-grid__info'>
          {title && <div className='errordon-video-grid__title'>{title}</div>}
          {accountName && (
            <div className='errordon-video-grid__meta'>@{accountName}</div>
          )}
        </div>
      )}
    </div>
  );
};

interface VideoGridProps {
  videos: VideoItem[];
  onVideoClick?: (id: string) => void;
}

export const VideoGrid: React.FC<VideoGridProps> = ({ videos, onVideoClick }) => {
  if (videos.length === 0) {
    return (
      <div className='errordon-video-grid--empty'>
        <FormattedMessage
          id='errordon.video_grid.empty'
          defaultMessage='No videos to display'
        />
      </div>
    );
  }

  return (
    <div className='errordon-video-grid'>
      {videos.map((video) => (
        <VideoGridItem
          key={video.id}
          {...video}
          onClick={() => onVideoClick?.(video.id)}
        />
      ))}
    </div>
  );
};

export default VideoGrid;
