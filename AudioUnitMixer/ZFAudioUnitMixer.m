//
//  ZFAudioUnitMixer.m
//  AudioUnitMixer
//
//  Created by 钟凡 on 2020/11/8.
//  Copyright © 2020 钟凡. All rights reserved.
//

#import "ZFAudioUnitMixer.h"
#import <AudioToolbox/AudioToolbox.h>

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else {
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
        fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    }
}
OSStatus inputCallback(void *inRefCon,
                       AudioUnitRenderActionFlags *ioActionFlags,
                       const AudioTimeStamp *inTimeStamp,
                       UInt32 inBusNumber,
                       UInt32 inNumberFrames,
                       AudioBufferList *ioData) {
    ZFAudioUnitMixer *mixer = (__bridge ZFAudioUnitMixer *)inRefCon;
    AudioBuffer buffer = ioData->mBuffers[0];
    [mixer.delegate audioMixer:mixer data:buffer.mData size:buffer.mDataByteSize forStreamIndex:inBusNumber];

    return noErr;
}

@interface ZFAudioUnitMixer()

@property (nonatomic, assign) AudioUnit ioUnit;
@property (nonatomic, assign) AudioUnit mixerUnit;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) AudioStreamBasicDescription *asbd;

@end


@implementation ZFAudioUnitMixer

- (instancetype)initWithAsbd:(AudioStreamBasicDescription *)asbd
{
    self = [super init];
    if (self) {
        _asbd = asbd;
        _queue = dispatch_queue_create("zf.audioMixer", DISPATCH_QUEUE_SERIAL);
        [self createUnits];
        [self setupUnits];
    }
    return self;
}
- (void)createUnits {
    AudioComponentDescription ioUnitDesc = {};
    ioUnitDesc.componentType = kAudioUnitType_Output;
    ioUnitDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    ioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioUnitDesc.componentFlags = 0;
    ioUnitDesc.componentFlagsMask = 0;
    AudioComponent outputComp = AudioComponentFindNext(NULL, &ioUnitDesc);
    if (outputComp == NULL) {
        printf("can't get AudioComponent");
    }
    OSStatus status = AudioComponentInstanceNew(outputComp, &_ioUnit);
    CheckError(status, "creat output unit");
    
    AudioComponentDescription mixerDesc = {};
    mixerDesc.componentType = kAudioUnitType_Mixer;
    mixerDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerDesc.componentFlags = 0;
    mixerDesc.componentFlagsMask = 0;
    AudioComponent mixerComp = AudioComponentFindNext(NULL, &mixerDesc);
    if (mixerComp == NULL) {
        printf("can't get AudioComponent");
    }
    status = AudioComponentInstanceNew(mixerComp, &_mixerUnit);
    CheckError(status, "creat mixer unit");
}
-(void)setupUnits {
    OSStatus status;
    UInt32 propertySize = sizeof(AudioStreamBasicDescription);
    //设置mixer输出格式
    status = AudioUnitSetProperty(_mixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  _asbd,
                                  propertySize);
    CheckError(status, "set stream format");

    //make connection
    AudioUnitElement inputBus  = 0;
    AudioUnitElement outputBus = 0;
    AudioUnitConnection mixerOutToIoUnitIn;
    mixerOutToIoUnitIn.sourceAudioUnit    = _mixerUnit;
    mixerOutToIoUnitIn.sourceOutputNumber = outputBus;
    mixerOutToIoUnitIn.destInputNumber    = inputBus;

    status = AudioUnitSetProperty(_ioUnit,                         // connection destination
                                  kAudioUnitProperty_MakeConnection,   // property key
                                  kAudioUnitScope_Input,              // destination scope
                                  outputBus,                            // destination element
                                  &mixerOutToIoUnitIn,                 // connection definition
                                  sizeof(mixerOutToIoUnitIn));
    CheckError(status, "make connection");
}
- (void)setStreamCount:(UInt32)count {
    OSStatus status;
    UInt32 propertySize = sizeof(AudioStreamBasicDescription);
    status = AudioUnitSetProperty(_mixerUnit,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  0,
                                  &count,
                                  sizeof(UInt32));
    CheckError(status, "set stream format");
    for (UInt32 i = 0; i < count; i++) {
        // Set the callback method
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = inputCallback;
        callbackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);
        status = AudioUnitSetProperty(_mixerUnit,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Input,
                                      i,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        CheckError(status, "set callback");
        status = AudioUnitSetProperty(_mixerUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      i,
                                      _asbd,
                                      propertySize);
        CheckError(status, "set stream format");
    }
}
- (void)startMix {
    dispatch_async(_queue, ^{
        OSStatus status;
        status = AudioUnitInitialize(self.mixerUnit);
        CheckError(status, "initialize mixer unit");
        status = AudioUnitInitialize(self.ioUnit);
        CheckError(status, "initialize output unit");
        status = AudioOutputUnitStart(self.ioUnit);
        CheckError(status, "start output unit");
    });
}
- (void)stopMix {
    dispatch_async(_queue, ^{
        OSStatus status;
        status = AudioOutputUnitStop(self.ioUnit);
        CheckError(status, "stop output unit");
        status = AudioUnitUninitialize(self.ioUnit);
        CheckError(status, "uninitialize output unit");
        status = AudioUnitUninitialize(self.mixerUnit);
        CheckError(status, "uninitialize mixer unit");
    });
}
@end
