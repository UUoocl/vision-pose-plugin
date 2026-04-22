cmake_minimum_required(VERSION 3.28...3.30)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/common/bootstrap.cmake" NO_POLICY_SCOPE)

project(${_name} VERSION ${_version})

include(compilerconfig)
include(defaults)
include(helpers)

# Cross-platform dependency discovery
find_package(libobs REQUIRED)

add_library(${PROJECT_NAME} MODULE)

# Disable warnings as errors
add_compile_options(-Wno-error)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
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
