#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'TranslateDot.xcodeproj')
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2620'
project.root_object.attributes['LastUpgradeCheck'] = '2620'

app_target = project.new_target(:application, 'TranslateDot', :osx, '15.0')
test_target = project.new_target(:unit_test_bundle, 'TranslateDotTests', :osx, '15.0')
test_target.add_dependency(app_target)

app_files = %w[
  App/TranslateDotApp.swift
  App/AppDelegate.swift
  App/AppState.swift
  App/Localization.swift
  Settings/AppSettings.swift
  Settings/SettingsView.swift
  Settings/LanguageModelsView.swift
  HotKey/HotKeyManager.swift
  Accessibility/AccessibilityPermissionManager.swift
  Accessibility/AXSelectedTextProvider.swift
  Accessibility/ClipboardSelectedTextProvider.swift
  Accessibility/SelectedTextResult.swift
  Capture/ScreenCapturePermissionManager.swift
  Capture/ScreenCaptureProvider.swift
  Capture/ScreenshotSelectionController.swift
  Capture/VisionTextRecognizer.swift
  Translation/TranslationCoordinator.swift
  Translation/AppleTranslationHost.swift
  Translation/TranslationRequest.swift
  Translation/TranslationResult.swift
  Translation/LanguageRouter.swift
  Panel/TranslationPanel.swift
  Panel/TranslationPanelController.swift
  Panel/PanelPositioner.swift
  Panel/TranslationPanelView.swift
  Panel/TranslationSuccessView.swift
  Features/TranslationViewModel.swift
].freeze

test_files = %w[
  LanguageRouterTests.swift
  PanelPositionerTests.swift
  TranslationViewModelTests.swift
  ScreenCaptureCoordinateConverterTests.swift
].freeze

app_group = project.main_group.new_group('TranslateDot', 'TranslateDot')
groups = {}
app_files.each do |relative_path|
  directory = File.dirname(relative_path)
  group = groups[directory] ||= app_group.new_group(directory, directory)
  reference = group.new_file(File.basename(relative_path))
  app_target.source_build_phase.add_file_reference(reference)
end

resources_group = app_group.new_group('Resources', 'Resources')
assets = resources_group.new_file('Assets.xcassets')
app_target.resources_build_phase.add_file_reference(assets)
localizations = resources_group.new_file('Localizable.xcstrings')
app_target.resources_build_phase.add_file_reference(localizations)
resources_group.new_file('Info.plist')
brand_group = resources_group.new_group('Brand', 'Brand')
brand_group.new_file('TranslateDotLogoOriginal.png')
brand_group.new_file('TranslateDotIconMaster.png')

tests_group = project.main_group.new_group('TranslateDotTests', 'TranslateDotTests')
test_files.each do |relative_path|
  reference = tests_group.new_file(relative_path)
  test_target.source_build_phase.add_file_reference(reference)
end

package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
package.repositoryURL = 'https://github.com/sindresorhus/KeyboardShortcuts.git'
package.requirement = {
  'kind' => 'upToNextMajorVersion',
  'minimumVersion' => '3.1.0'
}
project.root_object.package_references << package

keyboard_shortcuts = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
keyboard_shortcuts.package = package
keyboard_shortcuts.product_name = 'KeyboardShortcuts'
app_target.package_product_dependencies << keyboard_shortcuts

package_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
package_build_file.product_ref = keyboard_shortcuts
app_target.frameworks_build_phase.files << package_build_file

project.build_configurations.each do |config|
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
end

app_target.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.simon.translatedot',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'TranslateDot/Resources/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_STYLE' => 'Automatic',
    'ENABLE_APP_SANDBOX' => 'NO',
    'ENABLE_HARDENED_RUNTIME' => 'YES',
    'SWIFT_VERSION' => '6.0',
    'SWIFT_STRICT_CONCURRENCY' => 'complete',
    'MACOSX_DEPLOYMENT_TARGET' => '15.0',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks',
    'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS' => 'YES'
  )
end

test_target.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.simon.translatedot.tests',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic',
    'ENABLE_APP_SANDBOX' => 'NO',
    'SWIFT_VERSION' => '6.0',
    'SWIFT_STRICT_CONCURRENCY' => 'complete',
    'MACOSX_DEPLOYMENT_TARGET' => '15.0',
    'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/TranslateDot.app/Contents/MacOS/TranslateDot',
    'BUNDLE_LOADER' => '$(TEST_HOST)'
  )
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_test_target(test_target)
scheme.set_launch_target(app_target)
scheme.save_as(project_path, 'TranslateDot', true)

puts "Generated #{project_path}"
