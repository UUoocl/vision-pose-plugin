#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#include "VisionProcessor.h"
#include <util/platform.h>
#include <algorithm>

@interface VisionProcessorImpl : NSObject
@property (nonatomic, strong) VNDetectHumanBodyPoseRequest *poseRequest;
- (NSString *)processFrame:(struct obs_source_frame *)frame;
@end

@implementation VisionProcessorImpl

- (instancetype)init {
    self = [super init];
    if (self) {
        _poseRequest = [[VNDetectHumanBodyPoseRequest alloc] init];
    }
    return self;
}

- (NSString *)processFrame:(struct obs_source_frame *)frame {
    if (!frame) return nil;

    CVPixelBufferRef pixelBuffer = NULL;
    OSType pixelFormat;
    
    // Map OBS format to CoreVideo format
    switch (frame->format) {
        case VIDEO_FORMAT_BGRA:
        case VIDEO_FORMAT_BGRX:
            pixelFormat = kCVPixelFormatType_32BGRA;
            break;
        case VIDEO_FORMAT_NV12:
            pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
            break;
        case VIDEO_FORMAT_I420:
            pixelFormat = kCVPixelFormatType_420YpCbCr8Planar;
            break;
        case VIDEO_FORMAT_UYVY:
            pixelFormat = kCVPixelFormatType_422YpCbCr8;
            break;
        default:
            return nil;
    }

    CVReturn status;
    if (frame->format == VIDEO_FORMAT_NV12 || frame->format == VIDEO_FORMAT_I420) {
        // Multi-planar
        void *planeBaseAddresses[3] = { (void*)frame->data[0], (void*)frame->data[1], (void*)frame->data[2] };
        size_t planeWidths[3] = { frame->width, frame->width/2, frame->width/2 };
        size_t planeHeights[3] = { frame->height, frame->height/2, frame->height/2 };
        size_t planeBytesPerRow[3] = { frame->linesize[0], frame->linesize[1], frame->linesize[2] };
        
        int numPlanes = (frame->format == VIDEO_FORMAT_NV12) ? 2 : 3;
        
        status = CVPixelBufferCreateWithPlanarBytes(kCFAllocatorDefault,
                                                   frame->width, frame->height,
                                                   pixelFormat,
                                                   NULL, 0,
                                                   numPlanes,
                                                   planeBaseAddresses,
                                                   planeWidths,
                                                   planeHeights,
                                                   planeBytesPerRow,
                                                   NULL, NULL, NULL,
                                                   &pixelBuffer);
    } else {
        // Single plane
        status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                             frame->width, frame->height,
                                             pixelFormat,
                                             (void*)frame->data[0],
                                             frame->linesize[0],
                                             NULL, NULL, NULL,
                                             &pixelBuffer);
    }

    if (status != kCVReturnSuccess || !pixelBuffer) {
        return nil;
    }

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
    NSError *error = nil;
    [handler performRequests:@[self.poseRequest] error:&error];
    
    CVPixelBufferRelease(pixelBuffer);

    if (error) {
        return nil;
    }

    NSMutableArray *results = [NSMutableArray array];
    for (VNHumanBodyPoseObservation *observation in self.poseRequest.results) {
        NSMutableDictionary *poseData = [NSMutableDictionary dictionary];
        
        // Get all available joint names
        NSArray<VNHumanBodyPoseObservationJointName> *availableJoints = [observation availableJointNames];
        NSMutableDictionary *landmarks = [NSMutableDictionary dictionary];
        
        NSDictionary *jointMap = @{
            VNHumanBodyPoseObservationJointNameNose: @"nose",
            VNHumanBodyPoseObservationJointNameLeftEye: @"left_eye",
            VNHumanBodyPoseObservationJointNameRightEye: @"right_eye",
            VNHumanBodyPoseObservationJointNameLeftEar: @"left_ear",
            VNHumanBodyPoseObservationJointNameRightEar: @"right_ear",
            VNHumanBodyPoseObservationJointNameLeftShoulder: @"left_shoulder",
            VNHumanBodyPoseObservationJointNameRightShoulder: @"right_shoulder",
            VNHumanBodyPoseObservationJointNameLeftElbow: @"left_elbow",
            VNHumanBodyPoseObservationJointNameRightElbow: @"right_elbow",
            VNHumanBodyPoseObservationJointNameLeftWrist: @"left_wrist",
            VNHumanBodyPoseObservationJointNameRightWrist: @"right_wrist",
            VNHumanBodyPoseObservationJointNameLeftHip: @"left_hip",
            VNHumanBodyPoseObservationJointNameRightHip: @"right_hip",
            VNHumanBodyPoseObservationJointNameLeftKnee: @"left_knee",
            VNHumanBodyPoseObservationJointNameRightKnee: @"right_knee",
            VNHumanBodyPoseObservationJointNameLeftAnkle: @"left_ankle",
            VNHumanBodyPoseObservationJointNameRightAnkle: @"right_ankle",
            VNHumanBodyPoseObservationJointNameNeck: @"neck"
        };
        
        for (VNHumanBodyPoseObservationJointName jointName in availableJoints) {
            VNRecognizedPoint *point = [observation recognizedPointForJointName:jointName error:&error];
            if (point && point.confidence > 0.3) {
                NSString *mappedName = jointMap[jointName] ?: jointName;
                landmarks[mappedName] = @{
                    @"x": @(point.location.x),
                    @"y": @(1.0 - point.location.y),
                    @"c": @(point.confidence)
                };
            }
        }
        
        poseData[@"landmarks"] = landmarks;
        [results addObject:poseData];
    }

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:results options:0 error:&jsonError];
    if (!jsonData) return nil;

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end

VisionProcessor::VisionProcessor() {
    impl = (__bridge_retained void *)[[VisionProcessorImpl alloc] init];
}

VisionProcessor::~VisionProcessor() {
    VisionProcessorImpl *processor = (__bridge_transfer VisionProcessorImpl *)impl;
    processor = nil;
}

std::string VisionProcessor::processFrame(struct obs_source_frame *frame) {
    @autoreleasepool {
        VisionProcessorImpl *processor = (__bridge VisionProcessorImpl *)impl;
        NSString *result = [processor processFrame:frame];
        return result ? [result UTF8String] : "";
    }
}
