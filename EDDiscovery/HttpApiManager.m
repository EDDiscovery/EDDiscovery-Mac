//
//  HttpApiManager.h
//  EDDiscovery
//
//  Created by Luca Giacometti on 17/04/16.
//  Copyright © 2016 Luca Giacometti. All rights reserved.
//

#import "HttpApiManager.h"
#import "NSURLConnection+Progress.h"

NSString* baseUrl=nil;
NSString* locale=nil;

@implementation HttpApiManager

+(void)setBaseUrl:(NSString*)aBaseUrl
{
  baseUrl=aBaseUrl;
}

+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent withMethod:(NSString*)aMethod progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback parametersCount:(NSInteger)count parameters:(va_list)valist
{
  NSString* value1;
  NSString* value2;
  NSMutableString* urlString;
  if (apiName!=nil)
  {
    urlString=[NSMutableString stringWithFormat:@"%@/%@",
               baseUrl,
               apiName];
  }
  else
  {
    urlString=[NSMutableString stringWithFormat:@"%@",baseUrl];
  }
  NSMutableString* parameter=[NSMutableString string];
  for (int i=0; i<count; i++)
  {
    value1=va_arg(valist, NSString*);
    value2=va_arg(valist, NSString*);
    value2=(NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (CFStringRef)value2,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'();:@&=+$/?%#[]",
                                                                                 kCFStringEncodingUTF8 ));
    [parameter appendFormat:@"%@%@=%@", (parameter.length == 0) ? @"" : @"&", value1, value2!=nil?value2:@""];
  }
  
  NSMutableURLRequest *request;
  if ([aMethod isEqualToString:@"POST"])
  {
    request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[parameter dataUsingEncoding:NSASCIIStringEncoding]];
  }
  else
  {
    request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[urlString stringByAppendingFormat:@"?%@",parameter]]];
  }
  
  [self scheduleConnectionWithRequest:request concurrent:concurrent progressCallback:progressCallback responseCallback:responseCallback];
}

+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent withMethod:(NSString*)aMethod progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback parameters:(NSInteger)count,...
{
  va_list args;
  va_start(args, count);
  [HttpApiManager callApi:apiName
               concurrent:concurrent
               withMethod:aMethod
         progressCallBack:progressCallback
         responseCallback:responseCallback
          parametersCount:count
               parameters:args];
}

+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback multipartsCount:(NSInteger)count multiparts:(va_list)valist
{
  NSString* value1=nil;
  NSString* value2=nil;
  NSString* value3=nil;
  NSData* fileData=nil;
  NSMutableString* urlString;
  if (apiName!=nil)
  {
    urlString=[NSMutableString stringWithFormat:@"%@/%@",
               baseUrl,
               apiName];
  }
  else
  {
    urlString=[NSMutableString stringWithFormat:@"%@",baseUrl];
  }
  NSMutableData* postData=[NSMutableData data];

  for (int i=0; i<count; i++)
  {
    value1=va_arg(valist, NSString*);
    value2=va_arg(valist, NSString*);
    value3=nil;
    fileData=nil;
    if ([value2 isEqualToString:@"value"])
    {
      value3=va_arg(valist, NSString*);
    }
    else
    {
      fileData=va_arg(valist, NSData*);
    }
    
    [postData appendData:[[NSString stringWithFormat:@"--%@\r\n",BOUNDARY_TAG] dataUsingEncoding:NSUTF8StringEncoding]];
    
    if ([value2 isEqualToString:@"value"])
    {
      [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n",value1] dataUsingEncoding:NSUTF8StringEncoding]];
      [postData appendData:[[NSString stringWithFormat:@"%@",value3] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    else
    {
      if (fileData!=nil)
      {
        [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: file; filename=\"%@\"\r\n",value1] dataUsingEncoding:NSUTF8StringEncoding]];
        [postData appendData:[[NSString stringWithFormat:@"Content-Type: %@;\r\n\r\n",value2] dataUsingEncoding:NSUTF8StringEncoding]];
        [postData appendData:fileData];
      }
    }

    [postData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  }

  [postData appendData:[[NSString stringWithFormat:@"--%@",BOUNDARY_TAG] dataUsingEncoding:NSUTF8StringEncoding]];
  
  NSMutableURLRequest *request;
  request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
  [request setHTTPMethod:@"POST"];
  [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", BOUNDARY_TAG] forHTTPHeaderField:@"Content-Type"];
  [request setHTTPBody:postData];
  
  [self scheduleConnectionWithRequest:request concurrent:(BOOL)concurrent progressCallback:progressCallback responseCallback:responseCallback];
}

+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback multiparts:(NSInteger)count,...
{
  va_list args;
  va_start(args, count);
  [HttpApiManager callApi:apiName
               concurrent:concurrent
         progressCallBack:progressCallback
         responseCallback:responseCallback
          multipartsCount:count
               multiparts:args];
}

+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent withBody:(NSData*)aBody progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback {
  NSMutableString* urlString;
  if (apiName!=nil)
  {
    urlString=[NSMutableString stringWithFormat:@"%@/%@",
               baseUrl,
               apiName];
  }
  else
  {
    urlString=[NSMutableString stringWithFormat:@"%@",baseUrl];
  }
  
  NSMutableURLRequest *request;
  request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
  [request setHTTPMethod:@"POST"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request setHTTPBody:aBody];
  
  [self scheduleConnectionWithRequest:request concurrent:concurrent progressCallback:progressCallback responseCallback:responseCallback];
}

+(void)scheduleConnectionWithRequest:(NSURLRequest *)request
                          concurrent:(BOOL)concurrent
                    progressCallback:(ProgressBlock)progressCallback
                  responseCallback:(void(^)(id response, NSError *error))responseCallback {

  [NSURLConnection sendAsynchronousRequest:request
                                concurrent:concurrent
                           progressHandler:progressCallback
                         completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
                           
#ifdef HTTP_API_MANAGER_DEBUG
                           NSString *string = [NSString stringWithFormat:@"length: %ld", (long)data.length];
                           
                           if (data.length < 51200) {
                             string = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding: NSUTF8StringEncoding];
                           }
                           
                           NSLog(@"---------- Request ----------");
                           NSLog(@"%@ %@",request.HTTPMethod,request.URL);
                           NSLog(@"---------- body ----------");
                           NSLog(@"%@",[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
                           NSLog(@"---------- Response ----------");
                           NSLog(@"%@",string);
#endif
                           
                           if (error!=nil)
                           {
                             responseCallback(nil,error);
                           }
                           else {
                             responseCallback(data,nil);
                           }
                         }];
}

@end
