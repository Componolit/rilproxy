TOP_PATH := $(call my-dir)/..

# Test
include $(CLEAR_VARS)
LOCAL_PATH := $(TOP_PATH)/src
LOCAL_MODULE    := test_rilproxy
LOCAL_SRC_FILES := tests.c
LOCAL_CFLAGS += -fPIE -Wall -Werror -Wextra
LOCAL_LDFLAGS += -fPIE -pie
include $(BUILD_EXECUTABLE)

# Proxy server
include $(CLEAR_VARS)
LOCAL_PATH := $(TOP_PATH)/src
LOCAL_MODULE    := rilproxy_server
LOCAL_SRC_FILES := server.c
LOCAL_CFLAGS += -fPIE -Wall -Werror -Wextra
LOCAL_LDFLAGS += -fPIE -pie
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_PATH := $(TOP_PATH)/src
LOCAL_MODULE    := rilproxy_client
LOCAL_SRC_FILES := client.c
LOCAL_CFLAGS += -fPIE -Wall -Werror -Wextra
LOCAL_LDFLAGS += -fPIE -pie
include $(BUILD_EXECUTABLE)
