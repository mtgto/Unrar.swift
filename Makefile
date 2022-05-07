TARGET=Cunrar.xcframework
ZIP=Cunrar.zip
FRAMEWORK_MACOS=build/Release/Cunrar.framework
FRAMEWORK_IPHONEOS=build/Release-iphoneos/Cunrar.framework
FRAMEWORK_IPHONESIMULATOR=build/Release-iphonesimulator/Cunrar.framework

all: $(TARGET)

clean:
	rm -rf $(TARGET) $(FRAMEWORK_MACOS) $(FRAMEWORK_IPHONEOS) $(FRAMEWORK_IPHONESIMULATOR)

$(ZIP): $(TARGET)
	zip -r $@ $<
	shasum -a 256 $@

$(TARGET): $(FRAMEWORK_MACOS) $(FRAMEWORK_IPHONEOS) $(FRAMEWORK_IPHONESIMULATOR)
	xcodebuild -create-xcframework -output $@ -framework $(FRAMEWORK_MACOS) -framework $(FRAMEWORK_IPHONEOS) -framework $(FRAMEWORK_IPHONESIMULATOR)

$(FRAMEWORK_MACOS):
	xcodebuild -sdk macosx -target Cunrar build

$(FRAMEWORK_IPHONEOS):
	xcodebuild -sdk iphoneos -target Cunrar build

$(FRAMEWORK_IPHONESIMULATOR):
	xcodebuild -sdk iphonesimulator -target Cunrar build
