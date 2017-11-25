# integrator

This is a PoC of an automatic integration for dynamic frameworks pre-built with Carthage to XCode project.

# notes

All integrations are made on `Sample.xcodepoj` that is placed in `Test/Sample/` folder.
Integration code is contained in `Patcher.swift` in repository root folder.

# pre-conditions

1. Install [Carthage](https://github.com/Carthage/Carthage)
2. Install [Marathon](https://github.com/JohnSundell/Marathon)

# running sample

1. Install carthage dependencies by invoking `carhtage bootstrap --platform ios --no-use-binaries` in Sample project folder
2. Open `Sample.xcworkspace` or `Sample.xcodeproj` in XCode
3. Go to root repository folder and execute `marathon run Patcher`
4. Check sample project to see that following were done:
  * Carthage folder is added to project's `FRAMEWORK_SEARCH_PATHS`
  * Frameworks are added to `Carthage` group in project root
  * Frameworks are added to `Link binary with libraries` for targets according to DSL congifuration
  * Copy-frameworks script phases are added to target's build phases according to DSL congifuration

# editing sample

Currently DSL sample is hard-coded in `Patcher.swift` and looks like following:

```swift
  let sample = Project(
  name: "Sample",
  targets: [
    Target(
      name: "Sample",
      dependencies: [
        .carthage("RxSwift"),
        .carthage("RxCocoa")
      ]),
    Target(
      name: "SampleTests",
      dependencies: [
        .carthage("RxSwift"),
        .carthage("RxCocoa"),
        .carthage("RxTest"),
        .carthage("RxBlocking")
      ])
  ]
)
```

To edit `Patcher.swift` run `marathon edit Patcher`

# upcoming plans

Since this is very early version of prototype there is a lot of missing functionality:

 - [ ] check if dependencies are already integrated (currently it's simply duplicates all records)
 - [ ] get rid of mess in script code
 - [ ] convert from swift script to command line tool
 - [ ] add some way of automated testing (unit/integration)
 - [ ] load DSL from separate config file
 - [ ] remove dependencies that were integrated previously but are missing in DSL
 - [ ] ability to de-integrate
 - [ ] add workspaces support
 - [ ] add support for integrating local frameworks within the same workspace

to be continued ...
