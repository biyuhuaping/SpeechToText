//
//  ViewController.m
//  SpeechToText
//
//  Created by ZB on 2023/11/10.
//

#import "ViewController.h"
#import "ZBSpeech.h"

@interface ViewController ()<ZBSpeechDelegate>

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *startBtn;
@property (weak, nonatomic) IBOutlet UILabel *tipLabel;
@property (nonatomic ,strong) IBOutlet UIImageView *imageAnimation;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSMutableArray *images = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        [images addObject:[UIImage imageNamed:[NSString stringWithFormat:@"speech%d",i]]];
    }
    self.imageAnimation.animationImages = images;
    self.imageAnimation.animationDuration = 0.4;
    [ZBSpeech shareSpeech].delegate = self;
}

- (void)setTioLabelText:(NSString *)text withBtnEnable:(BOOL)enAble{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tipLabel.text = text;
        self.startBtn.enabled = enAble;
        [self.startBtn setTitleColor:enAble ? UIColor.blueColor :UIColor.grayColor forState:UIControlStateNormal];
    });
}

// 开始 / 结束
- (IBAction)startBtnClick:(id)sender {
    [[UIApplication sharedApplication].keyWindow endEditing:YES];
    if ([self.startBtn.titleLabel.text isEqualToString:@"结束"]) {
        //停止听写
        [[ZBSpeech shareSpeech] stopRecognize];
        [self.startBtn setTitle:@"开始" forState:UIControlStateNormal];
    }else{
        //启动听写
        [[ZBSpeech shareSpeech] startRecognize];
        [self.startBtn setTitle:@"结束" forState:UIControlStateNormal];
    }
}

#pragma mark - ZBSpeechDelegate
/// 听写结束回调
- (void)onResults:(NSString *)results isLast:(BOOL)isLast{
    if (isLast){
        NSLog(@"isLast:%d",isLast);
    }
    self.textView.text = results;
}

/// 提示回调
- (void)onTips:(NSString *)tipsStr{
    self.tipLabel.text = tipsStr;
}

/// 开始录音回调
- (void)onBeginOfSpeech{
    [self.imageAnimation startAnimating];
}

/// 停止录音回调
- (void)onEndOfSpeech{
    [self.imageAnimation stopAnimating];
}

//在创建语音识别任务时，我们首先得确保语音识别的可用性，需要实现delegate 方法。如果语音识别不可用，或是改变了状态，应随之设置 按钮的enable
//- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available{
//    if (available) {
//        self.startBtn.enabled = YES;
//        [self.startBtn setTitleColor:UIColor.blueColor forState:UIControlStateNormal];
//    }else{
//        self.startBtn.enabled = NO;
//        [self.startBtn setTitleColor:UIColor.grayColor forState:UIControlStateNormal];
//    }
//}

@end




/*
 * 检查 recognitionTask 的运行状态，如果正在运行，取消任务。
 
 * 创建一个 AVAudioSession 对象为音频录制做准备。这里我们将录音分类设置为 Record，模式设为 Measurement，然后启动。注意，设置这些属性有可能会抛出异常，因此你必须将其置于 try catch 语句中。
 
 * 实例化 recognitionResquest。创建 SFSpeechAudioBufferRecognitionRequest 对象，然后我们就可以利用它将音频数据传输到 Apple 的服务器。
 
 * 检查 audioEngine (你的设备)是否支持音频输入以录音。如果不支持，报一个 fatal error。
 
 * 检查 recognitionRequest 对象是否已被实例化，并且值不为 nil。
 
 * 告诉 recognitionRequest 不要等到录音完成才发送请求，而是在用户说话时一部分一部分发送语音识别数据。
 
 * 在调用 speechRecognizer 的 recognitionTask 函数时开始识别。该函数有一个完成回调函数，每次识别引擎收到输入时都会调用它，在修改当前识别结果，亦或是取消或停止时，返回一个最终记录。
 
 * 定义一个 boolean 变量来表示识别是否已结束。
 
 * 倘若结果非空，则设置 textView.text 属性为结果中的最佳记录。同时若为最终结果，将 isFinal 置为 true。
 
 * 如果请求没有错误或已经收到最终结果，停止 audioEngine (音频输入)，recognitionRequest 和 recognitionTask。同时，将开始录音按钮的状态切换为可用。
 
 * 向 recognitionRequest 添加一个音频输入。值得留意的是，在 recognitionTask 启动后再添加音频输入完全没有问题。Speech 框架会在添加了音频输入之后立即开始识别任务。
 
 * 将 audioEngine 设为准备就绪状态，并启动引擎。
 */

