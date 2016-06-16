//
//  YZAudioQueue.h
//  DMCPlayerDemo
//
//  Created by Zhang Yan on 16/6/2.
//  Copyright © 2016年 TOPDMC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AudioToolBox/AudioToolbox.h>

@class YZAudioQueue;

@protocol YZAudioQueueDelegate <NSObject>

- (void)audioQueue:(YZAudioQueue *)audioQueue bufferCompleted:(AudioQueueBufferRef)buffer;

@end

@interface YZAudioQueue : NSObject

- (void)newOutputQueueWithStreamDescription:(AudioStreamBasicDescription)streamDescription;

- (void)enqueueBuffer:(AudioQueueBufferRef)buffer withPacketsNumber:(UInt32)packetsNum packetDescriptions:(AudioStreamPacketDescription[])packetDescs;

- (void)play;

- (void)pause;

- (void)stop;
- (void)stop:(BOOL)immediate;

@property (nonatomic, assign) AudioQueueRef audioQueueRef;

@property (nonatomic, weak) id<YZAudioQueueDelegate> delegate;

@property (nonatomic, assign) AudioStreamBasicDescription streamDescription;

@end
