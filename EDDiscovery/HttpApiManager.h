//
//  HttpApiManager.h
//  EDDiscovery
//
//  Created by Luca Giacometti on 17/04/16.
//  Copyright © 2016 Luca Giacometti. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef DEBUG
#define HTTP_API_MANAGER_DEBUG
#endif

#define BOUNDARY_TAG (@"WebKitFormBoundaryHttpApiManager")

@interface HttpApiManager : NSObject

+(void)setBaseUrl:(NSString*)aBaseUrl;

+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent withBody:(NSData*)aBody progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback;
+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent withMethod:(NSString*)aMethod progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback parameters:(NSInteger)count,...;
+(void)callApi:(NSString*)apiName concurrent:(BOOL)concurrent progressCallBack:(ProgressBlock)progressCallback responseCallback:(void(^)(id response, NSError *error))responseCallback multiparts:(NSInteger)count,...;

@end
