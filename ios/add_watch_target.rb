# Adds the AqademiqWatch watchOS app target to Runner.xcodeproj.
#
# Same reasoning as add_widget_target.rb, and the same failure mode: a project
# that has lost this target still builds and still ships — it just quietly stops
# shipping the watch app, and nobody notices until someone looks at their wrist.
# Idempotent, so re-running repairs rather than duplicates.
#
#   ruby ios/add_watch_target.rb
#
# Uses the xcodeproj gem that ships with CocoaPods, so there is nothing extra to
# install on a machine that can already build the app.
$LOAD_PATH.unshift(*Dir.glob('/opt/homebrew/Cellar/cocoapods/*/libexec/gems/*/lib'))
$LOAD_PATH.unshift(*Dir.glob('/usr/local/Cellar/cocoapods/*/libexec/gems/*/lib'))
require 'xcodeproj'

ROOT = File.expand_path(__dir__)
PROJECT = File.join(ROOT, 'Runner.xcodeproj')
TARGET_NAME = 'AqademiqWatch'
APP_BUNDLE_ID = 'com.r13.aqademiq'
TEAM = 'SXN54W6F6T'
# watchOS 10 is the floor: the screen uses .containerBackground(for: .navigation),
# which is where the modern full-bleed watch layout starts.
DEPLOYMENT = '10.0'

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target missing'

watch = project.targets.find { |t| t.name == TARGET_NAME }
if watch
  puts "#{TARGET_NAME} already present — refreshing its sources."
  watch.source_build_phase.files.to_a.each do |f|
    watch.source_build_phase.remove_file_reference(f.file_ref)
  end
else
  # A single-target watch app is a plain application whose SDK is watchOS, not
  # the old :watch2_app product type — that one is half of the two-target
  # layout Apple retired, and pairing it with a modern Info.plist produces a
  # bundle the simulator refuses to install.
  watch = project.new_target(:application, TARGET_NAME, :watchos, DEPLOYMENT)
end

group = project.main_group.find_subpath(TARGET_NAME, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(TARGET_NAME)

# Sources: every Swift file in the folder, so adding one needs no bookkeeping.
Dir.glob(File.join(ROOT, TARGET_NAME, '*.swift')).sort.each do |path|
  name = File.basename(path)
  ref = group.files.find { |f| f.path == name } || group.new_reference(name)
  watch.add_file_references([ref])
end

# Ada belongs to all three renderers.
#
# She is a Flutter CustomPainter in the app and a Shape in the widget
# extension; the watch gets the extension's copy rather than a third one,
# because the spec's whole §4 is that the three must not drift. AdaShape.swift
# is pure SwiftUI with no WidgetKit in it, so it compiles for watchOS unchanged.
shared_group = project.main_group.find_subpath('AmbientWidgets', true)
shared_ref = shared_group.files.find { |f| f.path == 'AdaShape.swift' }
abort 'AdaShape.swift missing — run add_widget_target.rb first' unless shared_ref
watch.source_build_phase.add_file_reference(shared_ref)

# The asset catalog, so the icon actually ships.
assets = group.files.find { |f| f.path == 'Assets.xcassets' } ||
         group.new_reference('Assets.xcassets')
unless watch.resources_build_phase.files_references.include?(assets)
  watch.resources_build_phase.add_file_reference(assets)
end

# The phone half of the link has to be in the *app* target, not this one.
#
# It is easy to add a file to ios/Runner/ and assume Xcode noticed. It does not,
# and the failure is a compile error in a file that plainly exists
# ("cannot find 'WatchBridge' in scope"), which sends you looking at the wrong
# thing entirely.
runner_group = project.main_group.find_subpath('Runner', true)
bridge = runner_group.files.find { |f| f.path == 'WatchBridge.swift' } ||
         runner_group.new_reference('WatchBridge.swift')
unless app.source_build_phase.files_references.include?(bridge)
  app.source_build_phase.add_file_reference(bridge)
end

watch.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = TARGET_NAME
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{APP_BUNDLE_ID}.watchkitapp"
  s['INFOPLIST_FILE'] = "#{TARGET_NAME}/Info.plist"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['SDKROOT'] = 'watchos'
  s['WATCHOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
  s['TARGETED_DEVICE_FAMILY'] = '4'
  s['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
  s['SWIFT_VERSION'] = '5.0'
  s['DEVELOPMENT_TEAM'] = TEAM
  s['CODE_SIGN_STYLE'] = 'Automatic'
  # YES, like the widget extension. This target is *embedded* by Runner's copy
  # phase, not installed beside it — and NO puts a second AqademiqWatch.app at
  # the archive root, which leaves the archive with two applications and no way
  # for Xcode to tell which is the product. The symptom is far from the cause:
  # the archive builds, then export dies with "Unknown Distribution Error" and
  # `expected one {} but found app-store-connect`, because with no
  # ApplicationProperties the set of valid distribution methods is empty.
  s['SKIP_INSTALL'] = 'YES'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
  # A watch app without an icon archives fine and is rejected on upload, which
  # is a slow way to find out. It reuses the phone's 1024 rather than carrying
  # a second artwork to keep in step.
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

# The phone app carries the watch app inside it.
#
# dstSubfolderSpec 16 is "Products Directory"; the Watch subfolder is where the
# system looks when deciding whether an installed iPhone app brings a watch app
# with it. Get this wrong and the target builds perfectly and installs nothing.
embed = app.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Embed Watch Content' }
embed ||= app.new_copy_files_build_phase('Embed Watch Content').tap do |phase|
  phase.symbol_dst_subfolder_spec = :products_directory
  phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
end
unless embed.files_references.include?(watch.product_reference)
  embed.add_file_reference(watch.product_reference).tap do |f|
    f.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
end

# Build the watch before embedding it.
app.add_dependency(watch) unless app.dependencies.any? { |d| d.target == watch }

# Same ordering trap as the widget extension: Flutter's "Thin Binary" phase
# rewrites the app bundle, and anything copied in after it is either thinned
# away or trips "Cycle inside Runner". Embed first, thin second.
thin = app.build_phases.index do |p|
  p.respond_to?(:name) && p.name.to_s.include?('Thin Binary')
end
current = app.build_phases.index(embed)
if thin && current && current > thin
  app.build_phases.delete_at(current)
  app.build_phases.insert(thin, embed)
end

project.save
puts "#{TARGET_NAME} wired: #{watch.source_build_phase.files.count} sources, embedded in Runner."
