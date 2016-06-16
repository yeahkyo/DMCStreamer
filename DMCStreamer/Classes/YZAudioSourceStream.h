//
//  YZAudioSourceStream.h
//  DMCPlayerDemo
//
//  Created by Zhang Yan on 16/6/2.
//  Copyright © 2016年 TOPDMC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolBox/AudioToolbox.h>

@protocol YZAudioSourceDelegate <NSObject>

- (void)audioSource:(id)audioSource streamDescriptionChanged:(AudioStreamBasicDescription)streamDescription;

- (void)audioSource:(id)audioSource dataDecoded:(const char*)data size:(SInt64)packetSize offset:(SInt64)packetOffset desc:(AudioStreamPacketDescription)packetDescription;

- (void)audioSourceDataCompleted:(id)audioSource;

@end

@interface YZAudioSourceStream : NSObject

- (void)start;

- (void)stop;

- (BOOL)isCompleted;

@property (nonatomic, assign) AudioStreamBasicDescription streamDescription;

@property (nonatomic, weak) id<YZAudioSourceDelegate> delegate;

@property (nonatomic, strong) NSURL *url;

@property (nonatomic, readonly) NSTimeInterval duration;

@end
