# ESSOS-ALPHA

## Requirements

Operating System: macOS Sierra 10.12.4 or later

IDE: XCode 9.0 or later

Development Target: iOS 11 or later

## Usage

Build and run on XCode and target on one of the following <b>PHYSICAL</b> devices:
* iPhone 6S or later
* iPhone SE
* iPad (2017)
* All iPad Pro models

Note: Do not target on XCode simulators, which may not support some functionalities such as ARKit camera component.


## Features

* Add friends and chat
* Group chat
* Location share
* Group llocation share
* Post footprint
* View footprints by feeding into home page
* View footprints on map
* View footprints in AR mode
* Short distance AR location share


## Testings

### Unit Tests

Unit testing includes tests for all models components and functionalities. To check the tests, open the project in xcode and do command + U. If it does not compile, try click the title of the unit test directory. If tests pass, a green tick will show after the title of each test case.

We have made tests for:

- Login & email check
- fetching user profile
- fetching friend list
- posting footprint
- fetching footprints
- fetching conversations
- network


### UI Tests

UI tests can be run by the same way as unit tests. It contains tests for all the buttons and transition logic between views.

### Field Tests

Besides unit tests and UI tests, there are other features that need to be tests in field, such as location-sharing and footprint AR. All these features were tested before presentation at 2nd Oct. They should contain no bugs by now.

## Third Party Libraries Used
ARKit-CoreLocation @ProjectDent

License: https://github.com/ProjectDent/ARKit-CoreLocation/blob/master/LICENSE
