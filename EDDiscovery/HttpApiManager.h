//
//  JsonApiManager.h
//  EasyGroups
//
//  Created by WorkLuca on 02/02/15.
//  Copyright 2010 Zirak. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SSKeychain.h"

#define HTTP_API_MANAGER_DEBUG

#define HTTP_API_MANAGER_IDENTIFIER (@"HttpApiManager")

#define HTTP_API_MANAGER_SERVICE_KEY ((__bridge id)(kSecAttrService))
#define HTTP_API_MANAGER_EMAIL_KEY ((__bridge id)kSecAttrAccount)
#define HTTP_API_MANAGER_PASSWORD_KEY ((__bridge id)kSecValueData)

#define BOUNDARY_TAG (@"WebKitFormBoundaryHttpApiManager")

@interface HttpApiManager : NSObject
{
}

+(void)setBaseUrl:(NSString*)aBaseUrl andKeychainPrefix:(NSString*)aKeychainPrefix;

+(void)callApi:(NSString*)apiName withBody:(NSData*)aBody responseCallback:(void(^)(id response, NSError *error))callback;
+(void)callApi:(NSString*)apiName withMethod:(NSString*)aMethod responseCallback:(void(^)(id response, NSError *error))callback parameters:(NSInteger)count,...;
+(void)callApi:(NSString*)apiName responseCallback:(void(^)(id response, NSError *error))callback multiparts:(NSInteger)count,...;


@end
