//
//  SpotAlbum.m
//  Spot
//
//  Created by Joachim Bengtsson on 2009-05-24.
//  Copyright 2009 Third Cog Software. All rights reserved.
//

#import "SpotAlbum.h"
#import "SpotTrack.h"
#import "SpotSession.h"
#import "SpotURI.h"

@implementation SpotAlbum

@synthesize browsing;
@synthesize version, name, artistName, artistId, type, year, coverId, review, copyright, catalogues, similarAlbumIds, discs, popularity;

-(id)initWithAlbum:(struct album*)album;
{
	if( ! [super init] ) return nil;
	
  browsing = NO;

  name = [[NSString alloc] initWithUTF8String:album->name];
  albumId = [[NSString alloc] initWithUTF8String:album->id];
  artistName = [[NSString alloc] initWithUTF8String:album->artist];
  artistId = [[NSString alloc] initWithUTF8String:album->artist_id];
  coverId  = [[NSString alloc] initWithUTF8String:album->cover_id];
  popularity = album->popularity;
  
  if(album->has_forbidden){
    NSString *forbiddenString = [NSString stringWithUTF8String:album->forbidden];
    forbiddenCountries = [[forbiddenString componentsSeparatedByString:@" "] retain];
  }
  
  if(album->has_allowed){
    NSString *allowedString = [NSString stringWithUTF8String:album->allowed];
    allowedCountries = [[allowedString componentsSeparatedByString:@" "] retain];
  }
  
  return self;
}

-(void)loadBrowse:(struct album_browse*)album;
{
  browsing = YES;
  
  name = [[NSString alloc] initWithUTF8String:album->name];
  albumId = [[NSString alloc] initWithUTF8String:album->id];
  year = album->year;
  type = [[NSString alloc] initWithUTF8String:album->type];
  coverId = [[NSString alloc] initWithUTF8String:album->cover_id];
  popularity = album->popularity;
  artistName = [[NSString alloc] initWithUTF8String:album->artist];
  artistId = [[NSString alloc] initWithUTF8String:album->artist_id];
  if(album->review)
    review = [[NSString alloc] initWithUTF8String:album->review];
  
  if(album->has_forbidden){
    NSString *forbiddenString = [NSString stringWithUTF8String:album->forbidden];
    forbiddenCountries = [[forbiddenString componentsSeparatedByString:@" "] retain];
  }
  
  if(album->has_allowed){
    NSString *allowedString = [NSString stringWithUTF8String:album->allowed];
    allowedCountries = [[allowedString componentsSeparatedByString:@" "] retain];
  }

  
  //TODO: multiple discs when despotify has support for it
  NSMutableArray *tracks = [NSMutableArray array];
  for(struct track *track = album->tracks; track != NULL; track = track->next){
    SpotTrack *a_track = [[SpotTrack alloc] initWithTrack:track];
    [tracks addObject:a_track];
    [a_track release];
  }
  SpotPlaylist *disc = [[SpotPlaylist alloc] initWithName:name author:nil tracks:tracks];
  discs = [[NSArray alloc] initWithObjects:disc, nil];
  [disc release];
}


-(id)initWithAlbumBrowse:(struct album_browse*)album;
{
  if( ! [super init] ) return nil;
  
  [self loadBrowse:album];
  
  return self;
}

-(void)dealloc;
{
  [albumId release];
  [name release];
  [artistName release];
  [artistId release];
  [type release];
  [allowedCountries release];
  [forbiddenCountries release];
  [coverId release];
  [review release];
  [copyright release];
  [catalogues release];
  [similarAlbumIds release];
  [discs release];
  [playlist dealloc];
  [artist release];
  [super dealloc];
}


-(id)initWithCoder:(NSCoder *)decoder;
{
  [super initWithCoder:decoder];
  browsing = [decoder decodeBoolForKey:@"SAbrowsing"];
  name = [[decoder decodeObjectForKey:@"SAname"] retain];
  albumId = [[decoder decodeObjectForKey:@"SAalbumId"] retain];
  year = [decoder decodeIntForKey:@"SAyear"];
  type = [decoder decodeObjectForKey:@"SAtype"];
  allowedCountries = [decoder decodeObjectForKey:@"SAallowedCountries"];
  forbiddenCountries = [decoder decodeObjectForKey:@"SAforbiddenCountries"];
  coverId = [[decoder decodeObjectForKey:@"SAcoverId"] retain];
  popularity = [decoder decodeFloatForKey:@"SApopularity"];
  artistName = [[decoder decodeObjectForKey:@"SAartistName"] retain];
  artistId = [[decoder decodeObjectForKey:@"SAartistId"] retain];
  review = [[decoder decodeObjectForKey:@"SAreview"] retain];
  discs = [[decoder decodeObjectForKey:@"SAdiscs"] retain];
  return self;
}

-(void)encodeWithCoder:(NSCoder *)encoder;
{
  [super encodeWithCoder:encoder];
  [encoder encodeBool:browsing forKey:@"SAbrowsing"];
  [encoder encodeObject:name forKey:@"SAname"];
  [encoder encodeObject:albumId forKey:@"SAalbumId"];
  [encoder encodeInt:year forKey:@"SAyear"];
  [encoder encodeObject:type forKey:@"SAtype"];
  [encoder encodeObject:allowedCountries forKey:@"SAallowedCountries"];
  [encoder encodeObject:forbiddenCountries forKey:@"SAforbiddenCountries"];
  [encoder encodeObject:coverId forKey:@"SAcoverId"];
  [encoder encodeFloat:popularity forKey:@"SApopularity"];
  [encoder encodeObject:artistName forKey:@"SAartistName"];
  [encoder encodeObject:artistId forKey:@"SAartistId"];
  [encoder encodeObject:review forKey:@"SAreview"];
  [encoder encodeObject:discs forKey:@"SAdiscs"];
}

-(NSComparisonResult)compare:(SpotAlbum*)other;
{
  return [self.name compare:other.name];
}

#pragma mark shared
-(NSString *)id; { return albumId; }
-(SpotURI*)uri;
{
//  char uri[50];
//  return [SpotURI uriWithURI:despotify_album_to_uri(&albumBrowse, uri)];  
  return nil;
}


-(SpotPlaylist*)playlist;
{
  return [discs lastObject];
}

-(SpotArtist *)artist;
{
  if(!artist)
    artist = [[[SpotSession defaultSession] artistById:artistId] retain];
  return artist;
}

-(BOOL)isEqual:(SpotAlbum*)other;
{
  return [self hash] == [other hash];
}

-(NSUInteger)hash;
{
  return [self.artistId hash];
}

-(BOOL)allowed;
{
  NSString *myCountry = [[SpotSession defaultSession] country];
  if(forbiddenCountries && [forbiddenCountries containsObject:myCountry]) return NO;
  if(allowedCountries && ![allowedCountries containsObject:myCountry]) return NO;
  return YES;
}

@end
