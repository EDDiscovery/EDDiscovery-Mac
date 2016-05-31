//
//  Note.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 30/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class EDSM, System, Commander;

NS_ASSUME_NONNULL_BEGIN

@interface Note : NSManagedObject

+ (Note *)noteForSystem:(System *)system commander:(Commander *)commander;

@end

NS_ASSUME_NONNULL_END

#import "Note+CoreDataProperties.h"
