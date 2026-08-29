# Adds the AmbientWidgets extension target to Runner.xcodeproj.
#
# Kept in the repo and made idempotent rather than run once by hand, because a
# widget extension is the kind of target that quietly goes missing in a merge —
# and a project that has lost it still builds, it just silently stops shipping
# the lock screen. Re-running this repairs it.
#
#   ruby ios/add_widget_target.rb
#
# Uses the xcodeproj gem that ships with CocoaPods, so there is nothing extra
# to install on a machine that can already build the app.
$LOAD_PATH.unshift(*Dir.glob('/opt/homebrew/Cellar/cocoapods/*/libexec/gems/*/lib'))
$LOAD_PATH.unshift(*Dir.glob('/usr/local/Cellar/cocoapods/*/libexec/gems/*/lib'))
require 'xcodeproj'

ROOT = File.expand_path(__dir__)
PROJECT = File.join(ROOT, 'Runner.xcodeproj')
TARGET_NAME = 'AmbientWidgets'
APP_BUNDLE_ID = 'com.r13.aqademiq'
APP_GROUP = 'group.com.r13.aqademiq.ambient'
TEAM = 'SXN54W6F6T'

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target missing'

existing = project.targets.find { |t| t.name == TARGET_NAME }
if existing
  puts "#{TARGET_NAME} already present — refreshing its sources."
  existing.source_build_phase.files.to_a.each { |f| existing.source_build_phase.remove_file_reference(f.file_ref) }
else
  existing = project.new_target(
    :app_extension,
    TARGET_NAME,
    :ios,
    # WidgetKit needs 14, Live Activities 16.1. The *app* stays where it is:
    # raising its floor would drop users for a feature they cannot see anyway,
    # so only the extension is modern and everything inside is availability
    # gated.
    '16.1',
  )
end

group = project.main_group.find_subpath(TARGET_NAME, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(TARGET_NAME)

# Sources: every Swift file in the folder, so adding one needs no bookkeeping.
Dir.glob(File.join(ROOT, TARGET_NAME, '*.swift')).sort.each do |path|
  name = File.basename(path)
  ref = group.files.find { |f| f.path == name } || group.new_reference(name)
  existing.add_file_references([ref])
end

# Assets, if the extension ever gets its own.
assets = File.join(ROOT, TARGET_NAME, 'Assets.xcassets')
if File.exist?(assets)
  ref = group.files.find { |f| f.path == 'Assets.xcassets' } || group.new_reference('Assets.xcassets')
  existing.resources_build_phase.add_file_reference(ref)
end

existing.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{APP_BUNDLE_ID}.#{TARGET_NAME}"
  s['INFOPLIST_FILE'] = "#{TARGET_NAME}/Info.plist"
  s['CODE_SIGN_ENTITLEMENTS'] = "#{TARGET_NAME}/#{TARGET_NAME}.entitlements"
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.1'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['DEVELOPMENT_TEAM'] = TEAM
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SKIP_INSTALL'] = 'YES'
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

# Embed the extension in the app, or it builds and ships nothing.
embed = app.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Embed Foundation Extensions' }
embed ||= app.new_copy_files_build_phase('Embed Foundation Extensions').tap do |phase|
  phase.symbol_dst_subfolder_spec = :plug_ins
end
unless embed.files_references.include?(existing.product_reference)
  embed.add_file_reference(existing.product_reference).tap do |f|
    f.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
end
app.add_dependency(existing) unless app.dependencies.any? { |d| d.target == existing }

# Embed the extension *before* Flutter's "Thin Binary" script.
#
# Xcode adds this phase last, which puts it after the script that rewrites the
# app binary — the two then declare overlapping outputs and the build fails with
# "Cycle inside Runner". Nothing warns about it until the extension exists, so
# the ordering is enforced here rather than remembered.
thin = app.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
current = app.build_phases.index(embed)
if thin && current && current > thin
  app.build_phases.delete_at(current)
  app.build_phases.insert(thin, embed)
  puts 'Moved "Embed Foundation Extensions" ahead of "Thin Binary" to break the build cycle.'
end

# The app needs the same App Group, or the two halves cannot see each other.
app.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

project.save
puts "#{TARGET_NAME} target ready (bundle #{APP_BUNDLE_ID}.#{TARGET_NAME}, group #{APP_GROUP})."
