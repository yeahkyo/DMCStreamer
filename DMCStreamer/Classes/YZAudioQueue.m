//
//  YZAudioQueue.m
//  DMCPlayerDemo
//
//  Created by Zhang Yan on 16/6/2.
//  Copyright © 2016年 TOPDMC. All rights reserved.
//

#import "YZAudioQueue.h"

#import <AVFoundation/AVFoundation.h>

@interface YZAudioQueue()

@property (nonatomic, assign) BOOL isPlaying;

@end

@implementation YZAudioQueue

- (instancetype)init {
    if (self = [super init]) {
    }
    
    return self;
}

- (void)newOutputQueueWithStreamDescription:(AudioStreamBasicDescription)streamDescription {
    _streamDescription = streamDescription;
    
        OSStatus status;
    
    NSLog(@"New Output");
    status = AudioQueueNewOutput(&_streamDescription, AudioQueueOutputProc, (__bridge void *)self,  NULL, NULL, 0, &_audioQueueRef);
    self.isPlaying = YES;
   
//    UInt32 sizeOfUInt32 = sizeof(UInt32);
//    status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &packetBufferSize);
//    if (status || packetBufferSize == 0)
//    {
//        status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &packetBufferSize);
//        if (status || packetBufferSize == 0)
//        {
//            packetBufferSize = kAQDefaultBufSize;
//        }
//    } 
}

- (void)enqueueBuffer:(AudioQueueBufferRef)buffer withPacketsNumber:(UInt32)packetsNum packetDescriptions:(AudioStreamPacketDescription[])packetDescs {
    @synchronized (self) {
        if (!self.isPlaying) {
            return;
        }
        
        NSError *audioSessionError;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&audioSessionError];
        
        OSStatus status;
        
        if (packetsNum > 0) {
            status = AudioQueueEnqueueBuffer(self.audioQueueRef, buffer, packetsNum, packetDescs);
            if (status != noErr) {
                NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
                NSLog(@"Enqueue Buffer failed: %@",  [error localizedDescription]);
            }
        } else {
            UInt32 state, size;
            status = AudioQueueGetProperty(self.audioQueueRef, kAudioQueueProperty_IsRunning, &state, &size);
            
            if (state) {
                status = AudioQueueStop(self.audioQueueRef, false);
            }
        }
        
        status = AudioQueueStart(self.audioQueueRef, NULL);
        if (status != noErr) {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            NSLog(@"Start Audio Queue Failed: %@",  [error localizedDescription]);
        }
    }
}

- (void)play {
    @synchronized (self) {
        self.isPlaying = YES;
        AudioQueueStart(self.audioQueueRef, NULL);
    }
}

- (void)pause {
    AudioQueuePause(self.audioQueueRef);
}

- (void)stop {
    [self stop:YES];
}

- (void)stop:(BOOL)immediate {
    @synchronized (self) {
        self.isPlaying = NO;
        AudioQueueStop(self.audioQueueRef, immediate);
        self.audioQueueRef = nil;
    } 
}

static void AudioQueueOutputProc(void * inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    YZAudioQueue *audioQueue = (__bridge YZAudioQueue *)inUserData;
    [audioQueue.delegate audioQueue:audioQueue bufferCompleted:inBuffer];
}

@end
