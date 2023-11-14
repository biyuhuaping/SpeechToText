//
//  ZBSpeech.m
//  SpeechToText
//
//  Created by ZB on 2023/11/14.
//

#import "ZBSpeech.h"
#import <Speech/Speech.h>

@interface ZBSpeech ()<SFSpeechRecognizerDelegate>

// 创建语音识别器，指定语音识别的语言环境 locale ,将来会转化为什么语言，这里是使用的当前区域
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
// 语音识别任务，可监控识别进度。通过他可以取消或终止当前的语音识别任务
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;

// 发起语音识别请求，为语音识别器指定一个音频输入源，这里是在音频缓冲器中提供的识别语音。
// 除 SFSpeechAudioBufferRecognitionRequest 之外还包括：
// SFSpeechRecognitionRequest  从音频源识别语音的请求。
// SFSpeechURLRecognitionRequest 在录制的音频文件中识别语音的请求。
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;

// 语音引擎，负责提供录音输入
@property (nonatomic, strong) AVAudioEngine *audioEngine;

@end


@implementation ZBSpeech

+ (instancetype)shareSpeech{
    static ZBSpeech *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ZBSpeech alloc] init];
    });
    return instance;
}

- (instancetype)init{
    if (self = [super init]) {
        [self initializeFlySpeech];
    }
    return self;
}

//初始化讯飞语音底层
- (void)initializeFlySpeech{
    //    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale currentLocale]];
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh-CN"]];
    self.speechRecognizer.delegate = self;
    //    NSLog(@"语音识别器支持的区域：%@",[SFSpeechRecognizer supportedLocales]);
    //    NSLog(@"语音识别器支持的区域：%@",self.speechRecognizer.locale);
    //    NSLocale *locale  = self.speechRecognizer.locale;
    
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    //  在进行语音识别之前，你必须获得用户的相应授权，因为语音识别并不是在iOS 设备本地进行识别，而是在苹果的伺服器上进行识别的。所有的语音数据都需要传给苹果的后台服务器进行处理。因此必须得到用户的授权,这个方法并不是在主线程运行的。
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        NSString *text = @"";
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusNotDetermined: {//用户未决定
                text = @"权限提示：用户未决定";
            }
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied: {//拒绝
                text = @"权限提示：用户拒绝";
            }
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted: {//不支持
                text = @"权限提示：用户的设备不支持";
            }
                break;
            case SFSpeechRecognizerAuthorizationStatusAuthorized: {//允许
                text = @"权限提示：用户允许";
            }
                break;
            default:
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(onTips:)]){
                [self.delegate onTips:text];
            }
        });
    }];
}

//停止听写
- (void)stopRecognize{
    // 停止录音
    [self.audioEngine stop];
    // 表示音频源已完成，并且不会再将音频附加到识别请求。
    [self.recognitionRequest endAudio];
    
    //停止录音
    if (self.delegate && [self.delegate respondsToSelector:@selector(onEndOfSpeech)]){
        [self.delegate onEndOfSpeech];
    }
}

//取消
- (void)cancelRecognize{
    // 取消当前语音识别任务
    [self.recognitionTask cancel];
    self.recognitionTask = nil;
    [self stopRecognize];
    self.speechRecognizer.delegate = nil;
    self.delegate = nil;
}

//开始听写
- (void)startRecognize{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBeginOfSpeech)]){
        [self.delegate onBeginOfSpeech];
    }
    // 检查 recognitionTask 任务是否处于运行状态。如果是，取消任务开始新的任务
    if (self.recognitionTask != nil) {
        // 取消当前语音识别任务
        [self.recognitionTask cancel];
        NSLog(@"语音识别任务的当前状态 : %ld",(long)self.recognitionTask.state);
        self.recognitionTask = nil;
    }
    
    // 建立一个AVAudioSession 用于录音
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    // category 设置为 record,录音
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    // mode 设置为 measurement
    [audioSession setMode:AVAudioSessionModeMeasurement error:nil];
    // 开启 audioSession
    [audioSession setActive:YES error:nil];
    
    // 初始化RecognitionRequest，在后边我们会用它将录音数据转发给苹果服务器
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    
    // 检查 iPhone 是否有有效的录音设备
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    if (!inputNode) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onTips:)]){
            [self.delegate onTips:@"无效的录音设备"];
        }
    }

    // 在用户说话的同时，将识别结果分批次返回
    self.recognitionRequest.shouldReportPartialResults = YES;
    
    // 使用recognitionTask方法开始识别。
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        // 用于检查识别是否结束
        BOOL isFinal = NO;
        if (result != nil) {
            // 将 textView.text 设置为 result 的最佳音译
//            self.textView.text = result.bestTranscription.formattedString;
            if (self.delegate && [self.delegate respondsToSelector:@selector(onResults:isLast:)]){
                [self.delegate onResults:result.bestTranscription.formattedString isLast:result.isFinal];
            }
            // 如果 result 是最终，将 isFinal 设置为 true
            isFinal = result.isFinal;
        }
        
        // 如果没有错误发生，或者 result 已经结束，停止audioEngine 录音，终止 recognitionRequest 和 recognitionTask
        if (error != nil || isFinal) {
            [self.audioEngine stop];
            [inputNode removeTapOnBus:0];
            
            self.recognitionRequest = nil;
            self.recognitionTask = nil;
            
            //停止录音
            if (self.delegate && [self.delegate respondsToSelector:@selector(onEndOfSpeech)]){
                [self.delegate onEndOfSpeech];
            }
        }
    }];
    
    // 向recognitionRequest加入一个音频输入
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [self.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:nil];
//    self.textView.text = @"请讲话...";
}

@end
