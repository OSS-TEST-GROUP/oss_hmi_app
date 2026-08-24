# Project-level configuration.
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "hmi_launcher")
# The unique GTK application identifier for this application. See:
# https://wiki.gnome.org/HowDoI/ChooseApplicationID
set(APPLICATION_ID "com.obigo.hmi_launcher")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(SET CMP0063 NEW)

# Load bundled libraries from the lib/ directory relative to the binary.
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Root filesystem for cross-building.
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# Define build configuration options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

set(OBIGO_OASIS_CANDIDATE_DIRS
  "${CMAKE_SOURCE_DIR}/../third_party/obigo-oasis"
  "${CMAKE_SOURCE_DIR}/../../oss_launcher_bot/third_party/obigo-oasis"
)
set(OBIGO_OASIS_DIR "")
foreach(candidate ${OBIGO_OASIS_CANDIDATE_DIRS})
  if(EXISTS "${candidate}/include" AND EXISTS "${candidate}/lib")
    set(OBIGO_OASIS_DIR "${candidate}")
    break()
  endif()
endforeach()

# F015: chatbot_bridge (내장 LLM FFI) 는 F015 에서 Dart 측 FFI 가 제거됐다.
# Dart 코드(gemma_chatbot_service.dart)에서 dart:ffi / chatbot_bridge 의존이 삭제됐으므로
# chatbot_bridge.so 는 빌드되더라도 로드·호출되지 않는다.
# SDK 가 없으면 아래 if() 블록 전체가 건너뛰어져 chatbot_bridge 가 빌드 대상에서 제외된다.
# 새 AI 백엔드: Agent.Submit gRPC (agent_submit_ai_service.dart, ADR-014 결정 2).
set(CHATBOT_BRIDGE_ENABLED FALSE)
if(NOT "${OBIGO_OASIS_DIR}" STREQUAL "")
  set(OBIGO_OASIS_INCLUDE_DIR "${OBIGO_OASIS_DIR}/include")
  set(OBIGO_OASIS_LIB_DIR "${OBIGO_OASIS_DIR}/lib")
  set(OBIGO_SERVICE_LLM_LIB "${OBIGO_OASIS_LIB_DIR}/libservice_llm.so")
  set(OBIGO_ENGINE_SLLM_LIB "${OBIGO_OASIS_LIB_DIR}/libengine_sllm.so")

  if(EXISTS "${OBIGO_OASIS_INCLUDE_DIR}/llm_provider.hpp" AND
     EXISTS "${OBIGO_OASIS_INCLUDE_DIR}/llm_provider_llamacpp.hpp" AND
     EXISTS "${OBIGO_OASIS_INCLUDE_DIR}/multimodal_types.hpp" AND
     EXISTS "${OBIGO_SERVICE_LLM_LIB}" AND
     EXISTS "${OBIGO_ENGINE_SLLM_LIB}")
    add_library(chatbot_bridge SHARED
      "${CMAKE_SOURCE_DIR}/../native/chatbot_bridge.cpp"
    )

    APPLY_STANDARD_SETTINGS(chatbot_bridge)
    target_compile_features(chatbot_bridge PRIVATE cxx_std_17)

    target_include_directories(chatbot_bridge SYSTEM PRIVATE
      "${OBIGO_OASIS_INCLUDE_DIR}"
    )

    target_compile_options(chatbot_bridge PRIVATE
      -Wno-error=unused-variable
    )

    target_link_options(chatbot_bridge PRIVATE
      "LINKER:--no-as-needed"
    )

    target_link_libraries(chatbot_bridge PRIVATE
      "${OBIGO_ENGINE_SLLM_LIB}"
      "${OBIGO_SERVICE_LLM_LIB}"
    )

    set_target_properties(chatbot_bridge
      PROPERTIES
      BUILD_RPATH "$ORIGIN"
      INSTALL_RPATH "$ORIGIN"
    )

    set(CHATBOT_BRIDGE_ENABLED TRUE)
  endif()
endif()

if(NOT CHATBOT_BRIDGE_ENABLED)
  message(WARNING
    "chatbot_bridge is disabled. Add Obigo Oasis headers and libraries under "
    "apps/hmi_launcher/third_party/obigo-oasis or keep apps/oss_launcher_bot/"
    "third_party/obigo-oasis available to enable Gemma.")
endif()

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the install-generated bundle's copy of the executable will launch
# correctly, since the resources must in the right relative locations. To avoid
# people trying to run the unbundled copy, put it in a subdirectory instead of
# the default top-level location.
set_target_properties(${BINARY_NAME}
  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# By default, "installing" just makes a relocatable bundle in the build
# directory.
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# Start with a clean build bundle directory every time.
install(CODE "
  file(REMOVE_RECURSE \"${BUILD_BUNDLE_DIR}/\")
  " COMPONENT Runtime)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

if(CHATBOT_BRIDGE_ENABLED)
  install(TARGETS chatbot_bridge
    LIBRARY DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
  install(DIRECTORY "${OBIGO_OASIS_LIB_DIR}/"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime
    FILES_MATCHING PATTERN "*.so*")
  install(CODE "
    if(EXISTS \"${INSTALL_BUNDLE_LIB_DIR}/libonnxruntime.so\")
      execute_process(
        COMMAND \"${CMAKE_COMMAND}\" -E create_symlink
          libonnxruntime.so
          \"${INSTALL_BUNDLE_LIB_DIR}/libonnxruntime.so.1\"
      )
    endif()
    " COMPONENT Runtime)
endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/../models")
  install(DIRECTORY "${CMAKE_SOURCE_DIR}/../models"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    COMPONENT Runtime)
elseif(EXISTS "${CMAKE_SOURCE_DIR}/../../oss_launcher_bot/models")
  install(DIRECTORY "${CMAKE_SOURCE_DIR}/../../oss_launcher_bot/models"
    DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
# OPTIONAL: install_code_assets 타겟이 캐시로 건너뛰어진 경우 디렉토리가 없을 수 있음 (Flutter known bug)
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime
   OPTIONAL)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()
