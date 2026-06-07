APP = dist/Sadaa.app

# Command Line Tools (no Xcode.app) don't put Testing.framework on the dyld
# search path. We compile against it with -F and copy it next to the test
# bundle (@loader_path/../../../ rpath) so the runner can load it. Installing
# full Xcode makes all of this unnecessary but harmless.
CLT_FRAMEWORKS = /Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_INTEROP = /Library/Developer/CommandLineTools/Library/Developer/usr/lib/lib_TestingInterop.dylib
DEBUG_DIR = .build/arm64-apple-macosx/debug
SWIFT_TEST_FLAGS = -Xswiftc -F -Xswiftc $(CLT_FRAMEWORKS)

.PHONY: build test bundle run clean

build:
	swift build -c release

test:
	swift build --build-tests $(SWIFT_TEST_FLAGS)
	cp -R $(CLT_FRAMEWORKS)/Testing.framework $(DEBUG_DIR)/ 2>/dev/null || true
	cp $(CLT_INTEROP) $(DEBUG_DIR)/ 2>/dev/null || true
	swift test $(SWIFT_TEST_FLAGS)

bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp bundle/Info.plist $(APP)/Contents/Info.plist
	cp .build/release/SadaaApp $(APP)/Contents/MacOS/Sadaa
	codesign --force --sign - $(APP)

run: bundle
	open $(APP)

clean:
	rm -rf .build dist
