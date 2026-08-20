XCODE_DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
XCODE_ENV = DEVELOPER_DIR="$(XCODE_DEVELOPER_DIR)"
XCODE_DERIVED_DATA = .build/xcode
XCODE_DESTINATION = platform=macOS,arch=$(shell uname -m)

.PHONY: build test app run archive xcode-build xcode-test xcode-open clean

build:
	$(XCODE_ENV) swift build

test:
	$(XCODE_ENV) swift test

app:
	$(XCODE_ENV) ./scripts/build-app.sh

run: app
	open .build/app/MousePortal.app

archive:
	$(XCODE_ENV) ./scripts/archive-app.sh

xcode-build:
	$(XCODE_ENV) xcodebuild -project MousePortal.xcodeproj -scheme MousePortal -configuration Debug -destination '$(XCODE_DESTINATION)' -derivedDataPath "$(XCODE_DERIVED_DATA)" build

xcode-test:
	$(XCODE_ENV) xcodebuild -project MousePortal.xcodeproj -scheme MousePortal -configuration Debug -destination '$(XCODE_DESTINATION)' -derivedDataPath "$(XCODE_DERIVED_DATA)" test

xcode-open:
	open MousePortal.xcodeproj

clean:
	$(XCODE_ENV) swift package clean
