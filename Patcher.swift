import Foundation
import xcproj
import PathKit

let sampleProjectName: Path = "Sample.xcodeproj"
let basePath: Path = "/Users/fuzza/Development/integrator/"
let sampleProjectFolder: Path = basePath + "Test/Sample/"
let sampleProjectPath: Path = sampleProjectFolder + sampleProjectName
let targetProjectPath: Path = sampleProjectFolder + "Target.xcodeproj"
let carthageRelativePath: Path = "Carthage/Build/iOS"
let target = "Sample"
let testTarget = target + "Tests"

let dependencyMap = [target : ["RxSwift", "RxCocoa"],
                     testTarget : ["RxSwift", "RxCocoa", "RxTest", "RxBlocking"]]

let inputFolder = "$(SRCROOT)/Carthage/Build/iOS/"
let outputFolder = "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/"

let scriptBody = "/usr/local/bin/carthage copy-frameworks"

enum Dependency {
  case carthage(String)
}

class Project {
  var name: String
  var testTarget: String
  
  var dependencies: [Dependency]
  var testDependencies: [Dependency]
  
  var resolvedDependencies: [Dependency] {
    return dependencies
  }
  
  var resolvedTestDependencies: [Dependency] {
    return allDependencies
  }
  
  var allDependencies: [Dependency] {
    return dependencies + testDependencies
  }
  
  init(name: String,
       testTarget: String? = nil,
       dependencies: [Dependency] = [],
       testDependencies: [Dependency] = []) {
    self.name = name
    self.testTarget = testTarget ?? name + "Tests"
    self.dependencies = dependencies
    self.testDependencies = testDependencies
  }
}

let Sample = Project(
  name: "Sample",
  dependencies: [
    .carthage("RxSwift"),
    .carthage("RxCocoa")
  ],
  testDependencies: [
    .carthage("RxTest"),
    .carthage("RxBlocking")
  ])

let project = try! XcodeProj(path: sampleProjectPath)
print(project)

let pbxproj = project.pbxproj

// START FRAMEWORK SEARCH PATH

/*
 FRAMEWORK_SEARCH_PATHS = (
 "$(inherited)",
 "$(PROJECT_DIR)/Carthage/Build/iOS",
 );
 */

let searchPath: Path = "$(PROJECT_DIR)" + carthageRelativePath

let projectObject = pbxproj.objects.projects.getReference(pbxproj.rootObject)!
let configurationList = pbxproj.objects.configurationLists.getReference(projectObject.buildConfigurationList)!

configurationList.buildConfigurations
  .flatMap { pbxproj.objects.buildConfigurations.getReference($0) }
  .forEach { $0.buildSettings["FRAMEWORK_SEARCH_PATHS"] = searchPath; print($0.name) }

let targets = pbxproj.objects.nativeTargets
  .map { (_, value) in value }
  .filter { dependencyMap[$0.name] != nil }

// END FRAMEWORK SEARCH PATH

// SHELL SCRIPT RUN PHASE
for target in targets {
  print(target.name)
  
  let dependencies = dependencyMap[target.name] ?? [];
  print(dependencies)
  
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
}
  /*
   Add PBXFileReference
   
   6FD7C34C1FC8BA2700971D97 /* RxCocoa.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = RxCocoa.framework; path = Carthage/Build/iOS/RxCocoa.framework; sourceTree = "<group>"; };
   
   */
  
  /*
   Add PBXBuildFile
   
   6FD7C34D1FC8BA2800971D97 /* RxCocoa.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 6FD7C34C1FC8BA2700971D97 /* RxCocoa.framework */; };
   
   */
  
  /*
   Add PBXGroup
   
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
   
   6FD7C34B1FC8BA2700971D97 /* Frameworks */ = {
   isa = PBXGroup;
   children = (
   6FD7C34C1FC8BA2700971D97 /* RxCocoa.framework */,
   );
   name = Frameworks;
   sourceTree = "<group>";
   };
   
   */
  
  /*
   Add PBXFrameworksBuildPhase
   
   isa = PBXFrameworksBuildPhase;
   buildActionMask = 2147483647;
   files = (
   6FD7C34D1FC8BA2800971D97 /* RxCocoa.framework in Frameworks */,
   );
   runOnlyForDeploymentPostprocessing = 0;
   
   */

try! project.write(path: sampleProjectPath, override: true)

