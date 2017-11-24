import Foundation
import xcproj
import PathKit

let sampleProjectName: Path = "Sample.xcodeproj"
let basePath: Path = "/Users/fuzza/Development/integrator/"
let sampleProjectFolder: Path = basePath + "Test/Sample/"
let sampleProjectPath: Path = sampleProjectFolder + sampleProjectName
let targetProjectPath: Path = sampleProjectFolder + "Target.xcodeproj"

let target = "Sample"
let testTarget = target + "Tests"

let dependencyMap = [target : ["RxSwift", "RxCocoa"],
                     testTarget : ["RxSwift", "RxCocoa", "RxTest", "RxBlocking"]]

let inputFolder = "$(SRCROOT)/Carthage/Build/iOS/"
let outputFolder = "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/"

let scriptBody = "/usr/local/bin/carthage copy-frameworks"

//do {
  let project = try! XcodeProj(path: sampleProjectPath)
  print(project)

  let pbxproj = project.pbxproj

  let targets = pbxproj.objects.nativeTargets
    .map { (_, value) in value }
    .filter { dependencyMap[$0.name] != nil }

  for target in targets {
    print(target.name)
    
    let dependencies = dependencyMap[target.name] ?? [];
    print(dependencies)
    
    let inputPaths = dependencies.map { inputFolder + $0 + ".framework" }
    let outputPaths = dependencies.map { outputFolder + $0 + ".framework" }
    
    let reference = project.pbxproj.generateUUID(for: PBXShellScriptBuildPhase.self)
    
    let scriptPhase = PBXShellScriptBuildPhase(reference: reference,
                                               name: "Integrator",
                                               inputPaths: inputPaths,
                                               outputPaths: outputPaths,
                                               shellScript: scriptBody)
    
    pbxproj.objects.addObject(scriptPhase)
    target.buildPhases.append(reference)
    
    try! project.write(path: targetProjectPath, override: true)
  }
