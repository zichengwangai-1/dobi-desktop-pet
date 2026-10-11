#!/usr/bin/env python3
"""Generate the two-target Xcode project without third-party dependencies."""
from pathlib import Path
import hashlib
import plistlib
import sys

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def add(key, isa, **values):
    identifier = hashlib.sha1(key.encode()).hexdigest()[:24].upper()
    objects[identifier] = {"isa": isa, **values}
    return identifier


def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def encode(value, level=0):
    if isinstance(value, dict):
        return "{\n" + "\n".join("\t" * (level + 1) + quote(k) + " = " + encode(v, level + 1) + ";" for k, v in value.items()) + "\n" + "\t" * level + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(v, level) for v in value) + ")"
    return quote(value)


def main():
    use_catalog = "--asset-catalog" in sys.argv
    source_files = sorted(ROOT.glob("Shared/**/*.swift"))
    app_files = sorted(ROOT.glob("App/*.swift"))
    widget_files = sorted(ROOT.glob("Widget/*.swift"))
    references = {}
    for file in source_files + app_files + widget_files:
        path = file.relative_to(ROOT).as_posix()
        references[path] = add(path, "PBXFileReference", lastKnownFileType="sourcecode.swift", path=path, sourceTree="SOURCE_ROOT")
    assets = add("assets", "PBXFileReference", lastKnownFileType="folder.assetcatalog", path="Resources/Assets.xcassets", sourceTree="SOURCE_ROOT")
    images = []
    for file in sorted((ROOT / "Resources/Assets.xcassets").glob("*.imageset/*.png")):
        images.append(add(str(file), "PBXFileReference", lastKnownFileType="image.png", path=file.relative_to(ROOT).as_posix(), sourceTree="SOURCE_ROOT"))
    icons = [add(str(file), "PBXFileReference", lastKnownFileType="image.png", path=file.relative_to(ROOT).as_posix(), sourceTree="SOURCE_ROOT")
             for file in sorted((ROOT / "Resources/AppIcons").glob("*.png"))]
    config = add("config", "PBXFileReference", lastKnownFileType="text.xcconfig", path="Configuration/Project.xcconfig", sourceTree="SOURCE_ROOT")
    app_product = add("app-product", "PBXFileReference", explicitFileType="wrapper.application", path="DobiHome.app", sourceTree="BUILT_PRODUCTS_DIR")
    widget_product = add("widget-product", "PBXFileReference", explicitFileType="wrapper.app-extension", path="DobiHomeWidget.appex", sourceTree="BUILT_PRODUCTS_DIR")
    products = add("products", "PBXGroup", children=[app_product, widget_product], name="Products", sourceTree="<group>")
    root_group = add("root-group", "PBXGroup", children=[*references.values(), assets, *images, *icons, config, products], sourceTree="<group>")

    targets = {}
    for name, files, product, is_widget in [
        ("DobiHomeWidget", source_files + widget_files, widget_product, True),
        ("DobiHome", source_files + app_files, app_product, False),
    ]:
        builds = [add(name + str(f), "PBXBuildFile", fileRef=references[f.relative_to(ROOT).as_posix()]) for f in files]
        sources = add(name + "sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=builds, runOnlyForDeploymentPostprocessing="0")
        resource_refs = [assets] if use_catalog else images + ([] if is_widget else icons)
        resources = add(name + "resources", "PBXResourcesBuildPhase", buildActionMask="2147483647",
                        files=[add(name + "resource" + ref, "PBXBuildFile", fileRef=ref) for ref in resource_refs], runOnlyForDeploymentPostprocessing="0")
        frameworks = add(name + "frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=[], runOnlyForDeploymentPostprocessing="0")
        phases = [sources, frameworks, resources]
        dependencies = []
        if not is_widget:
            embed = add("embed-widget-file", "PBXBuildFile", fileRef=widget_product, settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
            phases.append(add("embed-widget", "PBXCopyFilesBuildPhase", buildActionMask="2147483647", dstPath="", dstSubfolderSpec="13", files=[embed], name="Embed Widget", runOnlyForDeploymentPostprocessing="0"))
            dependencies.append(add("widget-dependency", "PBXTargetDependency", target=targets["DobiHomeWidget"]))
        settings = {
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "PRODUCT_BUNDLE_IDENTIFIER": "$(DOBI_BUNDLE_PREFIX).widget" if is_widget else "$(DOBI_BUNDLE_PREFIX)",
            "INFOPLIST_FILE": "Configuration/Widget-Info.plist" if is_widget else "Configuration/App-Info.plist",
            "CODE_SIGN_ENTITLEMENTS": "Configuration/Dobi.entitlements",
            "GENERATE_INFOPLIST_FILE": "NO", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
            "APPLICATION_EXTENSION_API_ONLY": "YES" if is_widget else "NO",
            "SKIP_INSTALL": "YES" if is_widget else "NO",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
        }
        if not is_widget and use_catalog: settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
        configs = [add(name + mode, "XCBuildConfiguration", baseConfigurationReference=config, name=mode,
                       buildSettings={**settings, "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O"}) for mode in ["Debug", "Release"]]
        configuration_list = add(name + "config-list", "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
        targets[name] = add(name + "target", "PBXNativeTarget", buildConfigurationList=configuration_list, buildPhases=phases, buildRules=[], dependencies=dependencies,
                            name=name, productName=name, productReference=product,
                            productType="com.apple.product-type.app-extension" if is_widget else "com.apple.product-type.application")
    project_configs = [add("project" + mode, "XCBuildConfiguration", name=mode, buildSettings={"CLANG_ENABLE_MODULES": "YES", "ENABLE_TESTABILITY": "YES" if mode == "Debug" else "NO", "DEBUG_INFORMATION_FORMAT": "dwarf"}) for mode in ["Debug", "Release"]]
    project_config_list = add("project-config-list", "XCConfigurationList", buildConfigurations=project_configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
    project = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2600"},
                  buildConfigurationList=project_config_list, compatibilityVersion="Xcode 15.0", developmentRegion="zh-Hans", hasScannedForEncodings="0", knownRegions=["zh-Hans", "en", "Base"],
                  mainGroup=root_group, productRefGroup=products, projectDirPath="", projectRoot="", targets=list(targets.values()))
    bundle = ROOT / "DobiHome.xcodeproj"
    bundle.mkdir(exist_ok=True)
    (bundle / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({"archiveVersion": "1", "classes": {}, "objectVersion": "60", "objects": objects, "rootObject": project}) + "\n")
    scheme_path = bundle / "xcshareddata/xcschemes"
    scheme_path.mkdir(parents=True, exist_ok=True)
    app_id = targets["DobiHome"]
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_id}" BuildableName="DobiHome.app" BlueprintName="DobiHome" ReferencedContainer="container:DobiHome.xcodeproj"/>'
    (scheme_path / "DobiHome.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n''')
    common = {"CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)", "CFBundleExecutable": "$(EXECUTABLE_NAME)", "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleName": "$(PRODUCT_NAME)", "CFBundleShortVersionString": "$(MARKETING_VERSION)", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)"}
    app_info = {**common, "CFBundleDisplayName": "杜宾", "CFBundlePackageType": "APPL", "LSRequiresIPhoneOS": True, "UILaunchScreen": {}, "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False}, "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"]}
    if not use_catalog:
        app_info["CFBundleIcons"] = {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["AppIcon20", "AppIcon29", "AppIcon40", "AppIcon60"]}}
    widget_info = {**common, "CFBundleDisplayName": "杜宾小组件", "CFBundlePackageType": "XPC!", "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"}}
    for filename, info in [("App-Info.plist", app_info), ("Widget-Info.plist", widget_info), ("Dobi.entitlements", {})]:
        (ROOT / "Configuration" / filename).write_bytes(plistlib.dumps(info))
    print(f"Generated: {bundle}")


if __name__ == "__main__":
    main()
