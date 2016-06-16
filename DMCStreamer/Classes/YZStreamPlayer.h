//
//  YZStreamPlayer.h
//  DMCPlayback
//
//  Created by Zhang Yan on 16/5/18.
//  Copyright © 2016年 TopDMC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef NS_ENUM(NSUInteger, YZPlayerState) {
    YZPlayerStateIDLE,
    YZPlayerStatePlaying,
    YZPlayerStatePaused,
    YZPlayerStateBuffering
};

@class YZStreamPlayer;

@protocol YZStreamPlayerDelegate <NSObject>

- (void)streamPlayer:(YZStreamPlayer *)player stateChangedFrom:(YZPlayerState)oldState to:(YZPlayerState)newState;

@end

@interface YZStreamPlayer : NSObject

+ (instancetype)sharedPlayer;
    
- (void)playWithURLString:(NSString *)urlString;

- (void)play;

- (void)pause;

- (void)stop;

- (BOOL)isPlaying;

@property (nonatomic, readonly) NSTimeInterval currentTime;

@property (nonatomic, readonly) NSTimeInterval duration;

@property (nonatomic, readonly) YZPlayerState state;

@property (nonatomic, weak) id<YZStreamPlayerDelegate> delegate;

@end
