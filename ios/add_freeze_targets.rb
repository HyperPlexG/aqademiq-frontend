# Adds the three App freeze extension targets to Runner.xcodeproj
# (APP_FREEZE.md §5):
#
#   FreezeMonitor       com.r13.aqademiq.freeze-monitor  DeviceActivityMonitor — the schedule
#   FreezeShield        com.r13.aqademiq.freeze-shield   ShieldConfiguration   — the frozen screen's copy
#   FreezeShieldAction  com.r13.aqademiq.freeze-action   ShieldAction          — its two buttons
#
# Same reasoning as add_widget_target.rb, and the same failure mode, only
# worse: a project that has lost one of these still builds and still ships —
# frosts simply stop the moment Aqademiq is closed, or the frozen screen falls
# back to Apple's generic copy, or Thaw does nothing. Idempotent, so re-running
# repairs rather than duplicates.
#
#   ruby ios/add_freeze_targets.rb
#
# Uses the xcodeproj gem that ships with CocoaPods, so there is nothing extra
# to install on a machine that can already build the app.
$LOAD_PATH.unshift(*Dir.glob('/opt/homebrew/Cellar/cocoapods/*/libexec/gems/*/lib'))
$LOAD_PATH.unshift(*Dir.glob('/usr/local/Cellar/cocoapods/*/libexec/gems/*/lib'))
require 'xcodeproj'

ROOT = File.expand_path(__dir__)
PROJECT = File.join(ROOT, 'Runner.xcodeproj')
APP_BUNDLE_ID = 'com.r13.aqademiq'
APP_GROUP = 'group.com.r13.aqademiq.shared'
TEAM = 'R6YW5K2YSP'
# Individual (self) Screen Time authorization starts at iOS 16. The *app* stays
# where it is, as with the widget extension: only the extensions are modern,
# and everything Runner does with Screen Time is availability gated.
DEPLOYMENT = '16.0'

# Compiled into the app and into all three extensions — one copy of the rules,
# so a frost reads the same whether Aqademiq is open or not.
SHARED = 'FreezeShared'
XCCONFIG = 'FreezeExtension.xcconfig'

EXTENSIONS = [
  { name: 'FreezeMonitor', bundle: "#{APP_BUNDLE_ID}.freeze-monitor",
    frameworks: %w[DeviceActivity ManagedSettings FamilyControls UserNotifications] },
  { name: 'FreezeShield', bundle: "#{APP_BUNDLE_ID}.freeze-shield",
    frameworks: %w[ManagedSettingsUI ManagedSettings FamilyControls DeviceActivity UserNotifications] },
  { name: 'FreezeShieldAction', bundle: "#{APP_BUNDLE_ID}.freeze-action",
    frameworks: %w[ManagedSettings FamilyControls DeviceActivity UserNotifications] },
].freeze

# Runner links these weakly: its floor is iOS 13 and none of them exist before
# 15, so a strong link would stop the app launching on 13 and 14 at all.
WEAK_IN_APP = %w[FamilyControls ManagedSettings DeviceActivity].freeze

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target missing'

# --- The shared sources --------------------------------------------------------

shared_group = project.main_group.find_subpath(SHARED, true)
shared_group.set_source_tree('SOURCE_ROOT')
shared_group.set_path(SHARED)

shared_refs = Dir.glob(File.join(ROOT, SHARED, '*.swift')).sort.map do |path|
  name = File.basename(path)
  shared_group.files.find { |f| f.path == name } || shared_group.new_reference(name)
end
abort "No Swift files in #{SHARED}/" if shared_refs.empty?

xcconfig_ref = shared_group.files.find { |f| f.path == XCCONFIG } || shared_group.new_reference(XCCONFIG)

# --- The app's half ------------------------------------------------------------

# The rules and the store go into Runner too: `applyPolicy` re-shields and
# reschedules from the app's own process. And the channel handler, which —
# like every file in ios/Runner — Xcode does not pick up by itself; a missing
# one is a "cannot find 'AppFreezePlugin' in scope" in AppDelegate.
runner_group = project.main_group.find_subpath('Runner', true)
plugin_ref = runner_group.files.find { |f| f.path == 'AppFreezePlugin.swift' } ||
             runner_group.new_reference('AppFreezePlugin.swift')
(shared_refs + [plugin_ref]).each do |ref|
  app.source_build_phase.add_file_reference(ref, true)
end

app.build_configurations.each do |config|
  flags = config.build_settings['OTHER_LDFLAGS'] || ['$(inherited)']
  flags = flags.split(' ') if flags.is_a?(String)
  flags = ['$(inherited)'] + flags unless flags.include?('$(inherited)')
  WEAK_IN_APP.each do |framework|
    linked = flags.each_cons(2).any? { |a, b| a == '-weak_framework' && b == framework }
    flags += ['-weak_framework', framework] unless linked
  end
  config.build_settings['OTHER_LDFLAGS'] = flags
  # The app needs the family-controls entitlement and the App Group, both in
  # this file.
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# The app's own Family Controls entitlement. Kept out of the checked-in file
# until this script runs, because a distribution export carrying it fails to
# sign until Apple approves Family Controls for the bundle id — running this
# script is the decision to turn App freeze on. Idempotent like the rest.
entitlements_path = File.join(ROOT, 'Runner', 'Runner.entitlements')
entitlements = File.read(entitlements_path)
unless entitlements.include?('<key>com.apple.developer.family-controls</key>')
  marker = "\t<key>com.apple.security.application-groups</key>"
  abort "Runner.entitlements has no App Group key to insert before — add family-controls by hand." unless entitlements.include?(marker)
  entitlements = entitlements.sub(marker, "\t<key>com.apple.developer.family-controls</key>\n\t<true/>\n#{marker}")
  File.write(entitlements_path, entitlements)
  puts 'Runner.entitlements: added com.apple.developer.family-controls'
end

# --- The extensions ------------------------------------------------------------

embed = app.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Embed Foundation Extensions' }
embed ||= app.new_copy_files_build_phase('Embed Foundation Extensions').tap do |phase|
  phase.symbol_dst_subfolder_spec = :plug_ins
end

EXTENSIONS.each do |spec|
  name = spec[:name]
  abort "#{name}/ missing" unless File.directory?(File.join(ROOT, name))

  target = project.targets.find { |t| t.name == name }
  if target
    puts "#{name} already present — refreshing its sources."
    target.source_build_phase.files.to_a.each { |f| target.source_build_phase.remove_file_reference(f.file_ref) }
  else
    target = project.new_target(:app_extension, name, :ios, DEPLOYMENT)
  end

  group = project.main_group.find_subpath(name, true)
  group.set_source_tree('SOURCE_ROOT')
  group.set_path(name)

  # Its own sources — every Swift file in its folder, so adding one needs no
  # bookkeeping — and the shared ones.
  Dir.glob(File.join(ROOT, name, '*.swift')).sort.each do |path|
    file = File.basename(path)
    ref = group.files.find { |f| f.path == file } || group.new_reference(file)
    target.source_build_phase.add_file_reference(ref, true)
  end
  shared_refs.each { |ref| target.source_build_phase.add_file_reference(ref, true) }

  # Listed in the group so they show in Xcode; neither is compiled.
  ["Info.plist", "#{name}.entitlements"].each do |file|
    group.files.find { |f| f.path == file } || group.new_reference(file)
  end

  # The privacy manifest (App Group UserDefaults, reason 1C8F.1) has to be
  # *in* the extension's bundle to count, so it is a resource, not just a
  # file in the group: required-reason APIs are declared per bundle, and an
  # extension is a bundle of its own. Runner's settings are not touched.
  # Idempotent: avoid_duplicates leaves an existing entry alone.
  privacy = 'PrivacyInfo.xcprivacy'
  abort "#{name}/#{privacy} missing" unless File.exist?(File.join(ROOT, name, privacy))
  privacy_ref = group.files.find { |f| f.path == privacy } || group.new_reference(privacy)
  target.resources_build_phase.add_file_reference(privacy_ref, true)

  # Screen Time frameworks. `import` would autolink them anyway; listing them
  # makes what the extension needs visible in the target.
  target.add_system_framework(spec[:frameworks])

  target.build_configurations.each do |config|
    # Generated.xcconfig for Flutter's version, and nothing from Pods — see the
    # comment in FreezeExtension.xcconfig.
    config.base_configuration_reference = xcconfig_ref
    s = config.build_settings
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['PRODUCT_BUNDLE_IDENTIFIER'] = spec[:bundle]
    s['INFOPLIST_FILE'] = "#{name}/Info.plist"
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
    s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
    s['SDKROOT'] = 'iphoneos'
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['DEVELOPMENT_TEAM'] = TEAM
    s['CODE_SIGN_STYLE'] = 'Automatic'
    # Embedded by Runner's copy phase, not installed beside it — NO would put a
    # second product at the archive root (see add_watch_target.rb).
    s['SKIP_INSTALL'] = 'YES'
    s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    # In lockstep with the app, from pubspec.yaml via Generated.xcconfig.
    s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
    s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
    s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  end

  # Embed it in the app, or it builds and ships nothing.
  unless embed.files_references.include?(target.product_reference)
    embed.add_file_reference(target.product_reference).tap do |f|
      f.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
    end
  end
  app.add_dependency(target) unless app.dependencies.any? { |d| d.target == target }

  puts "#{name} ready (bundle #{spec[:bundle]}, #{target.source_build_phase.files.count} sources)."
end

# Embed the extensions *before* Flutter's "Thin Binary" script — the same trap
# add_widget_target.rb guards: Xcode appends a new copy phase last, after the
# script that rewrites the app bundle, and the two then fail the build with
# "Cycle inside Runner".
thin = app.build_phases.index { |p| p.respond_to?(:name) && p.name.to_s.include?('Thin Binary') }
current = app.build_phases.index(embed)
if thin && current && current > thin
  app.build_phases.delete_at(current)
  app.build_phases.insert(thin, embed)
  puts 'Moved "Embed Foundation Extensions" ahead of "Thin Binary" to break the build cycle.'
end

project.save
puts "App freeze targets wired (group #{APP_GROUP}, team #{TEAM})."
