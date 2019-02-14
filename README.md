# GCDSocketDemo
iOS的socket简易demo，包含数据解析参考

GCDAsyncSocket *clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];

NSError *error = nil;

[clientSocket connectToHost:@"47.52.53.52"
                      onPort:43
                       error:&error];
                       
NSDictionary *dict = @{@"c":@"6",@"cmd":@"1"};

NSString *jsonString = [self convertToJsonData:dict];

NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];

int le = (int)jsonString.length;

NSData *lenghData = [self intToData:le];

[clientSocket writeData:lenghData withTimeout:-1 tag:0];

[clientSocket writeData:data withTimeout:-1 tag:0];
