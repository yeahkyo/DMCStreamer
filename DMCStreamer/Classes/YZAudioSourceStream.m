//
//  YZAudioSourceStream.m
//  DMCPlayerDemo
//
//  Created by Zhang Yan on 16/6/2.
//  Copyright © 2016年 TOPDMC. All rights reserved.
//

#import "YZAudioSourceStream.h"

#define kCalculateBitratePacketsNumber 50

@interface YZAudioSourceStream()<NSURLSessionDelegate>

@property (nonatomic, assign) AudioFileStreamID audioFileStreamID;

@property (nonatomic, assign) NSInteger dataOffset;
@property (nonatomic, assign) NSInteger fileLength;
@property (nonatomic, assign) UInt64 audioDataByteCount;

@property (nonatomic, assign) long processedPacketsSize;
@property (nonatomic, assign) long processedPacketsNumber;

@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;

@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@property(nonatomic, assign) BOOL isCompleted;

@end

@implementation YZAudioSourceStream

- (instancetype)init {
    if (self = [super init]) {
        _isCompleted = NO;
    }
    
    return self;
}

- (NSTimeInterval)duration {
    double packetDuration = self.streamDescription.mFramesPerPacket / self.streamDescription.mSampleRate;
    double bitrate = 8.0 * self.processedPacketsSize / self.processedPacketsNumber / packetDuration;
    return (self.fileLength - self.dataOffset) / (bitrate * 0.125);
}

- (void)start {
    
    if (!_sessionQueue) {
        self.sessionQueue = dispatch_queue_create("YZStream Session", NULL);
    }
    
    dispatch_async(self.sessionQueue, ^{
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
//        if (!_urlSession) {
            _urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:operationQueue];
//        }
        _dataTask = [_urlSession dataTaskWithURL:_url];
        [_dataTask resume];
   });
    
    OSStatus status = AudioFileStreamOpen((__bridge void *)self, AudioFileStreamPropertyProc, AudioFileStreamPacketsProc, kAudioFileMP3Type, &_audioFileStreamID);
    if (status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Open File Stream Failed: %@",  [error localizedDescription]);
    }
}

- (void)stop {
    if (_sessionQueue) {
        dispatch_sync(self.sessionQueue, ^{
            [_dataTask cancel];
            [_urlSession invalidateAndCancel];
            self.fileLength = 0;
            self.dataOffset = 0;
            self.audioDataByteCount = 0;
            self.processedPacketsSize = 0;
            self.processedPacketsNumber = 0;
            AudioFileStreamClose(self.audioFileStreamID);
        });
    }
}

- (BOOL)isCompleted {
    return _isCompleted;
}

- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags
{
    OSStatus err;
    if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets)
    {
        //            discontinuous = true;
    }
    else if (inPropertyID == kAudioFileStreamProperty_DataOffset)
    {
        SInt64 offset;
        UInt32 offsetSize = sizeof(offset);
        err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataOffset, &offsetSize, &offset);
        if (err)
        {
            //                [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
            return;
        }
        self.dataOffset = offset;
        if (self.audioDataByteCount)
        {
            self.fileLength = self.dataOffset + self.audioDataByteCount;
        }
    }
    else if (inPropertyID == kAudioFileStreamProperty_AudioDataByteCount)
    {
        UInt32 byteCountSize = sizeof(UInt64);
        err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &_audioDataByteCount);
        if (err)
        {
            //            [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
            return;
        }
        self.fileLength = self.dataOffset + self.audioDataByteCount;
    }
    else if (inPropertyID == kAudioFileStreamProperty_DataFormat)
    {
        if (self.streamDescription.mSampleRate == 0)
        {
            UInt32 asbdSize = sizeof(self.streamDescription);
            
            // get the stream format.
            err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &_streamDescription);
            if (err)
            {
                //                [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
                return;
            }
        }
        [self.delegate audioSource:self streamDescriptionChanged:self.streamDescription];
    }
    else if (inPropertyID == kAudioFileStreamProperty_FormatList)
    {
        Boolean outWriteable;
        UInt32 formatListSize;
        err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
        if (err)
        {
            //            [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
            return;
        }
        
        AudioFormatListItem *formatList = malloc(formatListSize);
        err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
        if (err)
        {
            free(formatList);
            //            [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
            return;
        }
        
        for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
        {
            AudioStreamBasicDescription pasbd = formatList[i].mASBD;
            
            if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE ||
                pasbd.mFormatID == kAudioFormatMPEG4AAC_HE_V2)
            {
                //
                // We've found HE-AAC, remember this to tell the audio queue
                // when we construct it.
                //
#if !TARGET_IPHONE_SIMULATOR
                self.streamDescription = pasbd;
#endif
                [self.delegate audioSource:self streamDescriptionChanged:self.streamDescription];
                break;
            }
        }
        free(formatList);
    }
        			NSLog(@"Property is %c%c%c%c",
        				((char *)&inPropertyID)[3],
        				((char *)&inPropertyID)[2],
        				((char *)&inPropertyID)[1],
        				((char *)&inPropertyID)[0]);
}

- (void)handleStreamPackets:(const void *)inInputData numberBytes:(UInt32)inNumberBytes numberPackets:(UInt32)inNumberPackets packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions {
    if (inNumberBytes == 0 || inNumberPackets == 0) {
        return;
    }
    
    BOOL deletePackDesc = NO;
    if (inPacketDescriptions == NULL)
    {
        // CBR
        deletePackDesc = YES;
        UInt32 packetSize = inNumberBytes / inNumberPackets;
        inPacketDescriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * inNumberPackets);
        
        for (int i = 0; i < inNumberPackets; i++)
        {
            UInt32 packetOffset = packetSize * i;
            inPacketDescriptions[i].mStartOffset = packetOffset;
            inPacketDescriptions[i].mVariableFramesInPacket = 0;
            if (i == inNumberPackets - 1)
            {
                inPacketDescriptions[i].mDataByteSize = inNumberBytes - packetOffset;
            }
            else
            {
                inPacketDescriptions[i].mDataByteSize = packetSize;
            }
        }
    } else {
        // VBR
        for (int i = 0; i < inNumberPackets; ++i)
        {
            SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
            SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;
            
            [self.delegate audioSource:self dataDecoded:(const char*)inInputData size:packetSize offset:packetOffset desc:inPacketDescriptions[i]];
            
            if (self.processedPacketsNumber < kCalculateBitratePacketsNumber)
            {
                self.processedPacketsSize += packetSize;
                self.processedPacketsNumber += 1;
            }
        }
    }
    
    if (deletePackDesc)
    {
        free(inPacketDescriptions);
    }
}


#pragma mark - 
static void AudioFileStreamPropertyProc ( void *inClientData, AudioFileStreamID	inAudioFileStream, AudioFileStreamPropertyID	inPropertyID, AudioFileStreamPropertyFlags *	ioFlags) {
    YZAudioSourceStream *audioSource = (__bridge YZAudioSourceStream *)inClientData;
    [audioSource handlePropertyChangeForFileStream:inAudioFileStream fileStreamPropertyID:inPropertyID ioFlags:ioFlags];
}

static void AudioFileStreamPacketsProc (void *inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
    
    YZAudioSourceStream *audioSource = (__bridge YZAudioSourceStream *)inClientData;
    [audioSource handleStreamPackets:inInputData numberBytes:inNumberBytes numberPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
}

#pragma mark - NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    dispatch_async(dispatch_get_main_queue(), ^{
        OSStatus status = AudioFileStreamParseBytes(self.audioFileStreamID, (UInt32)[data length], [data bytes], 0);
        if (status != noErr) {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            //        NSLog(@"Audio Stream Parsed Failed: %@",  [error localizedDescription]);
            NSAssert(status == noErr, @"Audio Stream Parsed Failed: %@",  [error localizedDescription]);
        }
    });
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    self.fileLength = response.expectedContentLength;
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    if (error) {
        NSLog(@"session completed with error: %@", [error localizedDescription]);
        return;
    }
    
    self.isCompleted = YES;
    [self.delegate audioSourceDataCompleted:self];
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    if (error) {
        NSLog(@"session become invalid with error: %@", [error localizedDescription]);
    }
}

@end
