# Change Log

All notable changes to this project will be documented in [this file](http://keepachangelog.com/).

This project adheres to [Semantic Versioning](http://semver.org/).

## [0.12.0] - 5/18/2017
### Fixed
- Quote parameters as needed when passed to powershell

## [0.11.0] - 4/6/2017
### Fixed
- Allow parameter names with numeric characters
- Allow `-p:v` syntax for integer and string parameters
- Don't require command selection on initial prompt

## [0.10.0] - 2/3/2017
### Changed
- Don't create desktop shortcut

## [0.9.0] - 12/20/2016
### Fixed
- Fixed parsing of command sequence for sorting

## [0.8.0] - 12/15/2016
### Removed
- Removed 'Activity' module

## [0.7.1] - 12/14/2016
### Changed
- Minor logging/error handling tweaks

## [0.7.0] - 12/13/2016
### Changed
- Capture and log error information

## [0.6.0] - 12/13/2016
### Added
- Add '-RunAsAdmin' option

## [0.5.0] - 12/12/2016
### Added
- Add support for redirecting output to a log file

## [0.4.0] - 12/9/2016
### Added
- Add support for getting and setting configuration values
### Fixed
- Enhance string template escape character support
- Fix prompt message for 'Read-String'
### Changed
- Reduce logging for non-interactive command running
- Don't warn about environment variable mismatch

## [0.3.1] - 12/7/2016
### Changed
- Don't attempt to coerce error id into an event log event id.

## [0.3.0] - 12/7/2016
### Added
- Support alternative syntax ('[[name]]') for template strings.

## [0.2.0] - 12/7/2016
### Added
- Support alternative syntax for template strings.

## [0.1.0] - 12/6/2016
### Added
- Validate 'Read-String' input via regular expression.

## [0.0.24] - 12/2/2016
- Initial prototype release.
