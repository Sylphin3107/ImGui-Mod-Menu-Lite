#export THEOS=/var/theos
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

SSZIP_DIR      = SSZipArchive
SSZIP_DEFINES  = -DHAVE_ARC4RANDOM_BUF -DHAVE_ICONV -DHAVE_INTTYPES_H -DHAVE_PKCRYPT -DHAVE_STDINT_H -DHAVE_WZAES -DHAVE_ZLIB -DZLIB_COMPAT
SSZIP_INCLUDES = -I$(SSZIP_DIR) -I$(SSZIP_DIR)/minizip
SSZIP_FILES    = $(SSZIP_DIR)/SSZipArchive.m $(wildcard $(SSZIP_DIR)/minizip/*.c) $(wildcard $(SSZIP_DIR)/minizip/compat/*.c)

FRAMEWORK_NAME               = aovnet
$(FRAMEWORK_NAME)_FRAMEWORKS =  UIKit Foundation Security QuartzCore CoreGraphics CoreText  AVFoundation Accelerate GLKit SystemConfiguration GameController
$(FRAMEWORK_NAME)_CCFLAGS    = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG $(SSZIP_DEFINES) $(SSZIP_INCLUDES)
$(FRAMEWORK_NAME)_CFLAGS     = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value $(SSZIP_DEFINES) $(SSZIP_INCLUDES)
$(FRAMEWORK_NAME)_LDFLAGS    = -lz -liconv

$(FRAMEWORK_NAME)_FILES = DrawView.mm HideView/HeeeNoScreenShotView.m $(wildcard LoadView/*.mm) $(wildcard ImGui/*.cpp) $(wildcard ImGui/*.mm) $(SSZIP_FILES)

include $(THEOS_MAKE_PATH)/framework.mk