//
//  YZStreamPlayer.m
//  DMCPlayback
//
//  Created by Zhang Yan on 16/5/18.
//  Copyright © 2016年 TopDMC. All rights reserved.
//

#import "YZStreamPlayer.h"

#import "YZAudioBufferQueue.h"
#import "YZAudioSourceStream.h"
#import "YZAudioQueue.h"

#import <AVFoundation/AVFoundation.h>
#include <pthread.h>

#define kAQDefaultBufSize 512

@interface YZStreamPlayer() <YZAudioBufferQueueDelegate, YZAudioQueueDelegate, YZAudioSourceDelegate>

//@property (nonatomic, strong) NSFileHandle *fileHandle;

@property (nonatomic, strong) YZAudioBufferQueue *bufferQueue;

@property (nonatomic, strong) YZAudioQueue *audioQueue;

@property (nonatomic, strong) YZAudioSourceStream *audioSource;

@property (nonatomic, assign) YZPlayerState state;

@end

@implementation YZStreamPlayer

+ (instancetype)sharedPlayer {
    static YZStreamPlayer *instance = nil;
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _state = YZPlayerStateIDLE;
    }
    
    return self;
}

#pragma mark - public interface
- (void)playWithURLString:(NSString *)urlString {
    [self stop];
    
    self.audioSource.url = [NSURL URLWithString:urlString];
    [self.audioSource start];
    
    _state = YZPlayerStatePlaying;
}

- (void)play {
    _state = YZPlayerStatePlaying;
    [self.audioQueue play];
}

- (void)pause {
    _state = YZPlayerStatePaused;
    [self.audioQueue pause];
}

- (void)stop {
    _state = YZPlayerStateIDLE;
    [self.audioSource stop];
//    if (_bufferQueue) {
//        [self.bufferQueue reset];
//    }
    self.bufferQueue = nil;
    [self.audioQueue stop];
}

- (void)finshed {
    if (self.state != YZPlayerStateIDLE) {
        [self.audioQueue stop:NO];
        [self.delegate streamPlayer:self stateChangedFrom:self.state to:YZPlayerStateIDLE];
        self.state = YZPlayerStateIDLE;
    }
}

- (NSTimeInterval)currentTime {
    AudioTimeStamp timeStamp;
    OSStatus status = AudioQueueGetCurrentTime(self.audioQueue.audioQueueRef, NULL, &timeStamp, NULL);
    UInt32 state = NO, size;
    status = AudioQueueGetProperty(self.audioQueue.audioQueueRef, kAudioQueueProperty_IsRunning, &state, &size);
    
    if (state) {
        status = AudioQueueStop(self.audioQueue.audioQueueRef, false);
    }
    return timeStamp.mSampleTime / self.audioSource.streamDescription.mSampleRate;
}

- (NSTimeInterval)duration {
    return self.audioSource.duration;
}

#pragma mark - helper methods
- (BOOL)isPlaying {
    return self.state == YZPlayerStatePlaying;
}

#pragma mark - YZAudioBufferQueueDelegate
- (void)audioBufferQueue:(YZAudioBufferQueue *)bufferQueue bufferFilledOut:(AudioQueueBufferRef)buffer packetsNum:(UInt32)packetsNum packetDescs:(AudioStreamPacketDescription[])packetDescs {
    if ([self isPlaying]) {
        [self.audioQueue enqueueBuffer:buffer withPacketsNumber:packetsNum packetDescriptions:packetDescs];
    }
}

- (void)audioBufferQueueEmpty:(YZAudioBufferQueue *)bufferQueue {
//    [self.audioSource resume];
    if ([self.audioSource isCompleted]) {
        [self finshed];
    }
}

#pragma mark - YZAudioQueueDelegate
- (void)audioQueue:(YZAudioQueue *)audioQueue bufferCompleted:(AudioQueueBufferRef)buffer {
    if ([self isPlaying]) {
        [self.bufferQueue bufferComplete:buffer];
    }
}

#pragma mark - YZAudioSourceDelegate
- (void)audioSource:(id)audioSource dataDecoded:(const char *)data size:(SInt64)packetSize offset:(SInt64)packetOffset desc:(AudioStreamPacketDescription)packetDescription {
    if (!self.audioQueue.audioQueueRef) {
        [self.audioQueue newOutputQueueWithStreamDescription:self.audioSource.streamDescription];
    }
    
    [self.bufferQueue addData:data offset:packetOffset size:packetSize desc:packetDescription];
}


- (void)audioSource:(id)audioSource streamDescriptionChanged:(AudioStreamBasicDescription)streamDescription {
}

- (void)audioSourceDataCompleted:(id)audioSource {
    
}

#pragma mark - lazy load
- (YZAudioBufferQueue *)bufferQueue {
    if (!_bufferQueue) {
        _bufferQueue = [[YZAudioBufferQueue alloc] initWithAudioQueue:self.audioQueue.audioQueueRef  bufferSize:kAQDefaultBufSize];
        _bufferQueue.delegate = self;
    }
    
    return _bufferQueue;
}

- (YZAudioSourceStream *)audioSource {
    if (!_audioSource) {
        _audioSource = [[YZAudioSourceStream alloc] init];
        _audioSource.delegate = self;
    }
    
    return _audioSource;
}

- (YZAudioQueue *)audioQueue {
    if (!_audioQueue) {
        _audioQueue = [[YZAudioQueue alloc] init];
        _audioQueue.delegate = self;       
    }
    
    return _audioQueue;
}

@end
