//
//  ViewController.m
//  SocketDemo
//
//  Created by YuboZhou on 2018/12/11.
//  Copyright © 2018 YuboZhou. All rights reserved.
//

#import "ViewController.h"
#import <GCDAsyncSocket.h>

static NSString *hostString = @"47.52.53.52";
static NSInteger portInt = 443;

@interface ViewController () <GCDAsyncSocketDelegate> {
    
    NSMutableData *_data;
    NSInteger maxLength;
}

@property (nonatomic, strong) GCDAsyncSocket *clientSocket;
@property (nonatomic, strong) NSMutableData *resultData;

@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    NSError *error = nil;
    [_clientSocket connectToHost:hostString
                          onPort:portInt
                           error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
   // [self connectToServerWithCommand:@"1"];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    NSDictionary *dict = @{@"c":@"6",
                           @"cmd":@"1"
                           };
    NSString *jsonString = [self convertToJsonData:dict];
    
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    int le = (int)jsonString.length;
    NSData *lenghData = [self intToData:le];
    self.resultData = [NSMutableData data];
    [self.clientSocket writeData:lenghData withTimeout:-1 tag:0];
    [self.clientSocket writeData:data withTimeout:-1 tag:0];
}

- (NSData *)intToData:(int)value {
    
    Byte byte[4] = {};
    byte[0] =  (Byte) ((value>>24) & 0xFF);
    byte[1] =  (Byte) ((value>>16) & 0xFF);
    byte[2] =  (Byte) ((value>>8) & 0xFF);
    byte[3] =  (Byte) (value & 0xFF);
    
    return [NSData dataWithBytes:byte length:4];
}

- (int)dataToInt:(NSData *)data {
    
    Byte byte[4] = {};
    [data getBytes:byte length:4];
    int value;
    value = (int) (((byte[0] & 0xFF)<<24)
                   | ((byte[1] & 0xFF)<<16)
                   | ((byte[2] & 0xFF)<<8)
                   | (byte[3] & 0xFF));
    
    return value;
}

- (void)connectToServerWithCommand:(NSString *)command
{
    _clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [_clientSocket setUserData:command];
    
    NSError *error = nil;
    [_clientSocket connectToHost:hostString onPort:portInt error:&error];
    if (error) {
        NSLog(@"__connect error:%@",error.userInfo);
    }
    
    [_clientSocket writeData:[command dataUsingEncoding:NSUTF8StringEncoding] withTimeout:10.0f tag:6];
}

#pragma mark - GCDAsyncSocketDelegate
// 连接成功
- (void)socket:(GCDAsyncSocket *)sock
didConnectToHost:(NSString *)host
          port:(uint16_t)port {
   
    NSDictionary *userJson = @{@"c":@"1",
                               @"lo":@"",
                               @"pwd":@"",
                               @"price_mode":@"0"
                               };
    
    NSString *jsonString = [self convertToJsonData:userJson];
    int le = (int)jsonString.length;
    NSData *lenghData = [self intToData:le];
    [self.clientSocket writeData:lenghData withTimeout:-1 tag:201];
    [self.clientSocket writeData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:201];
}

// 断开连接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(NSError *)err {
    if (err) {
        NSLog(@"连接失败:%@",err);
    } else {
        NSLog(@"正常断开");
    }
}

// 发送数据
- (void)socket:(GCDAsyncSocket *)sock
didWriteDataWithTag:(long)tag {
    
    NSLog(@"%s",__func__);
    
    //发送完数据手动读取，-1不设置超时
    [sock readDataWithTimeout:-1
                          tag:tag];
}

// 读取数据
-(void)socket:(GCDAsyncSocket *)sock
  didReadData:(NSData *)data
      withTag:(long)tag {
    
  //  NSLog(@"data:%@",data);
    
    [self newExportResultData:data andTag:tag];
   // NSLog(@"%s %@ - %@",__func__,receiverStr,data);
}


// 新解包
- (void)newExportResultData:(NSData *)data andTag:(long)tag {
    
    if (data.length < 4) {
        
        return;
    }
    
    int dataLength = [self dataToInt:[data subdataWithRange:NSMakeRange(0, sizeof(4))]]; // 前4个byte代表数据长度
    
    if (!_data) {
        
        _data = [[NSMutableData alloc] init];
    }
    
    // 含有数据长度
    if (dataLength < 36864) {
        
        _data.length = 0;
        maxLength = dataLength;
        
        if (data.length > dataLength + 4) {
            
            NSData *jsonData = [data subdataWithRange:NSMakeRange(4, dataLength)];
            // 初次拼接
            [_data appendData:jsonData];
            
            // 判断是否拼接完整
            BOOL full = [self jsonIsFullWithTag:tag];
            if (full) {
                
                // 判断本次data是否还含有其他json数据
                if (data.length > dataLength + 4) {
                    
                    NSData *newJsonData = [data subdataWithRange:NSMakeRange(dataLength + 4, sizeof(data.length - dataLength - 4))];
                    [self newExportResultData:newJsonData andTag:tag];
                }
            }
        }else {
            
            NSData *jsonData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
            // 初次拼接
            [_data appendData:jsonData];
            
            [self jsonIsFullWithTag:tag];
        }
        
    }else {
        
        long endLength = maxLength - _data.length;
        
        if (data.length > endLength) {
            
            NSData *jsonData = [data subdataWithRange:NSMakeRange(0, endLength)];
            // 二次拼接
            [_data appendData:jsonData];
            
            // 判断是否拼接完整
            BOOL full = [self jsonIsFullWithTag:tag];
            
            if (full) {
                
                // 判断本次data是否还含有其他json数据
                if (data.length > dataLength + 4) {
                    
                    NSData *newJsonData = [data subdataWithRange:NSMakeRange(dataLength + 4, sizeof(data.length - dataLength - 4))];
                    [self newExportResultData:newJsonData andTag:tag];
                }
            }
        }else {
            
            // 二次拼接
            [_data appendData:data];
            
            [self jsonIsFullWithTag:tag];
        }
    }
}

- (BOOL)jsonIsFullWithTag:(long)tag {
    
    if (_data.length ==  maxLength) {
        
        id json = [NSJSONSerialization JSONObjectWithData:_data options:0 error:nil];
        if (json) {
            
            // 拼接成功完整json，发送data，并且清空接收model
            NSLog(@"JSON:%@",json);
            
            maxLength = 0;
            _data.length = 0;
        }else {
            
            NSLog(@"异常的Json数据:%@",_data);
        }
        return YES;
    }else {
        
        //  NSLog(@"还没有拼接完成，当前长度:%ld，总长度:%d",self.dataModel.resultData.length,self.dataModel.maxLength);
        return NO;
    }
    
    return NO;
}

// 输出json
- (void)printJson:(NSData *)data {
    
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (json) {
        
        NSDictionary *dict = json;
        
        if ([dict[@"k"] isEqualToNumber:@(201)]) {
            
            NSLog(@"json:%@",json);
        }
    }else {
        
        NSLog(@"data:%@",data);
    }
}

- (void)bytesplit2byte:(Byte[])src orc:(Byte[])orc begin:(NSInteger)begin count:(NSInteger)count {
    
    for (NSInteger i = begin; i < begin+count; i++){
        orc[i-begin] = src[i];
    }
}

- (NSString *)_859ToUTF8:(NSString *)oldStr
{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin1);
    
    NSString *str = nil;
    // 是否能变成ISO-8859-1这种编码的数据
    if ([oldStr canBeConvertedToEncoding:kCFStringEncodingISOLatin1]) {
        // 将ISO-8859-1的字符转成uft8
        str = [NSString stringWithUTF8String:[oldStr cStringUsingEncoding:enc]];
    }else{
        str = oldStr;
    }
    
    return str;
}

- (NSString *)convertToJsonData:(NSDictionary *)dict {

    NSError *error;

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];

    NSString *jsonString;

    if (!jsonData) {

        NSLog(@"%@", error);

    } else {

        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }

    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];

    NSRange range = {0, jsonString.length};

    //去掉字符串中的空格

    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];

    NSRange range2 = {0, mutStr.length};

    //去掉字符串中的换行符

    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];

    return mutStr;
}

- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

@end
