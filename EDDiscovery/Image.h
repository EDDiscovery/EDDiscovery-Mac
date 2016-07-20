//
//  Image.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Quartz/Quartz.h>

@class Commander;
@class System;
@class Jump;

NS_ASSUME_NONNULL_BEGIN

#define IMG_VOID_PREDICATE       [NSPredicate predicateWithFormat:@"jump.edsm == nil && jump.edsm != nil"]
#define IMG_CMDR_PREDICATE       [NSPredicate predicateWithFormat:@"jump.edsm.commander.name == %@ OR jump.netLogFile.commander.name == %@", commander.name, commander.name]
#define IMG_CMDR_PREDICATE_THUMB [NSPredicate predicateWithFormat:@"thumbnail != nil AND (jump.edsm.commander.name == %@ OR jump.netLogFile.commander.name == %@)", commander.name, commander.name]

@interface Image : NSManagedObject <QLPreviewItem>

+ (NSArray *)screenshotsForCommander:(Commander *)commander;
+ (Image *)imageWithPath:(NSString *)path inContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "Image+CoreDataProperties.h"
