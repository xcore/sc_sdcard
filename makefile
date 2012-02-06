# This variable should contain a space separated list of all
# the directories containing buildable applications (usually
# prefixed with the app_ prefix
BUILD_SUBDIRS = app_sdcard_test

XMOS_MAKE_PATH ?= ..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.toplevel
