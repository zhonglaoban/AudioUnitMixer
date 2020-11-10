//
//  ViewController.m
//  AudioUnitMixer
//
//  Created by 钟凡 on 2019/11/20.
//  Copyright © 2019 钟凡. All rights reserved.
//

#import "ViewController.h"
#import "ZFAudioUnitMixer.h"
#import "ZFAudioFileReader.h"

@interface ViewController ()<ZFAudioUnitMixerDelegate>

@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) AudioStreamBasicDescription inputFormat;
@property (nonatomic) AudioStreamBasicDescription outputFormat;
@property (nonatomic) ExtAudioFileRef audioFile;
@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic, assign) int frames;
@property (nonatomic, strong) ZFAudioUnitMixer *audioMixer;
@property (nonatomic, strong) ZFAudioFileReader *fileReader1;
@property (nonatomic, strong) ZFAudioFileReader *fileReader2;

@end


@implementation ViewController
- (IBAction)mixAction:(UIButton *)sender {
    [sender setSelected:!sender.isSelected];
    if (sender.isSelected) {
        [_audioMixer startMix];
    }else {
        [_audioMixer stopMix];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    _asbd.mSampleRate = 16000;
    _asbd.mFormatID = kAudioFormatLinearPCM;
    _asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    _asbd.mBytesPerPacket = 2;
    _asbd.mFramesPerPacket = 1;
    _asbd.mBytesPerFrame = 2;
    _asbd.mChannelsPerFrame = 1;
    _asbd.mBitsPerChannel = 16;
    
    _audioMixer = [[ZFAudioUnitMixer alloc] initWithAsbd:&_asbd];
    _audioMixer.delegate = self;
    [_audioMixer setStreamCount:2];
    
    _fileReader1 = [ZFAudioFileReader new];
    _fileReader2 = [ZFAudioFileReader new];
    
    [self setupAudioFiles:&_asbd];
}
- (void)setupAudioFiles:(AudioStreamBasicDescription *)asbd {
    NSString *source1 = [[NSBundle mainBundle] pathForResource:@"DrumsMonoSTP" ofType:@"aif"];
    NSString *source2 = [[NSBundle mainBundle] pathForResource:@"goodbye" ofType:@"mp3"];
    
    [_fileReader1 openFile:source1 format:asbd];
    [_fileReader2 openFile:source2 format:asbd];
}
- (void)audioMixer:(ZFAudioUnitMixer *)mixer data:(void *)data size:(int)size forStreamIndex:(UInt32)index {
    if (index == 0) {
        [_fileReader1 readData:data length:size];
    } else {
        [_fileReader2 readData:data length:size];
    }
}
@end
