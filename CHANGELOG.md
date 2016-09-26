# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [2.0.1] - 2016-08-26

### Added
- Added Integration tests

### Changed
- Updated to have more consistent error messages

## [2.0.0] - 2016-08-20

### Added
- BATS Tests & Travis CI
- Example Config
- Check Newman is installed

### Changed
- Updated to Newman 3 CLI Args
- Enforced webhook arg

### Fixed
- [Slack Message Contains No Data](https://github.com/cameronoxley/Newman-to-Slack/issues/7)

### Deprecated
- Removed `--no_color` arg
- Removed `--url` arg
- Removed `--summary` arg
- Changed `--slack_webhook` to `--webhook`
- Changed `--newman_command` to `--webhook`
- Changed Config var `env` to `environment`

## [1.1.1] - 2016-08-20

### Added
- Added long args for each arg
- Added increasing verbosity

### Changed
- Cleaned up code

## [1.1.0] - 2016-03-18

### Added
- Added config file input for environment separation.
- Added better error message handling.

### Fixed
- Fixed argument validation bug.

## [1.0.2] - 2015-12-10

### Fixed
- Fixed bug causing script to fail for verbose and summary args.

## [1.0.1] - 2015-11-17

### Added
- Added check for errors in bash.

### Removed
- Removed file dependency by using variables instead of temporary files.
- Removed unnecessary file parsing.

### Changed
- Cleaned up internal variable handling.

### Fixed
- [Ctrl-C leaves behind files](https://github.com/cameronoxley/Newman-to-Slack/issues/1)
- [Remove tmp file dependency](https://github.com/cameronoxley/Newman-to-Slack/issues/2)

## [1.0.0] - 2015-11-16
- First Add


