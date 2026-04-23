#pragma once

#include <string>
#include <vector>
#include <obs.h>

class VisionProcessor {
public:
    VisionProcessor();
    ~VisionProcessor();

    // Processes an OBS frame and returns a JSON string with pose landmarks
    std::string processFrame(struct obs_source_frame *frame);

private:
    void *impl; // Pointer to Objective-C++ implementation
};
