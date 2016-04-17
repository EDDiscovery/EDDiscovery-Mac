//
//  JsonApiManager.h
//  EasyGroups
//
//  Created by WorkLuca on 02/02/15.
//  Copyright 2010 Zirak. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KeychainItemWrapper.h"

#define HTTP_API_MANAGER_DEBUG

#define HTTP_API_MANAGER_IDENTIFIER (@"HttpApiManager")

#define HTTP_API_MANAGER_SERVICE_KEY ((__bridge id)(kSecAttrService))
#define HTTP_API_MANAGER_EMAIL_KEY ((__bridge id)kSecAttrAccount)
#define HTTP_API_MANAGER_PASSWORD_KEY ((__bridge id)kSecValueData)

#define BOUNDARY_TAG (@"WebKitFormBoundaryHttpApiManager")

@interface HttpApiManager : NSObject
{
}

+(NSString*)email;
+(NSString*)password;
+(void)setBaseUrl:(NSString*)aBaseUrl andKeychainPrefix:(NSString*)aKeychainPrefix;
+(void)setEmail:(NSString*)newEmail andPassword:(NSString*)newPassword;
+(BOOL)loadCredential;
+(void)saveCredential;
+(void)resetCredential;
+(void)willCallApi;
+(void)didCallApi;
// Usage
// dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
//  NSString* result=[JsonApiManager callApi:....];
//  dispatch_async(dispatch_get_main_queue(), ^(void){
//   NSLog(@"%@",result);
//  });
// });
+(void)callApi:(NSString*)apiName withMethod:(NSString*)aMethod sendCredential:(BOOL)isLogin responseCallback:(void(^)(id response, NSError *error))callback parametersCount:(NSInteger)count parameters:(va_list)valist;
+(void)callApi:(NSString*)apiName withMethod:(NSString*)aMethod sendCredential:(BOOL)isLogin responseCallback:(void(^)(id response, NSError *error))callback parameters:(NSInteger)count,...;
+(void)callApi:(NSString*)apiName responseCallback:(void(^)(id response, NSError *error))callback multipartsCount:(NSInteger)count multiparts:(va_list)valist;
+(void)callApi:(NSString*)apiName responseCallback:(void(^)(id response, NSError *error))callback multiparts:(NSInteger)count,...;

@end
