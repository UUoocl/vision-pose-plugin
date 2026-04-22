cmake_minimum_required(VERSION 3.16...3.26)

set(CMAKE_PREFIX_PATH 
    "${CMAKE_CURRENT_SOURCE_DIR}/.deps/obs-deps-2025-08-23-universal"
    "${CMAKE_CURRENT_SOURCE_DIR}/.deps/Frameworks/libobs.framework/Resources/cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/.deps"
    ${CMAKE_PREFIX_PATH}
)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/common/bootstrap.cmake" NO_POLICY_SCOPE)

project(${_name} VERSION ${_version})

# Cross-platform dependency discovery
find_package(libobs REQUIRED)

include(compilerconfig)
include(defaults)
include(helpers)

add_library(${PROJECT_NAME} MODULE)

# Disable warnings as errors
add_compile_options(-Wno-error)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    "${CMAKE_CURRENT_SOURCE_DIR}/.deps/obs-deps-2025-08-23-universal/include"
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    OBS::libobs
)

if(APPLE)
    target_link_libraries(${PROJECT_NAME} PRIVATE 
        "-framework Accelerate"
        "-framework Vision"
        "-framework AVFoundation"
        "-framework CoreVideo"
        "-framework CoreMedia"
        "-framework CoreImage"
        "-framework CoreGraphics"
        "-framework Foundation"
    )
    
    set_source_files_properties(VisionProcessor.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES
    PREFIX ""
)

target_sources(${PROJECT_NAME} PRIVATE
    vision-pose-plugin.cpp
    VisionProcessor.h
    VisionProcessor.mm
)

set_target_properties_plugin(${PROJECT_NAME} PROPERTIES OUTPUT_NAME ${_name})
