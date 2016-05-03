//
//  JsonApiManager.m
//  EasyGroups
//
//  Created by WorkLuca on 02/02/15.
//  Copyright 2010 Zirak. All rights reserved.
//

#import "HttpApiManager.h"

dispatch_queue_t queue;
dispatch_once_t onceToken;

NSString* keychainPrefix;
NSString* baseUrl=nil;
NSString* email=nil;
NSString* password=nil;
NSString* locale=nil;

@implementation HttpApiManager

+(NSString*)email
{
 return email;
}

+(NSString*)password
{
 return password;
}

+(void)setBaseUrl:(NSString*)aBaseUrl andKeychainPrefix:(NSString*)aKeychainPrefix
{
 dispatch_once(&onceToken, ^{
  queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT);
 });
 baseUrl=aBaseUrl;
 keychainPrefix=aKeychainPrefix;
}

+(void)setEmail:(NSString*)newEmail andPassword:(NSString*)newPassword
{
 email=newEmail;
 password=newPassword;
 locale=[[[NSLocale currentLocale] localeIdentifier] stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
 
 [HttpApiManager saveCredential];
}

+(BOOL)loadCredential
{
#warning TODO
  return NO;
// NSString* appID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
// NSString* accessGroup=[NSString stringWithFormat:@"%@.%@",keychainPrefix,appID];
// NSLog(@"Loading HttpApi data to keychain with ID: %@ and Group: %@",HTTP_API_MANAGER_IDENTIFIER,accessGroup);
// 
// KeychainItemWrapper* aKeychainWrapper=[[KeychainItemWrapper alloc] initWithIdentifier:HTTP_API_MANAGER_IDENTIFIER accessGroup:accessGroup];
// 
// // [aKeychainWrapper setObject:HTTP_API_MANAGER_IDENTIFIER forKey:HTTP_API_MANAGER_SERVICE_KEY];
// email=[aKeychainWrapper objectForKey:HTTP_API_MANAGER_EMAIL_KEY];
// password=[aKeychainWrapper objectForKey:HTTP_API_MANAGER_PASSWORD_KEY];
// locale=[[[NSLocale currentLocale] localeIdentifier] stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
// 
// return email!=nil && ![email isEqualToString:@""] && password!=nil && ![password isEqualToString:@""];
}

+(void)saveCredential
{
#warning TODO
//NSString* appID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
// NSString* accessGroup=[NSString stringWithFormat:@"%@.%@",keychainPrefix,appID];
// NSLog(@"Saving HttpApi data to keychain with ID: %@ and Group: %@",HTTP_API_MANAGER_IDENTIFIER,accessGroup);
// 
// KeychainItemWrapper* aKeychainWrapper=[[KeychainItemWrapper alloc] initWithIdentifier:HTTP_API_MANAGER_IDENTIFIER accessGroup:accessGroup];
// 
// // [aKeychainWrapper setObject:HTTP_API_MANAGER_IDENTIFIER forKey:HTTP_API_MANAGER_SERVICE_KEY];
// [aKeychainWrapper setObject:email forKey:HTTP_API_MANAGER_EMAIL_KEY];
// [aKeychainWrapper setObject:password forKey:HTTP_API_MANAGER_PASSWORD_KEY];
}

+(void)resetCredential
{
#warning TODO
// NSString* appID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
// NSString* accessGroup=[NSString stringWithFormat:@"%@.%@",keychainPrefix,appID];
// NSLog(@"Resetting HttpApi data for keychain with ID: %@ and Group: %@",HTTP_API_MANAGER_IDENTIFIER,accessGroup);
// 
// KeychainItemWrapper* aKeychainWrapper=[[KeychainItemWrapper alloc] initWithIdentifier:appID accessGroup:accessGroup];
// 
// // [aKeychainWrapper setObject:HTTP_API_MANAGER_IDENTIFIER forKey:HTTP_API_MANAGER_SERVICE_KEY];
// [aKeychainWrapper resetKeychainItem];
}

+(NSMutableString*)constructBaseParameterWithCredential:(BOOL)sendUsernameAndPassword
{
 NSMutableString* baseParameter=[NSMutableString string];
 if (email!=nil)
 {
  [baseParameter appendFormat:@"userLocale=%@",locale];
#ifdef HTTP_API_MANAGER_DEBUG
  [baseParameter appendFormat:@"&debug=1"];
#endif
  if (sendUsernameAndPassword)
  {
   [baseParameter appendFormat:@"&userEmail=%@",[email stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
   [baseParameter appendFormat:@"&userPassword=%@",[password stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
  }
 }
 return baseParameter;
}

+(void)willCallApi
{
// [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
// [UIApplication sharedApplication].networkActivityIndicatorVisible=YES;
}

+(void)didCallApi
{
// [UIApplication sharedApplication].networkActivityIndicatorVisible=NO;
// [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

+(void)callApi:(NSString*)apiName withMethod:(NSString*)aMethod sendCredential:(BOOL)sendUsernameAndPassword responseCallback:(void(^)(id response, NSError *error))callback parametersCount:(NSInteger)count parameters:(va_list)valist
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
 NSMutableString* parameter=[HttpApiManager constructBaseParameterWithCredential:sendUsernameAndPassword];
 for (int i=0; i<count; i++)
 {
  value1=va_arg(valist, NSString*);
  value2=va_arg(valist, NSString*);
  value2=(NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                               (CFStringRef)value2,
                                                                               NULL,
                                                                               (CFStringRef)@"!*'();:@&=+$/?%#[]",//(CFStringRef)@"!*'();:@&=+$,/?%#[]",
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
 dispatch_async(queue, ^{
  NSError* error=nil;

  NSData *data=[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
  NSString *string=[[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];
  
 #ifdef HTTP_API_MANAGER_DEBUG
   NSString *msg = [NSString stringWithFormat:@"\n%@\n%@\n%@\n%@\n%@\n%@\n\n",
                    @"---------- Request ----------",
                    [NSString stringWithFormat:@"%@ %@", aMethod, urlString],
                    @"---------- Parameters ----------",
                    parameter,
                    @"---------- Response ----------",
                    string];
   
   NSLog(@"%@", msg);
 #endif
  
  if (error!=nil)
  {
   dispatch_async(dispatch_get_main_queue(), ^{
    callback(nil,error);
   });
   return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
   callback(data,nil);
  });
 });
}

+(void)callApi:(NSString*)apiName withMethod:(NSString*)aMethod sendCredential:(BOOL)sendUsernameAndPassword responseCallback:(void(^)(id response, NSError *error))callback parameters:(NSInteger)count,...
{
 va_list args;
 va_start(args, count);
 [HttpApiManager callApi:apiName
              withMethod:aMethod
          sendCredential:sendUsernameAndPassword
        responseCallback:callback
         parametersCount:count
              parameters:args];
}

+(void)callApi:(NSString*)apiName responseCallback:(void(^)(id response, NSError *error))callback multipartsCount:(NSInteger)count multiparts:(va_list)valist
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
#ifdef HTTP_API_MANAGER_DEBUG
 NSMutableString* postDataString=[NSMutableString string];
#endif
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
  
  //  value2=(NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
  //                                                                               (CFStringRef)value2,
  //                                                                               NULL,
  //                                                                               (CFStringRef)@"!*'();:@&=+$,/?%#[]",
  //                                                                               kCFStringEncodingUTF8 ));
#ifdef HTTP_API_MANAGER_DEBUG
  [postDataString appendFormat:@"--%@\n",BOUNDARY_TAG];
#endif
  [postData appendData:[[NSString stringWithFormat:@"--%@\r\n",BOUNDARY_TAG] dataUsingEncoding:NSUTF8StringEncoding]];
  if ([value2 isEqualToString:@"value"])
  {
#ifdef HTTP_API_MANAGER_DEBUG
   [postDataString appendFormat:@"Content-Disposition: form-data; name=\"%@\"\n\n",value1];
   [postDataString appendFormat:@"%@",value3];
#endif
   [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n",value1] dataUsingEncoding:NSUTF8StringEncoding]];
   [postData appendData:[[NSString stringWithFormat:@"%@",value3] dataUsingEncoding:NSUTF8StringEncoding]];
  }
  else
  {
   if (fileData!=nil)
   {
#ifdef HTTP_API_MANAGER_DEBUG
    [postDataString appendFormat:@"Content-Disposition: file; filename=\"%@\"\n",value1];
    [postDataString appendFormat:@"Content-Type: %@;\n\n",value2];
    [postDataString appendFormat:@"FILE CONTENT"];
#endif
    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: file; filename=\"%@\"\r\n",value1] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithFormat:@"Content-Type: %@;\r\n\r\n",value2] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:fileData];
   }
  }
#ifdef HTTP_API_MANAGER_DEBUG
  [postDataString appendFormat:@"\n"];
#endif
  [postData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
 }
#ifdef HTTP_API_MANAGER_DEBUG
 [postDataString appendFormat:@"--%@",BOUNDARY_TAG];
#endif
 [postData appendData:[[NSString stringWithFormat:@"--%@",BOUNDARY_TAG] dataUsingEncoding:NSUTF8StringEncoding]];
 
#ifdef HTTP_API_MANAGER_DEBUG
 NSLog(@"---------- Request ----------");
 NSLog(@"%@",urlString);
 NSLog(@"---------- Parameters ----------");
 NSLog(@"%@",postDataString);
#endif
 
 dispatch_async(queue, ^{
  NSMutableURLRequest *request;
  request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
  [request setHTTPMethod:@"POST"];
  [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", BOUNDARY_TAG] forHTTPHeaderField:@"Content-Type"];
  [request setHTTPBody:postData];
  NSError* error=nil;
  NSData *data=[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
  NSString *string=[[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];
  
 #ifdef HTTP_API_MANAGER_DEBUG
  NSLog(@"---------- Response ----------");
  NSLog(@"%@",string);
 #endif
  
  if (error!=nil)
  {
   dispatch_async(dispatch_get_main_queue(), ^{
    callback(nil,error);
   });
   return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
   callback(data,nil);
  });
 });
}

+(void)callApi:(NSString*)apiName responseCallback:(void(^)(id response, NSError *error))callback multiparts:(NSInteger)count,...
{
 va_list args;
 va_start(args, count);
 [HttpApiManager callApi:apiName
        responseCallback:callback
         multipartsCount:count
              multiparts:args];
}

+(void)callApi:(NSString*)apiName withBody:(NSData*)aBody responseCallback:(void(^)(id response, NSError *error))callback {
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
//#ifdef HTTP_API_MANAGER_DEBUG
//  NSLog(@"---------- Request ----------");
//  NSLog(@"%@",urlString);
//  NSLog(@"---------- Parameters ----------");
//  NSLog(@"%@",postDataString);
//#endif
  
  dispatch_async(queue, ^{
    NSMutableURLRequest *request;
    request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:aBody];
    NSError* error=nil;
    NSData *data=[NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
    NSString *string=[[NSString alloc] initWithBytes: [data bytes] length:[data length] encoding: NSUTF8StringEncoding];
    
#ifdef HTTP_API_MANAGER_DEBUG
    NSLog(@"---------- Request ----------");
    NSLog(@"%@",urlString);
    NSLog(@"---------- body ----------");
    NSLog(@"%@",[[NSString alloc] initWithData:aBody encoding:NSUTF8StringEncoding]);
    NSLog(@"---------- Response ----------");
    NSLog(@"%@",string);
#endif
    
    if (error!=nil)
    {
      dispatch_async(dispatch_get_main_queue(), ^{
        callback(nil,error);
      });
      return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      callback(data,nil);
    });
  });
}

@end
