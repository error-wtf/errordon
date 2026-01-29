# Contributing to Errordon

Thank you for your interest in contributing to Errordon! This guide will help you get started.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [Making Changes](#making-changes)
5. [Testing](#testing)
6. [Pull Request Process](#pull-request-process)
7. [Coding Standards](#coding-standards)
8. [Documentation](#documentation)
9. [Translations](#translations)
10. [Security Issues](#security-issues)

---

## Code of Conduct

By participating in this project, you agree to abide by our principles:

- **Be respectful** - Treat everyone with respect and kindness
- **Be constructive** - Focus on improving the project
- **Be inclusive** - Welcome people of all backgrounds
- **No tolerance for hate** - Just like our platform, hate speech is not welcome

---

## Getting Started

### Types of Contributions

We welcome:

- 🐛 **Bug fixes**
- ✨ **New features**
- 📝 **Documentation improvements**
- 🌍 **Translations**
- 🧪 **Test coverage**
- 🎨 **UI/UX improvements**

### Before You Start

1. Check [existing issues](https://github.com/error-wtf/errordon/issues) for duplicates
2. For major changes, open an issue first to discuss
3. Fork the repository

---

## Development Setup

### Prerequisites

- Ruby 3.3.x
- Node.js 22.x
- PostgreSQL 14+
- Redis 7+
- Docker (optional but recommended)

### Quick Setup with Docker

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/errordon.git
cd errordon

# Start development environment
docker compose -f docker-compose.dev.yml up -d

# Install dependencies
docker compose exec web bundle install
docker compose exec web yarn install

# Setup database
docker compose exec web bin/rails db:setup

# Start development server
docker compose exec web bin/dev
```

### Manual Setup

```bash
# Clone repository
git clone https://github.com/YOUR-USERNAME/errordon.git
cd errordon

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
yarn install

# Copy environment file
cp .env.development.sample .env.development

# Setup database
bin/rails db:setup

# Start development server
bin/dev
```

### Environment Variables for Development

```bash
# .env.development
LOCAL_DOMAIN=localhost:3000
RAILS_ENV=development
DB_HOST=localhost
DB_USER=mastodon
DB_NAME=mastodon_development
REDIS_URL=redis://localhost:6379/0
```

---

## Making Changes

### Branch Naming

Use descriptive branch names:

```
feature/add-emoji-reactions
fix/matrix-rain-scroll-freeze
docs/update-deployment-guide
refactor/storage-quota-service
```

### Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting (no code change)
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

Examples:
```
feat(embed): enable rich oEmbed providers with iframe-only content

fix(theme): matrix rain no longer freezes on scroll

docs(readme): add deployment section
```

### File Organization

Errordon-specific code goes in designated locations:

```
app/
├── controllers/api/v1/errordon/    # API controllers
├── services/errordon/              # Business logic
├── workers/errordon/               # Background jobs
├── javascript/
│   ├── mastodon/features/errordon/ # React components
│   └── styles/errordon_*.scss      # Stylesheets
config/
├── initializers/errordon_*.rb      # Configuration
├── routes/errordon.rb              # API routes
└── locales/errordon.*.yml          # Translations
```

---

## Testing

### Running Tests

```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/services/errordon/storage_quota_service_spec.rb

# With coverage
COVERAGE=true bundle exec rspec
```

### Writing Tests

Place tests in `spec/` mirroring the app structure:

```ruby
# spec/services/errordon/storage_quota_service_spec.rb
require 'rails_helper'

RSpec.describe Errordon::StorageQuotaService do
  describe '.quota_for' do
    let(:account) { Fabricate(:account) }

    it 'returns base quota for new user' do
      quota = described_class.quota_for(account)
      expect(quota).to eq(1.gigabyte)
    end
  end
end
```

### Test Coverage

We aim for >80% coverage on Errordon-specific code. Check coverage:

```bash
open coverage/index.html
```

---

## Pull Request Process

### Before Submitting

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation updated if needed
- [ ] No console.log / puts / debug statements
- [ ] No credentials or secrets in code
- [ ] Commit messages follow conventions

### PR Template

```markdown
## Summary
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Refactoring

## Testing
How did you test this?

## Screenshots (if applicable)

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Changelog updated
```

### Review Process

1. Submit PR against `develop` branch
2. Automated CI checks run
3. Maintainer reviews code
4. Address feedback if any
5. Merge once approved

---

## Coding Standards

### Ruby

Follow [Ruby Style Guide](https://rubystyle.guide/):

```ruby
# Good
class Errordon::MyService
  def call(account)
    return if account.nil?
    
    process_account(account)
  end

  private

  def process_account(account)
    # ...
  end
end

# Bad
class Errordon::MyService
  def call account
    if account != nil
      process_account account
    end
  end
  def process_account account
    # ...
  end
end
```

### JavaScript/TypeScript

Follow Mastodon's existing patterns:

```typescript
// Good
import { useCallback, useState } from 'react';

interface Props {
  account: Account;
  onUpdate: (account: Account) => void;
}

export const MyComponent: React.FC<Props> = ({ account, onUpdate }) => {
  const [loading, setLoading] = useState(false);

  const handleClick = useCallback(() => {
    setLoading(true);
    // ...
  }, []);

  return (
    <button onClick={handleClick} disabled={loading}>
      Update
    </button>
  );
};
```

### SCSS

Follow BEM naming and Matrix theme conventions:

```scss
// Good
.errordon-component {
  background: var(--matrix-background);
  color: var(--matrix-text);

  &__header {
    border-bottom: 1px solid var(--matrix-primary);
  }

  &__content {
    padding: 16px;
  }

  &--highlighted {
    box-shadow: 0 0 10px var(--matrix-glow);
  }
}
```

### SQL/Migrations

```ruby
# Good - reversible migration
class AddQuotaToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :custom_quota, :bigint
    add_index :accounts, :custom_quota
  end
end

# When irreversible, use up/down
class ComplexMigration < ActiveRecord::Migration[7.1]
  def up
    # ...
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

---

## Documentation

### When to Update Docs

- Adding new features
- Changing configuration options
- Modifying API endpoints
- Updating deployment process

### Documentation Locations

| Type | Location |
|------|----------|
| Feature docs | `docs/FEATURES/` |
| API reference | `docs/API.md` |
| Configuration | `docs/CONFIGURATION.md` |
| Deployment | `docs/DEPLOYMENT.md` |
| Changelog | `docs/CHANGELOG.md` |

### Writing Style

- Use clear, concise language
- Include code examples
- Add screenshots for UI changes
- Keep formatting consistent

---

## Translations

### Adding Translations

1. Copy English locale file:
   ```bash
   cp config/locales/errordon.en.yml config/locales/errordon.de.yml
   ```

2. Translate strings:
   ```yaml
   # config/locales/errordon.de.yml
   de:
     errordon:
       storage_quota:
         exceeded: "Speicherkontingent überschritten"
   ```

3. Test in browser:
   ```bash
   bin/rails server
   # Visit http://localhost:3000?locale=de
   ```

### Translation Guidelines

- Keep placeholders intact: `%{name}`, `%{count}`
- Maintain HTML tags if present
- Test with actual content

---

## Security Issues

### Reporting Security Vulnerabilities

**DO NOT** open public issues for security vulnerabilities.

Instead:
1. Email security concerns to the maintainers
2. Include detailed description
3. Provide steps to reproduce
4. Allow time for fix before disclosure

### Security Best Practices

When contributing:
- Never commit credentials
- Sanitize user input
- Use parameterized queries
- Validate file uploads
- Follow OWASP guidelines

---

## Getting Help

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Questions and general discussion
- **Matrix Chat** - Real-time help (link in README)

---

## Recognition

Contributors are listed in:
- GitHub contributors page
- Release notes for significant contributions

Thank you for contributing to a safer Fediverse! 🎉
