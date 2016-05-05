//
//  Trilateration.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "Trilateration.h"

#import "System.h"

#pragma mark -
#pragma mark Coordinate class

@implementation Coordinate

- (id)initWithX:(double)x y:(double)y z:(double)z {
  self = [super init];
  
  if (self != nil) {
    _x = x;
    _y = y;
    _z = z;
  }
  
  return self;
}

- (double)distanceToCoordinate:(Coordinate *)coordinate {
  double output_d = sqrt(pow(self.x - coordinate.x, 2) + pow(self.y - coordinate.y, 2) + pow(self.z - coordinate.z, 2));
  double rounded = round(output_d * 100.0) / 100.0;
  
  return rounded;
}

@end

#pragma mark -
#pragma mark Candidate class

@interface Candidate : Coordinate

- (id)initWithX:(double)x y:(double)y z:(double)z;
- (id)initWithCoordinate:(Coordinate *)co;

@property(nonatomic, assign) double totalSqErr;
@property(nonatomic, assign) int i1;
@property(nonatomic, assign) int i2;
@property(nonatomic, assign) int i3;

@end

@implementation Candidate

- (id)initWithX:(double)x y:(double)y z:(double)z {
  self = [super initWithX:x y:y z:z];
  
  return self;
}

- (id)initWithCoordinate:(Coordinate *)co {
  self = [super initWithX:co.x y:co.y z:co.z];
  
  return self;
}

@end

#pragma mark -
#pragma mark Candidate class

@interface Entry ()

@property(nonatomic, strong) System *system;
@property(nonatomic, assign) double  correctedDistance;

@end

@implementation Entry

- (id)initWithCoordinate:(Coordinate *)coordinate distance:(double)distance {
  self = [super init];
  
  if (self != nil) {
    _coordinate = coordinate;
    _distance   = distance;
  }
  
  return self;
}

- (id)initWithX:(double)x y:(double)y z:(double)z distance:(double)distance {
  Coordinate *coordinate = [[Coordinate alloc] initWithX:x y:y z:z];
  
  self = [self initWithCoordinate:coordinate distance:distance];
  
  return self;
}

- (id)initWithSystem:(System *)system distance:(double)distance {
  self = [self initWithX:system.x y:system.y z:system.z distance:distance];
  
  if (self != nil) {
    self.system = system;
  }
  
  return self;
}

@end

#pragma mark -
#pragma mark DistanceTest class

@interface DistanceTest : NSObject

@property(nonatomic, assign) double distance;
@property(nonatomic, assign) double error;
@property(nonatomic, assign) int    dp;

@end

@implementation DistanceTest
@end

#pragma mark -
#pragma mark Result class

@implementation Result

- (id)initWithState:(ResultState)state {
  self = [super init];
  
  if (self != nil) {
    _state = state;
  }
  
  return self;
}

- (id)initWithState:(ResultState)state coordinate:(Coordinate *)coordinate {
  self = [self initWithState:state];
  
  if (self != nil) {
    _coordinate = coordinate;
  }
  
  return self;
}

- (id)initWithState:(ResultState)state coordinate:(Coordinate *)coordinate entries:(NSArray <Entry *> *)entries {
  self = [self initWithState:state coordinate:coordinate];
  
  if (self != nil) {
    _entries = entries;
  }
  
  return self;
}

@end

#pragma mark -
#pragma mark Region class

@interface Region : NSObject

- (id)init;
- (id)initWithCenter:(Coordinate *)center;

- (double)volume;
- (BOOL)contains:(Coordinate *)p;
- (Region *)union:(Region *)r;
- (double)centrality:(Coordinate *)p;

@property(nonatomic, assign) int    regionSize;
@property(nonatomic, assign) double minx;
@property(nonatomic, assign) double maxx;
@property(nonatomic, assign) double miny;
@property(nonatomic, assign) double maxy;
@property(nonatomic, assign) double minz;
@property(nonatomic, assign) double maxz;
@property(nonatomic, strong) NSMutableArray <Coordinate *> *origins;

@end

@implementation Region

- (id)init {
  self = [super init];
  
  if (self != nil) {
    self.regionSize = 1;
  }
  
  return self;
}

- (id)initWithCenter:(Coordinate *)center {
  self = [self init];
  
  if (self != nil) {
    self.origins = [[NSMutableArray <Coordinate *> alloc] init];
    
    [self.origins addObject:center];

    self.minx = floor(center.x * 32 - self.regionSize) / 32;
    self.maxx = ceil (center.x * 32 + self.regionSize) / 32;
    self.miny = floor(center.y * 32 - self.regionSize) / 32;
    self.maxy = ceil (center.y * 32 + self.regionSize) / 32;
    self.minz = floor(center.z * 32 - self.regionSize) / 32;
    self.maxz = ceil (center.z * 32 + self.regionSize) / 32;
  }
  
  return self;
}

// number of grid coordinates in the region
// for a region that has not been merged this is typically (2*regionSize)^3 (though if the center
// was grid aligned it will be (2*regionsize-1)^3)
- (double)volume {
  return (32768 * (self.maxx - self.minx + 1 / 32) * (self.maxy - self.miny + 1 / 32) * (self.maxz - self.minz + 1 / 32));
}

// p has properties x, y, z. returns true if p is in this region, false otherwise
- (BOOL)contains:(Coordinate *)p {
  return (p.x >= self.minx && p.x <= self.maxx
          && p.y >= self.miny && p.y <= self.maxy
          && p.z >= self.minz && p.z <= self.maxz);
}

// returns a new region that represents the union of this and r
- (Region *)union:(Region *)r {
  //    if (!(r instanceof Region)) return null;
    
  Region *u = [[Region alloc] init];
    
  u.origins = [[NSMutableArray <Coordinate *> alloc] init];
  
  [u.origins addObjectsFromArray:self.origins];
  [u.origins addObjectsFromArray:r.origins];

  u.minx = MIN(self.minx, r.minx);
  u.miny = MIN(self.miny, r.miny);
  u.minz = MIN(self.minz, r.minz);
  u.maxx = MAX(self.maxx, r.maxx);
  u.maxy = MAX(self.maxy, r.maxy);
  u.maxz = MAX(self.maxz, r.maxz);
    
  return u;
}
  
// returns the highest coordinate of the vector from p to the closest origin point. this is the
// minimum value of region size (in Ly) that would include the specified point
- (double)centrality:(Coordinate *)p {
  double d, best;
  best = 0;
  for (int i = 0; i < self.origins.count; i++)
  {
    d = MAX(
            ABS(self.origins[i].x - p.x),
            MAX(ABS(self.origins[i].y - p.y),
                ABS(self.origins[i].z - p.z))
            );
    if (d < best || best == 0)
      best = d;
  }
  return best;
}
  
@end


#pragma mark -
#pragma mark Trilateration class

@interface Trilateration()

@property(nonatomic, strong) NSMutableArray <Entry      *> *entries;
@property(nonatomic, strong) NSArray        <Region     *> *regions;
@property(nonatomic, assign) int                            bestCount;
@property(nonatomic, assign) int                            nextBest;
@property(nonatomic, strong) NSMutableArray <Coordinate *> *best;
@property(nonatomic, strong) NSMutableArray <Coordinate *> *next;
@end

@implementation Trilateration

//public delegate void Log(string message);
//public Log Logger
//{
//  get { return logger; }
//  set { logger = value; }
//}
//private Log logger = delegate { };

- (id)init {
  self = [super init];
  
  if (self != nil) {
    self.entries = [[NSMutableArray <Entry *> alloc] init];
  }
  
  return self;
}

- (NSArray <Region *> *)getRegions {
  NSMutableArray <Region *> *regions = [[NSMutableArray <Region *> alloc] init];
  
  // find candidate locations by trilateration on all combinations of the input distances
  // expand candidate locations to regions, combining as necessary
  for (int i1 = 0; i1 < self.entries.count; i1++)
  {
    for (int i2 = i1 + 1; i2 < self.entries.count; i2++)
    {
      for (int i3 = i2 + 1; i3 < self.entries.count; i3++)
      {
        NSArray <Candidate *> *candidates = [self getCandidates:self.entries :i1 :i2 :i3];
        
        //candidates.forEach(function(candidate)
        for (Candidate *candidate in candidates) {
          Region *r = [[Region alloc] initWithCenter:candidate];
          // see if there is existing region we can merge this new one into
          for (int j = 0; j < regions.count; j++)
          {
            Region *u = [r union:regions[j]];
            if (u.volume < r.volume + regions[j].volume)
            {
              // volume of union is less than volume of individual regions so merge them
              regions[j] = u;
              // TODO should really rescan regions to see if there are other existing regions that can be merged into this
              r = nil;	// clear r so we know not to add it
              break;
            }
          }
          if (r != nil)
          {
            [regions addObject:r];
          }
        }
      }
    }
  }
  
  //		console.log("Candidate regions:");
  //		$.each(regions, function() {
  //			console.log(this.toString());
  //		});
  return regions;
}

- (int)checkDistances:(Coordinate *)p {
  int count = 0;
  
  for (Entry *entry in self.entries)
  
  //self.distances.forEach(function(dist)
  {
    int dp = 2;
    /*
     if (typeof dist.distance === 'string') {
     // if dist is a string then check if it has exactly 3 decimal places:
     if (dist.distance.indexOf('.') === dist.distance.length-4) dp = 3;
     } else if (dist.distance.toFixed(3) === dist.distance.toString()) {
     // assume it's 3 dp if its 3 dp rounded string matches the string version
     dp = 3;
     }
     */
    
    
    if (entry.distance == [self eddist:p :entry.coordinate :dp])
      count++;
    
  }
  
  return count;
}




- (Result *)runCSharp {
  
  self.regions = [self getRegions];
  // check the number of matching distances for each grid location in each region
  // track the best number of matches (and the corresponding locations) and the next
  // best number
  self.bestCount = 0;
  self.best = [[NSMutableArray <Coordinate *> alloc] init];
  self.nextBest = 0;
  self.next = [[NSMutableArray <Coordinate *> alloc] init];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"regionSize > 0"];
  NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"origins.@count" ascending:NO];
  NSArray <Region *> *sortedregions = [self.regions filteredArrayUsingPredicate:predicate];
  
  sortedregions = [sortedregions sortedArrayUsingDescriptors:@[sortDescriptor]];
  
  for (Region *region in sortedregions)
  {
    //this.regions.forEach(function(region) {
    //bestCount = 0;
    //best = new List<Coordinate>();
    //nextBest = 0;
    //next = new List<Coordinate>();
    
    for (double x = region.minx; x <= region.maxx; x += 1 / 32.0)
    {
      for (double y = region.miny; y <= region.maxy; y += 1 / 32.0)
      {
        for (double z = region.minz; z <= region.maxz; z += 1 / 32.0)
        {
          Coordinate *p = [[Coordinate alloc] initWithX:x y:y z:z];
          int matches = [self checkDistances:p];
          if (matches > self.bestCount)
          {
            self.nextBest = self.bestCount;
            self.next = self.best;
            self.bestCount = matches;
            self.best = [[NSMutableArray <Coordinate *> alloc] init];
            [self.best addObject:p];
            
          }
          else if (matches == self.bestCount)
          {
            [self.best addObject:p];
          }
          else if (matches > self.nextBest)
          {
            self.nextBest = matches;
            self.next = [[NSMutableArray <Coordinate *> alloc] init];
            [self.next addObject:p];
            
          }
          else if (matches == self.nextBest)
          {
            [self.next addObject:p];
          }
          if (matches > self.bestCount)
          {
            self.nextBest = self.bestCount;
            self.next = self.best;
            self.bestCount = matches;
            self.best = [[NSMutableArray <Coordinate *> alloc] init];
            [self.best addObject:p];
          }
          else if (matches == self.bestCount)
          {
            BOOL found = NO;
            for (Coordinate *e in self.best)
            {
              //this.best.forEach(function(e) {
              if (e.x == p.x && e.y == p.y && e.z == p.z)
              {
                found = YES;
                //return false;
                break;
              }
            }
            if (!found) [self.best addObject:p];
          }
          else if (matches > self.nextBest)
          {
            self.nextBest = matches;
            self.next = [[NSMutableArray <Coordinate *> alloc] init];
            [self.next addObject:p];
          }
          else if (matches == self.nextBest)
          {
            BOOL found = NO;
            for (Coordinate *e in self.best)
            {
              if (e.x == p.x && e.y == p.y && e.z == p.z)
              {
                found = YES;
                //return false;
                break;
              }
            }
            if (!found) [self.next addObject:p];
          }
        }
      }
    }
    
    
    //var correctEntriesCount = 0;
    //var correctedEntries = new Dictionary<Entry, double>();
    
    //foreach (var entry in entries)
    //{
    //    var correctedDistance = entry.Coordinate % coordinate;
    //    if (correctedDistance == entry.Distance)
    //    {
    //        correctEntriesCount++;
    //    }
    //    correctedEntries.Add(entry, correctedDistance);
    //}
    
    if (self.bestCount >= 5 && (self.bestCount - self.nextBest) >= 2)
    {
      Result *res = [[Result alloc] initWithState:Exact coordinate:self.best[0] entries:[self calculateCSharpResultEntries:self.entries :self.best[0]]];
      return res;
    }
    else if ((self.bestCount - self.nextBest) >= 1)
    {
      return [[Result alloc] initWithState:NotExact coordinate:self.best[0] entries:[self calculateCSharpResultEntries:self.entries :self.best[0]]];
    }
    else if (self.best != nil && self.best.count > 1)
      return [[Result alloc] initWithState:MultipleSolutions coordinate:self.best[0] entries:[self calculateCSharpResultEntries:self.entries :self.best[0]]]; // Trilatation.best.Count  shows how many solutions
    else
      return [[Result alloc] initWithState:NeedMoreDistances];
    
    
    
  }
  return [[Result alloc] initWithState:NeedMoreDistances];
}

- (NSArray <Entry *> *)calculateCSharpResultEntries:(NSArray <Entry *> *)entries :(Coordinate *)coordinate {
  NSMutableArray <Entry *> *correctedEntries = [[NSMutableArray <Entry *> alloc] init];
  
  for (Entry *entry in entries)
  {
    entry.correctedDistance = [entry.coordinate distanceToCoordinate:coordinate];
    
    [correctedEntries addObject:entry];
  }
  
  return correctedEntries;
}


//  / p1 and p2 are objects that have x, y, and z properties
// returns the difference p1 - p2 as a vector object (with x, y, z properties), calculated as single precision (as ED does)
- (Coordinate *)diff:(Coordinate *)p1 :(Coordinate *)p2 {
  return [[Coordinate alloc] initWithX:(p1.x - p2.x) y:(p1.y - p2.y) z:(p1.z - p2.z)];
}


// p1 and p2 are objects that have x, y, and z properties
// returns the sum p1 + p2 as a vector object (with x, y, z properties)
- (Coordinate *)sum:(Coordinate *)p1 :(Coordinate *)p2 {
  return [[Coordinate alloc] initWithX:(p1.x + p2.x)
                                     y:(p1.y + p2.y)
                                     z:(p1.z + p2.z)];
}


// p1 and p2 are objects that have x, y, and z properties
// returns the distance between p1 and p2
- (double)dist:(Coordinate *)p1 :(Coordinate *)p2 {
  return [self length:[self diff:p2 :p1]];
}

// v is a vector obejct with x, y, and z properties
// returns the length of v
- (double)length:(Coordinate *)v {
  return sqrt([self dotProd:v :v]);
}


// p1 and p2 are objects that have x, y, and z properties
// dp is optional number of decimal places to round to (defaults to 2)
// returns the distance between p1 and p2, calculated as single precision (as ED does),
// rounded to the specified number of decimal places
- (double)eddist:(Coordinate *)p1 :(Coordinate *)p2 :(int)dp {
  //  dp = (typeof dp === 'undefined') ? 2 : dp;
  Coordinate *v = [self diff:p2 :p1];
  float d = [self fround:(sqrt([self fround:([self fround:([self fround:(v.x * v.x)] + [self fround:(v.y * v.y)])] + [self fround:(v.z * v.z)])]))];
  return [self round:d :dp];
}


- (float)fround:(double) d {
  return (float)d;
}

// round to the specified number of decimal places
- (double)round:(double)v :(int)dp {
  return round(v * pow(10, dp)) / pow(10, dp);
}


// p1 and p2 are objects that have x, y, and z properties
// returns the scalar (dot) product p1 . p2
- (double)dotProd:(Coordinate *)p1 :(Coordinate *)p2 {
  return p1.x * p2.x + p1.y * p2.y + p1.z * p2.z;
}

// p1 and p2 are objects that have x, y, and z properties
// returns the vector (cross) product p1 x p2
- (Coordinate *)crossProd:(Coordinate *)p1 :(Coordinate *)p2 {
  return [[Coordinate alloc] initWithX:(p1.y * p2.z - p1.z * p2.y)
                                     y:(p1.z * p2.x - p1.x * p2.z)
                                     z:(p1.x * p2.y - p1.y * p2.x)];
}

// v is a vector obejct with x, y, and z properties
// s is a scalar value
// returns a new vector object containing the scalar product of s and v
- (Coordinate *)scalarProd:(double)s :(Coordinate *)v {
  return [[Coordinate alloc] initWithX:(s * v.x)
                                     y:(s * v.y)
                                     z:(s * v.z)];
}


//// returns a vector with the components of v rounded to 1/32
//private Coordinate gridLocation(Coordinate v)
//{
//  return new Coordinate(
//                        (Math.Round(v.X * 32) / 32),
//                        (Math.Round(v.Y * 32) / 32),
//                        (Math.Round(v.Z * 32) / 32));
//}
//
//
//// dists is an array of reference objects (properties x, y, z, distance)
//// returns an object containing the best candidate found (properties x, y, z, totalSqErr, i1, i2, i3)
//// i1, i2, i3 are the indexes into dists[] that were reference points for the candidate
//// totalSqErr is the total of the squares of the difference between the supplied distance and the calculated distance to each system in dists[]
//private Candidate getBestCandidate(Entry[] dists)
//{
//  int i1 = 0, i2 = 1, i3 = 2, i4;
//  Candidate bestCandidate = null;
//  
//  // run the trilateration for each combination of 3 reference systems in the set of systems we have distance data for
//  // we look for the best candidate over all trilaterations based on the lowest total (squared) error in the calculated
//  // distances to all the reference systems
//  for (i1 = 0; i1 < dists.Length; i1++)
//  {
//    for (i2 = i1 + 1; i2 < dists.Length; i2++)
//    {
//      for (i3 = i2 + 1; i3 < dists.Length; i3++)
//      {
//        var candidates = getCandidates(dists, i1, i2, i3);
//        if (candidates.Length == 2)
//        {
//          candidates[0].totalSqErr = 0;
//          candidates[1].totalSqErr = 0;
//          
//          for (i4 = 0; i4 < dists.Length; i4++)
//          {
//            DistanceTest err = checkDist((Coordinate)candidates[0], dists[i4].Coordinate, dists[i4].Distance);
//            candidates[0].totalSqErr += err.error * err.error;
//            err = checkDist((Coordinate)candidates[1], dists[i4].Coordinate, dists[i4].Distance);
//            candidates[1].totalSqErr += err.error * err.error;
//          }
//          if (bestCandidate == null || bestCandidate.totalSqErr > candidates[0].totalSqErr)
//          {
//            bestCandidate = candidates[0];
//            bestCandidate.i1 = i1;
//            bestCandidate.i2 = i2;
//            bestCandidate.i3 = i3;
//            //console.log("best candidate so far: (1st) "+JSON.stringify(bestCandidate,2));
//          }
//          if (bestCandidate.totalSqErr > candidates[1].totalSqErr)
//          {
//            bestCandidate = candidates[1];
//            bestCandidate.i1 = i1;
//            bestCandidate.i2 = i2;
//            bestCandidate.i3 = i3;
//            //console.log("best candidate so far: (2nd) "+JSON.stringify(bestCandidate,2));
//          }
//        }
//      }
//    }
//  }
//  return bestCandidate;
//}

// dists is an array of reference objects (properties x, y, z, distance)
// i1, i2, i3 indexes of the references to use to calculate the candidates
// returns an array of two points (properties x, y, z). if the supplied reference points are disjoint then an empty array is returned
- (NSArray <Candidate *> *)getCandidates:(NSArray <Entry *> *)dists :(int)i1 :(int)i2 :(int)i3 {
  Coordinate *p1 = dists[i1].coordinate;
  Coordinate *p2 = dists[i2].coordinate;
  Coordinate *p3 = dists[i3].coordinate;
  double distance1 = dists[i1].distance;
  double distance2 = dists[i2].distance;
  double distance3 = dists[i3].distance;
  
  Coordinate *p1p2 = [self diff:p2 :p1];
  double d = [self length:p1p2];
  Coordinate *ex = [self scalarProd:(1 / d) :p1p2];
  Coordinate *p1p3 = [self diff:p3 :p1];
  double i = [self dotProd:ex :p1p3];
  Coordinate *ey = [self diff:p1p3 :[self scalarProd:i :ex]];
  ey = [self scalarProd:(1 / [self length:ey]) :ey];
  double j = [self dotProd:ey :[self diff:p3 :p1]];
  
  double x = (distance1 * distance1 - distance2 * distance2 + d * d) / (2 * d);
  double y = ((distance1 * distance1 - distance3 * distance3 + i * i + j * j) / (2 * j)) - (i * x / j);
  double zsq = distance1 * distance1 - x * x - y * y;
  if (zsq < 0)
  {
    //console.log("inconsistent distances (z^2 = "+zsq+")");
    return @[];
  }
  else
  {
    double z = sqrt(zsq);
    Coordinate *ez = [self crossProd:ex :ey];
    Coordinate *coord1 = [self sum:[self sum:p1 :[self scalarProd:x :ex]] :[self scalarProd:y :ey]];
    Coordinate *coord2 = [self diff:coord1 :[self scalarProd:z :ez]];
    coord1 = [self sum:coord1 :[self scalarProd:z :ez]];
    
    return @[[[Candidate alloc] initWithCoordinate:coord1],
             [[Candidate alloc] initWithCoordinate:coord2]];
  }
}

//// calculates the distance between p1 and p2 and then calculates the error between the calculated distance and the supplied distance.
//// if dist has 3dp of precision then the calculated distance is also calculated with 3dp, otherwise 2dp are assumed
//// returns and object with properties (distance, error, dp)
//private DistanceTest checkDist(Coordinate p1, Coordinate p2, double dist)
//{
//  DistanceTest ret = new DistanceTest();
//  
//  ret.dp = 2;
//  
//  /*
//   if (dist.toFixed(3) === dist.toString()) {
//   // assume it's 3 dp if its 3 dp rounded string matches the string version
//   ret.dp = 3;
//   }*/
//  
//  ret.distance = eddist(p1, p2, ret.dp);
//  ret.error = Math.Abs(ret.distance - dist);
//  return ret;
//}
//
//
//public void AddEntry(Entry distance)
//{
//  entries.Add(distance);
//}
//
//public void AddEntry(double x, double y, double z, double distance)
//{
//  AddEntry(new Entry(new Coordinate(x, y, z), distance));
//}

/// <summary>
/// Executes trilateration based on given distances.
/// </summary>
/// <returns>Result information, including coordinate and corrected Entry distances if found.</returns>
- (Result *)run:(Algorithm)algorithm {
  return [self runCSharp];
}



//public class CalculationErrorException : Exception { }


@end
