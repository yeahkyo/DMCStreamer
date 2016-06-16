//
//  YZAudioBuffer.m
//  DMCPlayerDemo
//
//  Created by Zhang Yan on 16/5/20.
//  Copyright © 2016年 TOPDMC. All rights reserved.
//

#import "YZAudioBufferQueue.h"

#import <AVFoundation/AVFoundation.h>
#include <pthread.h>

#define kBufferNum 3 
#define kAQMaxPacketDescs 512

@interface YZAudioBufferQueue() {
    AudioQueueBufferRef buffersArray[kBufferNum];
    BOOL inUseArray[kBufferNum];
    AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs];
    
    pthread_mutex_t mutex;
    pthread_cond_t cond;
}

@property (nonatomic, assign) NSUInteger currIndex;

@property (nonatomic, assign) NSUInteger filledSize;

@property (nonatomic, assign) NSUInteger inUseCount;

@property (nonatomic, assign) BOOL isPlaying;

@property (nonatomic, assign) UInt32 packetsNum;

@end

@implementation YZAudioBufferQueue

- (instancetype)initWithAudioQueue:(AudioQueueRef)audioQueue bufferSize:(NSUInteger)bufferSize {
    if (self = [super init]) {
        
        bufferSize = 2048;
        
        for (int i = 0; i < kBufferNum; i ++) {
            NSLog(@"Allocate Buffer");
            OSStatus status = AudioQueueAllocateBuffer(audioQueue, (unsigned int)bufferSize, &buffersArray[i]);
            inUseArray[i] = false;
        }
        
        _bufferSize = bufferSize;
        _currIndex = 0;
        _filledSize = 0;
        _inUseCount = 0;
        _isPlaying = false;
        _packetsNum = 0;
        
        pthread_mutex_init(&mutex, NULL);
        pthread_cond_init(&cond, NULL);
    }
    
    return self;
}


- (void)addData:(const void *)data offset:(SInt64)offset size:(SInt64)size desc:(AudioStreamPacketDescription)desc {
//    @synchronized(self) {
        if (size > 0 || offset > 0) {
            packetDescs[self.packetsNum] = desc;
            packetDescs[self.packetsNum].mStartOffset = self.filledSize;
            self.packetsNum ++;
        }
        
        AudioQueueBufferRef fillBuf = buffersArray[self.currIndex];
        memcpy((char*)fillBuf->mAudioData + self.filledSize, (const char*)data + offset, size);
        self.filledSize += size;
//    }
    
    if (self.filledSize + size > self.bufferSize) {
        [self fulledOut];
    }
    
    size_t packetsDescsRemaining = kAQMaxPacketDescs - self.packetsNum;
    if (packetsDescsRemaining <= 0) {
        [self fulledOut];
    }
}

- (void)fulledOut {
//    @synchronized (self) {
        if (self.filledSize <= 0) {
            return;
        }
        
        AudioQueueBufferRef buffer = buffersArray[self.currIndex];
        buffer->mAudioDataByteSize = (unsigned int)self.filledSize;
        self.inUseCount ++;
        inUseArray[self.currIndex] = true;
        
        [self.delegate audioBufferQueue:self bufferFilledOut:buffer packetsNum:self.packetsNum packetDescs:packetDescs];
    
        if (++ self.currIndex >= kBufferNum) {
            self.currIndex = 0;
        }
        self.filledSize = 0;
        self.packetsNum = 0;
        
        [self waitForNextBuffer];
//    }
}

- (void)bufferComplete:(AudioQueueBufferRef)buffer {
    for (int i = 0; i < kBufferNum; i ++) {
        if (buffersArray[i] == buffer) {
            pthread_mutex_lock(&mutex);
            inUseArray[i] = false;
            self.inUseCount --;
            if (self.inUseCount < 1) {
                [self.delegate audioBufferQueueEmpty:self];
            }
            pthread_cond_signal(&cond);
            pthread_mutex_unlock(&mutex);
            break;
        }
    }
}

- (void)reset {
//    @synchronized (self) {
        for (int i = 0; i < kBufferNum; i ++) {
            inUseArray[i] = false;
        }
        
        _currIndex = 0;
        _filledSize = 0;
        _inUseCount = 0;
        _isPlaying = false;
        _packetsNum = 0;
//    }
}

- (void)waitForNextBuffer {
    pthread_mutex_lock(&mutex);
    while(inUseArray[self.currIndex]) {
        pthread_cond_wait(&cond, &mutex);
    }
    pthread_mutex_unlock(&mutex);
}

@end
