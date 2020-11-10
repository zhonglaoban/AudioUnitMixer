//
//  ZFAudioUnitMixer.h
//  AudioUnitMixer
//
//  Created by 钟凡 on 2020/11/8.
//  Copyright © 2020 钟凡. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZFAudioUnitMixer;

@protocol ZFAudioUnitMixerDelegate <NSObject>

- (void)audioMixer:(ZFAudioUnitMixer *)mixer data:(void *)data size:(int)size forStreamIndex:(UInt32)index;

@end

@interface ZFAudioUnitMixer : NSObject

@property (nonatomic, weak) id<ZFAudioUnitMixerDelegate> delegate;

- (instancetype)initWithAsbd:(AudioStreamBasicDescription *)asbd;
- (void)setStreamCount:(UInt32)count;
- (void)startMix;
- (void)stopMix;

@end

NS_ASSUME_NONNULL_END
