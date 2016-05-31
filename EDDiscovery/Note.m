//
//  Note.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 30/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "Note.h"
#import "EDSM.h"
#import "System.h"
#import "Commander.h"

@implementation Note

// Insert code here to add functionality to your managed object subclass

+ (Note *)noteForSystem:(System *)system commander:(Commander *)commander {
  NSAssert([system.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  NSAssert([commander.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  
  NSManagedObjectContext *context = commander.managedObjectContext;
  __block Note           *note    = nil;
  
  [MAIN_CONTEXT performBlockAndWait:^{
    NSString             *className = NSStringFromClass([Note class]);
    NSFetchRequest       *request   = [[NSFetchRequest alloc] init];
    NSEntityDescription  *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSError              *error     = nil;
    NSArray              *array     = nil;
    
    request.entity                 = entity;
    request.predicate              = [NSPredicate predicateWithFormat:@"system == %@ && edsm.commander == %@", system, commander];
    request.returnsObjectsAsFaults = NO;
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
    NSAssert1(array.count <= 1, @"Expected max 1 note per system per commander, got %ld instead", (long)array.count);
    
    note = array.firstObject;
  }];
  
  return note;
}

@end
