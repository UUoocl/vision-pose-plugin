#include <obs-module.h>
#include <obs.h>
#include <vector>
#include <atomic>
#include <string>
#include <mutex>
#include <util/platform.h>
#include "VisionProcessor.h"

OBS_DECLARE_MODULE()
OBS_MODULE_AUTHOR("Antigravity")
OBS_MODULE_USE_DEFAULT_LOCALE("vision-pose-plugin", "en-US")

struct VisionFilterState {
    std::string topic = "pose_landmarks";
    std::atomic<uint64_t> lastFrameTime{0};
    std::atomic<int> fps{15};
    VisionProcessor *processor;
    obs_source_t *context;
};

static void vision_pose_update(void *data, obs_data_t *settings) {
    VisionFilterState *state = (VisionFilterState *)data;
    state->topic = obs_data_get_string(settings, "topic");
    state->fps.store((int)obs_data_get_int(settings, "fps"), std::memory_order_relaxed);
    
    blog(LOG_INFO, "[Vision Pose] Filter updated: topic=%s, fps=%d", 
        state->topic.c_str(), state->fps.load());
}

static void *vision_pose_create(obs_data_t *settings, obs_source_t *source) {
    blog(LOG_INFO, "[Vision Pose] Filter instance created");
    VisionFilterState *state = new VisionFilterState();
    state->context = source;
    state->processor = new VisionProcessor();
    vision_pose_update(state, settings);
    return state;
}

static void vision_pose_destroy(void *data) {
    blog(LOG_INFO, "[Vision Pose] Filter instance destroyed");
    VisionFilterState *state = (VisionFilterState *)data;
    delete state->processor;
    delete state;
}

static struct obs_source_frame *vision_pose_video(void *data, struct obs_source_frame *frame) {
    VisionFilterState *state = (VisionFilterState *)data;
    if (!frame) return frame;

    uint64_t now = os_gettime_ns();
    int current_fps = state->fps.load(std::memory_order_relaxed);
    if (current_fps <= 0) current_fps = 15;
    uint64_t interval = 1000000000ULL / current_fps;
    uint64_t last = state->lastFrameTime.load(std::memory_order_relaxed);
    
    if (now - last < interval) return frame;
    state->lastFrameTime.store(now, std::memory_order_relaxed);

    // Process frame with Vision
    std::string landmarks_json = state->processor->processFrame(frame);

    if (!landmarks_json.empty()) {
        obs_data_t *packet = obs_data_create();
        obs_data_set_string(packet, "t", "pose");
        obs_data_set_string(packet, "v", landmarks_json.c_str());
        obs_data_set_string(packet, "a", state->topic.c_str());
        
        calldata_t cd;
        calldata_init(&cd);
        calldata_set_ptr(&cd, "packet", packet);
        
        signal_handler_t *sh = obs_get_signal_handler();
        if (sh) {
            signal_handler_signal(sh, "media_warp_transmit", &cd);
        }
        
        calldata_free(&cd);
        obs_data_release(packet);
    }

    return frame;
}

static const char *vision_pose_get_name(void *unused) {
    (void)unused;
    return "Vision Pose Detection";
}

static obs_properties_t *vision_pose_properties(void *data) {
    (void)data;
    obs_properties_t *props = obs_properties_create();
    obs_properties_add_text(props, "topic", "WebSocket Topic", OBS_TEXT_DEFAULT);
    obs_properties_add_int(props, "fps", "Target FPS", 1, 60, 1);
    return props;
}

static void vision_pose_defaults(obs_data_t *settings) {
    obs_data_set_default_string(settings, "topic", "pose_landmarks");
    obs_data_set_default_int(settings, "fps", 15);
}

bool obs_module_load(void) {
    obs_source_info vision_pose_info = {};
    vision_pose_info.id = "vision_pose_filter";
    vision_pose_info.type = OBS_SOURCE_TYPE_FILTER;
    vision_pose_info.output_flags = OBS_SOURCE_VIDEO;
    vision_pose_info.get_name = vision_pose_get_name;
    vision_pose_info.create = vision_pose_create;
    vision_pose_info.destroy = vision_pose_destroy;
    vision_pose_info.update = vision_pose_update;
    vision_pose_info.get_properties = vision_pose_properties;
    vision_pose_info.get_defaults = vision_pose_defaults;
    vision_pose_info.filter_video = vision_pose_video;

    obs_register_source(&vision_pose_info);
    
    blog(LOG_INFO, "[Vision Pose] Plugin loaded");
    return true;
}

void obs_module_unload(void) {}
