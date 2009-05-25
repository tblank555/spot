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

@implementation SpotAlbum

@synthesize browsing;

-(id)initWithAlbum:(struct album*)album_;
{
	if( ! [super init] ) return nil;
	
  browsing = NO;
	memcpy(&album, album_, sizeof(struct album));
  tracks = nil;
  return self;
}

-(id)initWithAlbumBrowse:(struct album_browse*)album_;
{
  if( ! [super init] ) return nil;
  
  browsing = YES;
	memcpy(&albumBrowse, album_, sizeof(struct album_browse));
  
  
  strcpy(album.name, albumBrowse.name);
  strcpy(album.id, albumBrowse.id);
  strcpy(album.cover_id, albumBrowse.cover_id);
  album.popularity = albumBrowse.popularity;
  
  SpotMutablePlaylist *a_playlist = [[SpotMutablePlaylist alloc] init];
  NSMutableArray *a_tracks = [[NSMutableArray alloc] initWithCapacity:albumBrowse.num_tracks];
  if(albumBrowse.num_tracks > 0){
    for(struct track *track = albumBrowse.tracks; track != NULL; track = track->next){
      SpotTrack *strack = [[[SpotTrack alloc] initWithTrack:track] autorelease];
      [a_playlist addTrack:strack];
      [a_tracks addObject:strack];
    }
  }
  playlist = a_playlist;
  tracks = a_tracks;
	
	return self;
}

-(SpotAlbum *)moreInfo;
{
  if(browsing) return nil;
  return [[SpotSession defaultSession] albumById:self.id];
}

#pragma mark shared
-(SpotId *)id; { return [SpotId albumId:album.id]; }
-(NSString *)name; { return [NSString stringWithCString:album.name]; }
-(SpotId *)coverId; { return [SpotId coverId:album.cover_id]; }
-(float) popularity; { return album.popularity; }

#pragma mark artist only  
-(NSString *)artistName; { return browsing ? nil : [NSString stringWithCString:album.artist]; }
-(SpotId *)artistId; { return browsing ? nil : [SpotId artistId:album.artist_id]; }
  
#pragma mark browsing only
-(int) year; { return browsing ? albumBrowse.year : 0; }
-(NSArray *)tracks; { return tracks; } 


@end
