//
//  ZBSpeech.h
//  SpeechToText
//
//  Created by ZB on 2023/11/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ZBSpeechDelegate <NSObject>

@required
/// 听写结束回调
- (void)onResults:(NSString *)results isLast:(BOOL)isLast;
@optional
/// 提示回调
- (void)onTips:(NSString *)tipsStr;
/// 开始录音回调
- (void)onBeginOfSpeech;
/// 停止录音回调
- (void)onEndOfSpeech;

@end



@interface ZBSpeech : NSObject

@property (nonatomic, weak) id <ZBSpeechDelegate> delegate;

+ (instancetype)shareSpeech;

/// 开始听写
- (void)startRecognize;

/// 停止听写
- (void)stopRecognize;

/// 取消
- (void)cancelRecognize;

@end

NS_ASSUME_NONNULL_END
