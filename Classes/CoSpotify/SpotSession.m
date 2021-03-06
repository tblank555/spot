//
//  SpotSession.m
//  Spot
//
//  Created by Joachim Bengtsson on 2009-05-16.
//  Copyright 2009 Third Cog Software. All rights reserved.
//

#import "SpotSession.h"
#import "SpotPlaylist.h"
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <wchar.h>

#import "SpotCache.h"
#import "SpotItem.h"
#import "SpotArtist.h"
#import "SpotAlbum.h"
#import "SpotTrack.h"
#import "SpotSearch.h"
#import "SpotImage.h"

#import <UIKit/UIKit.h>

SpotSession *SpotSessionSingleton;

NSString *SpotSessionErrorDomain = @"SpotSessionErrorDomain";


///Holds some stuff we need to know where to call back on async fetches
@interface SpotSessionFetchJob : NSObject
{
  NSString *fetchId;
  id target;
  SEL selector;
}

-(id)initWithId:(NSString*)id target:(id)t selector:(SEL)s;
@property (nonatomic, readonly) NSString *fetchId;
@property (nonatomic, readonly) id target;
@property (nonatomic, readonly) SEL selector;

@end

@implementation SpotSessionFetchJob
@synthesize fetchId, target, selector;

-(id)initWithId:(NSString*)id_ target:(id)t selector:(SEL)s;
{
  if(![super init])return nil;
  
  fetchId = id_;
  target = t;
  selector = s;
  
  return self;
}

@end

#pragma mark callback receivers

void cb_client_callback(int type, void*data){
  NSLog(@"client callback %d", type);
//  SpotSession *ss = [SpotSession defaultSession];
  switch(type){
    case DESPOTIFY_TRACK_START:
        //[ss.player performSelectorOnMainThread:@selector(trackDidStart) withObject:nil waitUntilDone:NO];
      break;
    case DESPOTIFY_TRACK_CHANGE:
    case DESPOTIFY_TRACK_END:
        //[ss.player performSelectorOnMainThread:@selector(trackDidEnd) withObject:nil waitUntilDone:NO];
      break;
  }
}


@interface SpotPlayer (ForSessionOnly)
-(void)trackDidStart;
-(void)trackDidEnd;
@end


@interface SpotSession ()
@property (nonatomic, readwrite) BOOL loggedIn;
-(void)receivedXML:(NSString*)xmlString;

-(void)startThread;
-(void)stopThread;
@end


@implementation SpotSession
@synthesize loggedIn, session, player;

-(NSString*)pathForFile:(NSString *)f;
{
  NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  return [docsPath stringByAppendingPathComponent:f];
}

+(SpotSession*)defaultSession;
{
	if(!SpotSessionSingleton)
		SpotSessionSingleton = [[SpotSession alloc] init];
	
	return SpotSessionSingleton;
}

-(id)init;
{
	if( ! [super init] ) return nil;
  
  //This is just to try to wake up the network
  [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.google.com"]];

	
	if(!despotify_init()) {
		NSLog(@"Init failed");
		[self release];
		return nil;
	}
	
	session = despotify_init_client(cb_client_callback);
	if( !session) {
		NSLog(@"Init client failed");
		[self release];
		return nil;
	}
  
  player = [[SpotPlayer alloc] initWithSession:self];
	
	self.loggedIn = NO;
  
  cache = [[SpotCache alloc] init];
  networkLock = [[NSLock alloc] init];
  [self startThread];
    
  //load stored playlists
  playlists = [NSKeyedUnarchiver unarchiveObjectWithFile:[self pathForFile:@"playlist"]];
  NSLog(@"got %@ %@", [playlists class], playlists);
  if([playlists isKindOfClass:[NSArray class]]){
    playlists = [[playlists mutableCopy] retain];
  } else {
    NSLog(@"playlists file is not a list! Recreating");
    playlists = [[NSMutableArray alloc] init];
    [NSKeyedArchiver archiveRootObject:playlists toFile:[self pathForFile:@"playlist"]];
  }
	return self;
}

-(void)dealloc;
{
  [self stopThread];
	NSLog(@"Logged out");
  [player release];
  [playlists release];
  [cache release];
	despotify_exit(session);
	despotify_cleanup();
  [networkLock release];
	[super dealloc];
}

-(void)cleanup;
{
	[self release];
	SpotSessionSingleton = nil;
}

-(BOOL)authenticate:(NSString *)user password:(NSString*)password error:(NSError**)error;
{
  [networkLock lock];
	BOOL success = despotify_authenticate(session, [user UTF8String], [password UTF8String]);
  [networkLock unlock];
	if(!success && error)
		*error = [NSError errorWithDomain:SpotSessionErrorDomain code:SpotSessionErrorCodeDefault userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%s", despotify_get_error(session)] forKey:NSLocalizedDescriptionKey]];
	usleep(500000); // This is what you get with an API without callbacks ;(
	if(success) {
		NSLog(@"Successfully logged in as %@", user);
	}
	self.loggedIn = success;
	
	[self performSelector:@selector(checkPremium) withObject:nil afterDelay:1.0];
  
	return success;
}
-(void)checkPremium;
{
	if(self.loggedIn && ![self.accountType isEqual:@"premium"]){
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Account" message:[NSString stringWithFormat:@"You need a Premium account to use Spot. (You have %@)\nPlease visit spotify.com and upgrade.", self.accountType] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
  }
	
}

-(void)receivedXML:(NSString*)xmlString;
{
//  NSLog(@"Got some XML:\n%@", xmlString);
 
}

-(NSArray*)playlists;
{
  
//	NSMutableArray *playlists = [NSMutableArray array];
	return playlists; // until they fix their playlist servers
	
  [networkLock lock];
	struct playlist *rootlist = despotify_get_stored_playlists(session);
  [networkLock unlock];
  NSLog(@"got lists");
	for(struct playlist *pl = rootlist; pl; pl = pl->next) {
		SpotPlaylist *playlist = [[[SpotPlaylist alloc] initWithPlaylist:pl] autorelease];
		[playlists addObject:playlist];
	}
	despotify_free_playlist(rootlist);

	return playlists;
}


-(NSString*)username;
{
	return [NSString stringWithUTF8String:session->user_info->username];	
}
-(NSString*)country;
{
	return [NSString stringWithUTF8String:session->user_info->country];
}
-(NSString*)accountType;
{
	return [NSString stringWithUTF8String:session->user_info->type];
}
-(NSDate*)expires;
{
	return [NSDate dateWithTimeIntervalSince1970:session->user_info->expiry];
}
-(NSString*)serverHost;
{
	return [NSString stringWithUTF8String:session->user_info->server_host];
}
-(NSUInteger)serverPort;
{
	return session->user_info->server_port;
}
-(NSDate*)lastPing;
{
	return [NSDate dateWithTimeIntervalSince1970:session->user_info->last_ping];
}

#pragma mark Get by id functions

-(SpotArtist *)artistById:(NSString *)id_;
{
  SpotItem *item = [cache itemById:id_];
  if(item) return (SpotArtist*)item;
    
  [networkLock lock];
  struct artist_browse *ab = despotify_get_artist(session, (char*)[id_ cStringUsingEncoding:NSASCIIStringEncoding]);
  [networkLock unlock];
  if(!ab) return nil;
  
  SpotArtist *artist = [[[SpotArtist alloc] initWithArtistBrowse:ab] autorelease];
  [cache addItem:artist];

  return artist;
}

-(void)doAsyncImageById:(SpotSessionFetchJob*)job;
{
  int len = 0;
  [networkLock lock];
  void *jpegdata = despotify_get_image(session, (char*)[job.fetchId cStringUsingEncoding:NSASCIIStringEncoding], &len);
  [networkLock unlock];
  if(len > 0){
    SpotImage *image = [[SpotImage alloc] initWithImageData:[NSData dataWithBytes:jpegdata length:len] id:job.fetchId];
    free(jpegdata);
    [cache addItem:image];
    [job.target performSelectorOnMainThread:job.selector withObject:image waitUntilDone:NO];
  }
}

-(void)asyncImageById:(NSString *)id_ respondTo:(id)target selector:(SEL)selector;
{
  SpotItem *item = [cache itemById:id_];
  if(item)
    //no need to fetch, call target asap
    [target performSelector:selector withObject:item];
  else
    [self performSelector:@selector(doAsyncImageById:) onThread:thread withObject:[[[SpotSessionFetchJob alloc] autorelease] initWithId:id_ target:target selector:selector] waitUntilDone:NO];
}

-(SpotImage *)imageById:(NSString*)id_;
{
  SpotItem *item = [cache itemById:id_];
  if(item) return (SpotImage*)item;
  
  int len = 0;
  [networkLock lock];
  void *jpegdata = despotify_get_image(session, (char*)[id_ cStringUsingEncoding:NSASCIIStringEncoding], &len);
  [networkLock unlock];
  if(len > 0){
    SpotImage *image = [[SpotImage alloc] initWithImageData:[NSData dataWithBytes:jpegdata length:len] id:id_];
    free(jpegdata);
    [cache addItem:image];
    return [image autorelease];
  } 
  return nil;
}

-(SpotAlbum *)albumById:(NSString *)id_;
{
  SpotItem *item = [cache itemById:id_];
  if(item) return (SpotAlbum*)item;
  
  [networkLock lock];
  struct album_browse *ab = despotify_get_album(session, (char*)[id_ cStringUsingEncoding:NSASCIIStringEncoding]);
  [networkLock unlock];
  if(!ab) return nil;
  
  SpotAlbum *album = [[[SpotAlbum alloc] initWithAlbumBrowse:ab] autorelease];
  [cache addItem:album];
  
  return album;
}

-(SpotTrack *)trackById:(NSString *)id_;
{
  SpotItem *item = [cache itemById:id_];
  if(item) return (SpotTrack*)item;
  
  [networkLock lock];
  struct track *track = despotify_get_track(session, (char*)[id_ cStringUsingEncoding:NSASCIIStringEncoding]);
  [networkLock unlock];
  if(!track) return nil;
  
  SpotTrack *the_track = [[(SpotTrack*)[SpotTrack alloc] initWithTrack:track] autorelease];
  [cache addItem:the_track];
  
  return the_track;
}


-(SpotPlaylist *)playlistById:(NSString *)id_;
{
  SpotItem *item = [cache itemById:id_];
  if(item) return (SpotPlaylist*)item;

  [networkLock lock];
  struct playlist *pl = despotify_get_playlist(session, (char*)[id_ cStringUsingEncoding:NSASCIIStringEncoding]);
  [networkLock unlock];
  SpotPlaylist *list = [[[SpotPlaylist alloc] initWithPlaylist:pl] autorelease];
  
  [cache addItem:list];
  return list;
}

#pragma mark Get by uri
//TODO: support cacheing for uris
-(SpotAlbum*)albumByURI:(SpotURI*)uri;
{
  [networkLock lock];
  struct album_browse* ab = despotify_link_get_album(session, uri.link);
  [networkLock unlock];
  return [[[SpotAlbum alloc] initWithAlbumBrowse:ab] autorelease];
}

-(SpotArtist*)artistByURI:(SpotURI*)uri;
{
  [networkLock lock];
  struct artist_browse* ab = despotify_link_get_artist(session, uri.link);
  [networkLock unlock];
  return [[[SpotArtist alloc] initWithArtistBrowse:ab] autorelease];
}

-(SpotTrack*)trackByURI:(SpotURI*)uri;
{
  [networkLock lock];
  struct track* track = despotify_link_get_track(session, uri.link);
  [networkLock unlock];
  return [[(SpotTrack*)[SpotTrack alloc] initWithTrack:track] autorelease];
}

-(SpotPlaylist*)playlistByURI:(SpotURI*)uri;
{
  [networkLock lock];
  struct playlist* pl = despotify_link_get_playlist(session, uri.link);
  [networkLock unlock];
  return [[[SpotPlaylist alloc] initWithPlaylist:pl] autorelease];
}

-(SpotSearch*)searchByURI:(SpotURI*)uri;
{
  [networkLock lock];
  struct search_result* sr = despotify_link_get_search(session, uri.link);
  [networkLock unlock];
  return [[[SpotSearch alloc] initWithSearchResult:sr] autorelease];
}

-(SpotItem *)cachedItemById:(NSString*)id_;
{
  return [cache itemById:id_];
}

-(void)doPlayTrack:(SpotTrack*)track;
{
  [networkLock lock];
  despotify_play(session, track.de_track, NO);
  [networkLock unlock];
}

-(void)playTrack:(SpotTrack*)track;
{
  //queue on mainthread do we dont collide with loading of images
  [self performSelector:@selector(doPlayTrack:) onThread:thread withObject:track waitUntilDone:NO];
}

-(void)addPlaylist:(SpotPlaylist*)playlist;
{
  NSLog(@"addPlaylist");
  if(![playlists containsObject:playlist]){
    NSLog(@"adding playlist %@", playlist.name);
    //add 
    [playlists addObject:playlist];
    //save to disc
    [NSKeyedArchiver archiveRootObject:playlists toFile:[self pathForFile:@"playlist"]];
  } else {
    NSLog(@"playlist %@ exists", playlist.name);
  }
}

#pragma mark Threading
-(void)runLoop:(id)arg;
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSLog(@"thread running");
  [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
  [[NSRunLoop currentRunLoop] run];
  NSLog(@"thread done");
  [pool drain];
}

-(void)startThread;
{
  NSLog(@"starting thread");
  thread = [[NSThread alloc] initWithTarget:self selector:@selector(runLoop:) object:nil];
  [thread start];
}

-(void)stopThread;
{
  [thread cancel];
  [thread release];
  thread = nil;
}
@end
