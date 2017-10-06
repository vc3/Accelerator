# Change Log

All notable changes to this project will be documented in [this file](http://keepachangelog.com/).

This project adheres to [Semantic Versioning](http://semver.org/).

## [0.18.0] - 10/6/2017
### Added
- Add 'AcceleratorCommandFileName' global variable
- Add 'Accelerator.Configuration' module
- Add 'Accelerator.ServiceConnector' module
- Add 'Accelerator.EmailService' module
### Fixed
- Add check for no config file path

## [0.17.3] - 8/30/2017
### Fixed
- Don't double-up quotes around args

## [0.17.2] - 8/30/2017
### Fixed
- Fix creation of event log source

## [0.17.1] - 8/29/2017
### Fixed
- Fix install script

## [0.17.0] - 8/29/2017
### Changed
- Rename 'Confirm' to 'SkipConfirmation' to avoid conflict with "ShouldProcess"
- Attempt early detection of the '-Verbose' switch
- Support both '-Interactive' and '-LogFile'
### Fixed
- Handle parsing of "-Param:Value" parameters
- Handle arguments that FOR evaluates as wildcards

## [0.16.0] - 6/9/2017
### Fixed
- Only pause on error in a new window when in interactive mode

## [0.15.0] - 5/19/2017
### Fixed
- Fix issues with auto-pause on error

## [0.14.0] - 5/19/2017
### Fixed
- Print error before pausing if `Start-Accelerator` could not be called
- Silently continue if already elevated when -RunAsAdmin is specified without -UseStart
### Added
- Add 'RunAsAdmin' metadata option that validates elevated privileges if set

## [0.13.0] - 5/19/2017
### Fixed
- Don't set default window title for non-interactive call
### Added
- Pause on error when using -Interactive and not -UseStart
### Changed
- Don't attempt to reset Accelerator* global variables
- Minor formatting change

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
