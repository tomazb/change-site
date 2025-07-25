# Contributing to change-site

Thank you for your interest in contributing to the change-site project! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)
- [Community Guidelines](#community-guidelines)

## Getting Started

### Prerequisites

- Bash 4.4 or higher
- Git for version control
- NetworkManager (for testing)
- Basic understanding of shell scripting
- Familiarity with network configuration concepts

### Development Environment

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/change-site.git
   cd change-site
   ```

2. **Set up upstream remote**
   ```bash
   git remote add upstream https://github.com/tomazb/change-site.git
   ```

3. **Install development dependencies**
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install shellcheck network-manager jq
   
   # On RHEL/CentOS
   sudo dnf install ShellCheck NetworkManager jq
   ```

4. **Verify setup**
   ```bash
   # Test script syntax
   bash -n change-site.sh
   
   # Run basic tests
   ./tests/run-tests.sh --basic
   ```

## Development Setup

### Branch Strategy

- `main` - Stable, production-ready code
- `develop` - Integration branch for new features
- `feature/*` - Individual feature development
- `hotfix/*` - Critical bug fixes
- `release/*` - Release preparation

### Workflow

1. **Create feature branch**
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout -b feature/your-feature-name
   ```

2. **Make changes and test**
   ```bash
   # Make your changes
   vim change-site.sh
   
   # Test thoroughly
   ./tests/run-tests.sh
   ./change-site.sh --dry-run 192.168 172.23
   ```

3. **Commit changes**
   ```bash
   git add .
   git commit -m "feat: Add new feature description"
   ```

4. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   # Create PR on GitHub
   ```

## Contributing Guidelines

### Types of Contributions

- **Bug fixes** - Fix existing functionality
- **Features** - Add new capabilities
- **Documentation** - Improve or add documentation
- **Testing** - Enhance test coverage
- **Performance** - Optimize existing code
- **Security** - Address security concerns

### Contribution Process

1. **Check existing issues** - Look for related issues or discussions
2. **Create issue** - For significant changes, create an issue first
3. **Fork and branch** - Work on a feature branch
4. **Implement changes** - Follow coding standards
5. **Test thoroughly** - Ensure all tests pass
6. **Document changes** - Update relevant documentation
7. **Submit PR** - Create a pull request with clear description

## Code Standards

### Shell Script Guidelines

#### Style Requirements

```bash
# Use 2-space indentation
if [[ condition ]]; then
  echo "Properly indented"
fi

# Use meaningful variable names
CONFIG_FILE="/etc/change-site.conf"
SOURCE_SUBNET="$1"

# Quote variables to prevent word splitting
echo "Processing subnet: ${SOURCE_SUBNET}"

# Use functions for reusable code
validate_subnet() {
  local subnet="$1"
  [[ "$subnet" =~ ^[0-9]{1,3}\.[0-9]{1,3}$ ]]
}
```

#### Best Practices

- **Error Handling**: Always check return codes
- **Input Validation**: Validate all user inputs
- **Logging**: Use structured logging with levels
- **Security**: Avoid command injection vulnerabilities
- **Portability**: Ensure RHEL 8-10 compatibility

#### Function Design

```bash
# Functions should be focused and under 50 lines
# Use descriptive names and document parameters
update_network_connection() {
  local connection_name="$1"
  local old_subnet="$2"
  local new_subnet="$3"
  
  # Implementation here
  return 0
}
```

### Documentation Standards

#### Code Comments

```bash
# Function: update_hosts_file
# Purpose: Update /etc/hosts entries for subnet change
# Parameters:
#   $1 - source subnet (e.g., "192.168")
#   $2 - target subnet (e.g., "172.23")
# Returns: 0 on success, 1 on failure
update_hosts_file() {
  # Implementation
}
```

#### Markdown Documentation

- Use clear headings and structure
- Include code examples
- Provide step-by-step instructions
- Link to related documentation

### Commit Message Format

Follow conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

#### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/modifications
- `chore`: Maintenance tasks

#### Examples
```
feat(monitoring): Add structured JSON logging

- Implement configurable log levels
- Add timestamp formatting
- Include performance metrics

Closes #123
```

## Testing Requirements

### Test Categories

1. **Unit Tests** - Individual function testing
2. **Integration Tests** - Component interaction testing
3. **System Tests** - End-to-end functionality
4. **Performance Tests** - Execution time and memory usage
5. **Compatibility Tests** - RHEL version compatibility

### Running Tests

```bash
# Run all tests
./tests/run-tests.sh

# Run specific test suite
./tests/run-tests.sh --basic
./tests/run-tests.sh --integration
./tests/run-tests.sh --enhanced

# Run individual test file
./tests/test-change-site.sh
```

### Writing Tests

#### Test Structure

```bash
#!/bin/bash
# Test file: test-new-feature.sh

# Setup
setup_test_environment() {
  # Prepare test conditions
}

# Test cases
test_new_feature_basic() {
  # Test basic functionality
  assert_equals "expected" "$(actual_result)"
}

test_new_feature_edge_cases() {
  # Test edge cases
  assert_fails "invalid_input"
}

# Cleanup
cleanup_test_environment() {
  # Clean up test artifacts
}
```

#### Test Requirements

- All new features must include tests
- Tests should cover normal and edge cases
- Use dry-run mode for safe testing
- Include performance benchmarks for significant changes

### Quality Gates

All contributions must pass:

- [ ] Shellcheck linting
- [ ] Syntax validation
- [ ] All test suites
- [ ] Security scan
- [ ] Documentation validation
- [ ] Performance benchmarks

## Documentation

### Required Documentation

#### For New Features
- Update `README.md` with usage examples
- Add to `docs/PROJECT_STATUS.md`
- Include in `docs/STAGING_TESTING_GUIDE.md`
- Update configuration documentation

#### For Bug Fixes
- Document the issue and solution
- Update troubleshooting section if applicable
- Add test cases to prevent regression

#### For API Changes
- Update all affected documentation
- Provide migration guide if needed
- Update version compatibility information

### Documentation Guidelines

- Use clear, concise language
- Provide practical examples
- Include troubleshooting information
- Maintain consistency with existing style

## Pull Request Process

### PR Requirements

1. **Clear Description**
   - What changes were made
   - Why the changes were necessary
   - How to test the changes

2. **Testing Evidence**
   - All tests pass
   - Manual testing performed
   - Performance impact assessed

3. **Documentation Updates**
   - Relevant documentation updated
   - Examples provided where applicable

4. **Code Quality**
   - Follows coding standards
   - Includes appropriate comments
   - No unnecessary complexity

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

## Testing
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing completed
- [ ] Performance impact assessed

## Documentation
- [ ] README updated
- [ ] Code comments added
- [ ] Documentation files updated

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] No merge conflicts
- [ ] CI/CD pipeline passes
```

### Review Process

1. **Automated Checks** - CI/CD pipeline validation
2. **Code Review** - Maintainer review for quality and standards
3. **Testing Validation** - Verify test coverage and results
4. **Documentation Review** - Ensure documentation is complete
5. **Final Approval** - Maintainer approval for merge

## Release Process

### Version Management

The project follows semantic versioning (SemVer):
- `MAJOR.MINOR.PATCH`
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes (backward compatible)

### Release Workflow

1. **Feature Complete** - All features for release implemented
2. **Testing** - Comprehensive testing completed
3. **Documentation** - All documentation updated
4. **Release Branch** - Create release branch from develop
5. **Version Bump** - Update version numbers
6. **Release Notes** - Generate comprehensive release notes
7. **Tag and Release** - Create Git tag and GitHub release
8. **Merge to Main** - Merge release to main branch

### Release Responsibilities

#### Contributors
- Ensure features are complete and tested
- Update relevant documentation
- Participate in release testing

#### Maintainers
- Coordinate release timeline
- Review all changes
- Manage release process
- Communicate with community

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Focus on technical merit

### Communication

#### GitHub Issues
- Use for bug reports and feature requests
- Provide clear reproduction steps
- Include relevant system information

#### Pull Requests
- Engage in constructive code review
- Respond to feedback promptly
- Ask questions when unclear

#### Discussions
- Use GitHub Discussions for general questions
- Share ideas and proposals
- Help other community members

### Recognition

Contributors are recognized through:
- GitHub contributor statistics
- Release notes acknowledgments
- Community recognition
- Maintainer recommendations

## Getting Help

### Resources
- **Documentation**: `docs/` directory
- **Examples**: `tests/` directory
- **Issues**: GitHub Issues tab
- **Discussions**: GitHub Discussions

### Contact
- Create GitHub issue for bugs/features
- Use GitHub Discussions for questions
- Tag maintainers for urgent issues

### Mentorship
New contributors can request mentorship by:
- Creating an issue with `mentorship` label
- Asking in GitHub Discussions
- Reaching out to existing contributors

## Thank You

Thank you for contributing to change-site! Your contributions help make network configuration management easier and more reliable for everyone.