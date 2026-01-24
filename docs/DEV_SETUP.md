# Local Development Setup

## Prerequisites

- Ruby 3.2+
- Node.js 18+
- PostgreSQL 14+
- Redis 6+
- ffmpeg (for media processing)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/error-wtf/mastodon-media-columns.git
cd mastodon-media-columns

# Add upstream
git remote add upstream https://github.com/mastodon/mastodon.git

# Install Ruby dependencies
bundle install

# Install Node dependencies
yarn install

# Copy environment file
cp .env.production.sample .env

# Edit .env with your local settings
# - Database URLs
# - Redis URL
# - Secret keys

# Setup database
RAILS_ENV=development bundle exec rails db:setup

# Start all services
foreman start
```

## Docker Alternative

```bash
# Use docker-compose for dependencies
docker-compose -f docker-compose.dev.yml up -d db redis

# Run Rails locally
bundle exec rails s

# Or run everything in Docker
docker-compose up
```

## Running Tests

```bash
# Ruby tests
bundle exec rspec

# JavaScript tests
yarn test

# Linting
bundle exec rubocop
yarn lint
```

## Key Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LOCAL_DOMAIN` | Your instance domain | `localhost:3000` |
| `DB_HOST` | PostgreSQL host | `localhost` |
| `REDIS_URL` | Redis connection | `redis://localhost:6379` |
| `SECRET_KEY_BASE` | Rails secret | `rake secret` |

## Useful Commands

```bash
# Rails console
bundle exec rails c

# Database migrations
bundle exec rails db:migrate

# Asset compilation
bundle exec rails assets:precompile

# Sidekiq (background jobs)
bundle exec sidekiq
```
