# Contributing to Mastodon Media Columns

## Branch Workflow

1. **Create feature branch** from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Make changes** with small, focused commits

3. **Test locally** before pushing

4. **Open PR** against `develop`

## Commit Messages

Use conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code refactoring
- `test:` Adding tests

## Code Style

- Follow existing Mastodon code style
- Ruby: RuboCop rules
- JavaScript: ESLint rules
- Run linters before committing

## Testing

```bash
# Ruby tests
bundle exec rspec

# JavaScript tests
yarn test

# Linting
bundle exec rubocop
yarn lint
```

## Pull Request Guidelines

- Keep PRs small and focused
- Include tests for new functionality
- Update documentation as needed
- Ensure CI passes
- Request review from maintainers
