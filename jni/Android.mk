TOP_PATH := $(call my-dir)/..

# Test
include $(CLEAR_VARS)
LOCAL_PATH := $(TOP_PATH)/src
LOCAL_MODULE    := test_rilproxy
LOCAL_SRC_FILES := main.c
LOCAL_CFLAGS += -fPIE -Wall -Werror -Wextra
LOCAL_LDFLAGS += -fPIE -pie
include $(BUILD_EXECUTABLE)

# Proxy
include $(CLEAR_VARS)
LOCAL_PATH := $(TOP_PATH)/src
LOCAL_MODULE    := rilproxy
LOCAL_SRC_FILES := main.c
LOCAL_CFLAGS += -fPIE -Wall -Werror -Wextra
LOCAL_LDFLAGS += -fPIE -pie
include $(BUILD_EXECUTABLE)
