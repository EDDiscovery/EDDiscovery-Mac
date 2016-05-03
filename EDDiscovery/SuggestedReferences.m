//
//  SuggestedReferences.m
//  EDDiscovery
//
//  Created by thorin on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "SuggestedReferences.h"

#import "System.h"
#import "ReferencesSector.h"
#import "CoreDataManager.h"
#import "ReferenceSystem.h"

@implementation SuggestedReferences {
  System  *lastKnownPosition;
  NSMutableArray *sectors;
  int sections;
}

- (id)initWithLastKnownPosition:(System *)system {
  self = [super init];
  
  if (self != nil) {
    lastKnownPosition = system;
    
    sections = 12;
    
    NSTimeInterval ti = [NSDate timeIntervalSinceReferenceDate];
    
    [self createSectors];
    [self addSystemsToSectors];
    
    NSLog(@"FindCandidates time %.000f", [NSDate timeIntervalSinceReferenceDate] - ti);
  }
  
  return self;
}

- (void)createSectors {
  sectors = [[NSMutableArray alloc] initWithCapacity:sections];
  
  for (int i=0; i<sections; i++) {
    sectors[i] = [[NSMutableArray alloc] initWithCapacity:sections];
  }
  
  for (int az = -180, aznr =0; az<180; az += 360/sections, aznr++)
  {
    for (int alt = -90, altnr =0 ; alt < 90; alt += 360 / sections, altnr++)
    {
      ReferencesSector *sector = [[ReferencesSector alloc] initWithAzimuth:az altitude:alt width:360 / sections];
      sectors[aznr][altnr] = sector;
    }
  }
}


- (void)addSystemsToSectors {
  int aznr, altnr;
  
  NSArray *globalSystems = [System allSystems];
  
  for (System *sys in globalSystems) {
    if (sys.hasCoordinates) {
      ReferenceSystem *refSys = [[ReferenceSystem alloc] initWithReferenceSystem:sys estimatedPosition:lastKnownPosition];
      
      if (refSys.distance > 0.0) // Exlude own position
      {
        aznr = (int)floor((refSys.azimuth * 180 / M_PI + 180) / (360.0 / sections));
        altnr = (int)floor((refSys.altitude * 180 / M_PI) / (360.0 / sections));
        
        [sectors[aznr%sections][altnr%(sections/2)] addCandidate:refSys];
      }
    }
  }
}


- (ReferenceSystem *)getCandidate {
  double maxdistance = 0;
  ReferencesSector *sectorcandidate = nil;
  
  // Get Sector with maximum distance for all others...
  for (int i = 0; i < sections; i++)
    for (int j = 0; j < sections / 2; j++)
    {
      if ([sectors[i][j] referencesCount] == 0 && [sectors[i][j] candidatesCount] > 0)  // An unused sector with candidates left?
      {
        double dist;
        double mindist = 10;
        
        for (int ii = 0; ii < sections; ii++)
          for (int jj = 0; jj < sections / 2; jj++)
          {
            if ([sectors[ii][jj] candidatesCount] > 0)
            {
              dist = [self calculateAngularDistance:[sectors[i][j] azimuthCenterRad] :[sectors[i][j] latitudeCenterRad] :[sectors[ii][jj] azimuthCenterRad] :[sectors[ii][jj] latitudeCenterRad]];
              
              if (dist > 0.001)
              {
                if (dist < mindist)
                  mindist = dist;
              }
            }
          }
        
        
        if (mindist > maxdistance)  // New candidate
        {
          maxdistance = mindist;
          sectorcandidate = sectors[i][j];
        }
        
      }
    }
  
  if (sectorcandidate == nil)
  {
    if (self.nrOfRefenreceSystems == 0)
    {
      System *sys = [System systemWithName:@"Sol"];
      
      if (lastKnownPosition.x == 0 && lastKnownPosition.y == 0 && lastKnownPosition.z == 0)
        sys = [System systemWithName:@"Sirius"];
      
      if (sys == nil)
        return nil;   // Should not happend
      
      ReferenceSystem *refSys = [[ReferenceSystem alloc] initWithReferenceSystem:sys estimatedPosition:lastKnownPosition];
      
      return refSys;
    }
    
    return nil;
  }
  
  return [sectorcandidate getBestCandidate];
}

- (void)addReferenceStar:(System *)sys {
  ReferenceSystem *refSys = [[ReferenceSystem alloc] initWithReferenceSystem:sys estimatedPosition:lastKnownPosition];
  
  if (self.nrOfRefenreceSystems== 0 || refSys.distance > 0.0) // Exlude own position
  {
    int aznr = (int)floor((refSys.azimuth * 180 / M_PI + 180) / (360.0 / sections));
    int altnr = (int)floor((refSys.altitude * 180 / M_PI) / (360.0 / sections));
    
    [sectors[aznr % sections][altnr % (sections / 2)] addReference:refSys];
  }
  
}

- (int)nrOfRefenreceSystems {
  int nr = 0;
  for (int i = 0; i < sections; i++)
    for (int j = 0; j < sections / 2; j++)
      nr += [sectors[i][j] referencesCount];
  
  return nr;
}



/// <summary>
/// Calculate angular distance between 2 sperical points
/// </summary>
/// <param name="longitude1Rad">Point 1 longitude in radians</param>
/// <param name="latitude1Rad">Point 1 latitude in radians</param>
/// <param name="longitude2Rad">Point 2 longitude in radians</param>
/// <param name="latitude2Rad">Point 2 latitude in radians</param>
/// <returns></returns>
- (double)calculateAngularDistance:(double)longitude1Rad :(double)latitude1Rad :(double)longitude2Rad :(double)latitude2Rad {
  double logitudeDiff = ABS(longitude1Rad - longitude2Rad);
  
  if (logitudeDiff > M_PI)
    logitudeDiff = 2.0 * M_PI - logitudeDiff;
  
  double angleCalculation = acos( sin(latitude1Rad) * sin(latitude2Rad) +  cos(latitude1Rad) * cos(latitude2Rad) * cos(logitudeDiff));
  return angleCalculation;
}

@end
