APP = dist/Sadaa.app

.PHONY: build test bundle run clean

build:
	swift build -c release

test:
	swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks

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
