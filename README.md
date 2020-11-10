# 如何使用Audio Unit 混合音频
在之前的AudioUnit和ExtAudioFile两篇文章基础之上，我们来做一些更有意思也更有挑战性的工作，那就是从文件中读取两个音频，将它们混合之后播放出来。

本篇文章分为以下2个部分：
1. 使用`ExtAudioFile`读取文件。
2. `AudioMixerUnit`的具体使用。

## 使用`ExtAudioFile`读取文件
`ExtAudioFile`可以按照我们设置的数据格式读取文件，很方便，具体参照这篇文章。
[ExtAudioFile如何使用](https://www.jianshu.com/p/03491bf9bd0b)

## `AudioMixerUnit `的具体使用
我们这里使用两个`AudioUnit`来实现混音和播放的功能，`AudioMixerUnit `用来混合数据，`AudioOutputUnit`用来播放数据。画了一个草图，如下：
![结构图.png](https://upload-images.jianshu.io/upload_images/3277096-63d62df2e138b709.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 创建`AudioUnit`
先设置描述，然后通过`AudioComponentFindNext`和`AudioComponentInstanceNew`来获取一个`AudioUnit`实例，也可以通过`AudioGraph`来实现。
```objc
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
```

### 设置`AudioUnit`属性
设置`AudioMixerUnit`输出格式，并将`AudioMixerUnit`的输出和`AudioOutputUnit`的输入连接起来。这里的`Bus`或者`Element`可以看作是箭头的下标，`AudioMixerUnit`的输出和`AudioOutputUnit`的输入只有一根线，所以是0。

```objc
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
```

### 设置`AudioUnit`输入源回调
这里设置`AudioMixerUnit`有几个输入源，输入格式，获取数据的回调。
```objc
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
```

### 控制`AudioOutputUnit`
同播放与录制时一样，开始时先调用`Initialize`再`Start`，结束时先`Stop`再`Uninitialize`。

```objc
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
```

### 填充数据
这里设置了一个代理，回调触发的时候去取数据，我的demo中是从文件中读取数据。

```objc
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
```

[Github地址](https://github.com/zhonglaoban/AudioUnitMixer)
