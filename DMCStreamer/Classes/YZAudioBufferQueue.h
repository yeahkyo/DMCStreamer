//
//  YZAudioBuffer.h
//  DMCPlayerDemo
//
//  Created by Zhang Yan on 16/5/20.
//  Copyright © 2016年 TOPDMC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class YZAudioBufferQueue;

@protocol YZAudioBufferQueueDelegate <NSObject>

- (void)audioBufferQueue:(YZAudioBufferQueue *)bufferQueue bufferFilledOut:(AudioQueueBufferRef)buffer packetsNum:(UInt32)packetsNum packetDescs:(AudioStreamPacketDescription[])packetDescs;
- (void)audioBufferQueueEmpty:(YZAudioBufferQueue *)bufferQueue;

@end

@interface YZAudioBufferQueue : NSObject

- (instancetype)initWithAudioQueue:(AudioQueueRef)audioQueue bufferSize:(NSUInteger)bufferSize;
//- (instancetype)initWithAudioQueue:(AudioQueueRef)audioQueue;

- (void)addData:(const void *)data offset:(SInt64)offset size:(SInt64)size desc:(AudioStreamPacketDescription)desc;

- (void)bufferComplete:(AudioQueueBufferRef)buffer;

- (void)reset;

@property (nonatomic, assign) NSUInteger bufferSize;

@property (nonatomic, weak) id<YZAudioBufferQueueDelegate> delegate;

@end
