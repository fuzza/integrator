import Foundation
import xcproj
import PathKit

let sampleProjectName: Path = "Sample.xcodeproj"
let basePath: Path = "/Users/fuzza/Development/integrator/"
let sampleProjectFolder: Path = basePath + "Test/Sample/"
let sampleProjectPath: Path = sampleProjectFolder + sampleProjectName
let carthageRelativePath: Path = "Carthage/Build/iOS"

let inputFolder = "$(SRCROOT)/Carthage/Build/iOS/"
let outputFolder = "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/"

let scriptBody = "/usr/local/bin/carthage copy-frameworks"

enum Dependency: Hashable {
  case carthage(String)
  
  var asString: String {
    switch self {
    case let .carthage(name):
      return name
    }
  }
  
  var hashValue: Int {
    switch self {
    case let .carthage(name):
      return name.hashValue
    }
  }
  
 static func ==(lhs: Dependency, rhs: Dependency) -> Bool {
    switch (lhs, rhs) {
    case let (.carthage(leftName), .carthage(rightName)):
      return leftName == rightName
    }
  }
}

struct Target {
  var name: String
  var dependencies: [Dependency]
}

class Project {
  var name: String
  var targets: [Target]
  
  func resolveDependencies(for target: Target) -> [Dependency] {
    return target.dependencies
  }
  
  func resolveAllDependencies() -> Set<Dependency> {
    let flattenedDependencies = targets
      .map { self.resolveDependencies(for: $0) }
      .flatMap { $0 }
    return Set(flattenedDependencies)
  }
  
  func target(_ name: String) -> Target? {
    return targets.first { $0.name == name }
  }
  
  init(name: String,
       targets: [Target]) {
    self.name = name
    self.targets = targets
  }
}

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

let projectFile = try! XcodeProj(path: sampleProjectPath)
let pbxproj = projectFile.pbxproj

// START FRAMEWORK SEARCH PATH

/*
 FRAMEWORK_SEARCH_PATHS = (
 "$(inherited)",
 "$(PROJECT_DIR)/Carthage/Build/iOS",
 );
 */

let rootObject = pbxproj.objects.projects.getReference(pbxproj.rootObject)!
let configurationListUid = rootObject.buildConfigurationList
let configurationList = pbxproj.objects.configurationLists.getReference(configurationListUid)!

let frameworkSearchPath: Path = "$(PROJECT_DIR)" + carthageRelativePath
configurationList.buildConfigurations
  .flatMap { pbxproj.objects.buildConfigurations.getReference($0) }
  .forEach { $0.buildSettings["FRAMEWORK_SEARCH_PATHS"] = frameworkSearchPath }

// END FRAMEWORK SEARCH PATH

// START CREATE PBXGROUP FOR FRAMEWORKS

/*
 6FD7C34B1FC8BA2700971D97 /* Frameworks */ = {
 isa = PBXGroup;
 children = (
 );
 name = Frameworks;
 sourceTree = "<group>";
 };
*/

let carthageGroupName = "Carthage"

let groupUid = pbxproj.generateUUID(for: PBXGroup.self)
let group = PBXGroup(reference: groupUid,
                     children: [],
                     sourceTree: .group,
                     name: carthageGroupName)
pbxproj.objects.addObject(group)

// END CREATE PBXGROUP FOR FRAMEWORKS

// START ADD PBXGROUP TO ROOT PROJECT GROUP

/*
 6FD7C2E91FC8982000971D97 = {
 isa = PBXGroup;
 children = (
 6FD7C2F41FC8982000971D97 /* Sample */,
 6FD7C3091FC8982000971D97 /* SampleTests */,
 6FD7C2F31FC8982000971D97 /* Products */,
 6FD7C34B1FC8BA2700971D97 /* Frameworks */,
 );
 sourceTree = "<group>";
 };
 */

let rootGroupUid = rootObject.mainGroup
let rootGroup = pbxproj.objects.groups.getReference(rootGroupUid)!
rootGroup.children.append(groupUid)

// END ADD PBXGROUP TO ROOT PROJECT GROUP

// ADD FRAMEWORKS AS FILE REFERENCES

/*
 Add PBXFileReference
 
 PBXFileReference
 
 6FD7C34C1FC8BA2700971D97 /* RxCocoa.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = RxCocoa.framework; path = Carthage/Build/iOS/RxCocoa.framework; sourceTree = "<group>"; };
 
 
 Add to frameworks group
 
 6FD7C34B1FC8BA2700971D97 /* Frameworks */ = {
 isa = PBXGroup;
 children = (
 6FD7C34C1FC8BA2700971D97 /* RxCocoa.framework */,
 );
 name = Frameworks;
 sourceTree = "<group>";
 };
 
 Add build file
 
 6FD7C34D1FC8BA2800971D97 /* RxCocoa.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 6FD7C34C1FC8BA2700971D97 /* RxCocoa.framework */; };
 */

struct LinkedFramework {
  var name: String
  var fileReferenceUid: String
  var buildFileUid: String
  
  var fileName: String {
    return name + ".framework"
  }
}

let linkedFrameworks = sample.resolveAllDependencies()
  .map { $0.asString }
  .map {
    LinkedFramework(name: $0,
                    fileReferenceUid: pbxproj.generateUUID(for: PBXFileReference.self),
                    buildFileUid: pbxproj.generateUUID(for: PBXBuildFile.self))
  }
  
linkedFrameworks
  .forEach {
    // Add file reference
    let fileReference = PBXFileReference(reference: $0.fileReferenceUid,
                                         sourceTree: .group,
                                         name: $0.fileName,
                                         lastKnownFileType: "wrapper.framework",
                                         path: carthageRelativePath.string + "/" + $0.fileName)
    pbxproj.objects.addObject(fileReference)
    
    // Add file reference to framework group
    group.children.append($0.fileReferenceUid)
  
    // Add build file
    let buildFile = PBXBuildFile(reference: $0.buildFileUid, fileRef: $0.fileReferenceUid)
    pbxproj.objects.addObject(buildFile)
  }

// END ADD FRAMEWORKS AS FILE REFERENCES

// SHELL SCRIPT RUN PHASE

pbxproj.objects.nativeTargets
  .map { (_, value) in value }
  .forEach { target in
    let targetModel = sample.target(target.name)!
    let dependencies = sample.resolveDependencies(for: targetModel).map { $0.asString }
    let inputPaths = dependencies.map { inputFolder + $0 + ".framework" }
    let outputPaths = dependencies.map { outputFolder + $0 + ".framework" }
    
    let reference = pbxproj.generateUUID(for: PBXShellScriptBuildPhase.self)
    let scriptPhase = PBXShellScriptBuildPhase(reference: reference,
                                               name: "Integrator",
                                               inputPaths: inputPaths,
                                               outputPaths: outputPaths,
                                               shellScript: scriptBody)
    
    pbxproj.objects.addObject(scriptPhase)
    target.buildPhases.append(reference)
    
    // Link binary with libraries
    
    /*
     Add PBXFrameworksBuildPhase
     
     isa = PBXFrameworksBuildPhase;
     buildActionMask = 2147483647;
     files = (
     6FD7C34D1FC8BA2800971D97 /* RxCocoa.framework in Frameworks */,
     );
     runOnlyForDeploymentPostprocessing = 0;
     
     */
    
    let frameworksBuildPhase = target.buildPhases
      .flatMap { pbxproj.objects.frameworksBuildPhases[$0] }
      .first!

    linkedFrameworks
      .filter { dependencies.contains($0.name) }
      .forEach { frameworksBuildPhase.files.append($0.buildFileUid) }
  }

try! projectFile.write(path: sampleProjectPath, override: true)

