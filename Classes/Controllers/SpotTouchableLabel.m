//
//  SpotTouchableLabel.m
//  Spot
//
//  Created by Patrik Sjöberg on 2009-05-29.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SpotTouchableLabel.h"

@interface NSObject (TouchLabel)
-(void)didTouchLabel:(id)sender;

@end


@implementation SpotTouchableLabel

@synthesize delegate;

-(id)initWithFrame:(CGRect)frame;
{
  if(![super initWithFrame:frame])return nil;
  [self setUserInteractionEnabled:YES];
  return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSLog(@"Touches Began!");
  if([delegate respondsToSelector:@selector(didTouchLabel:)])
    [delegate didTouchLabel:self];
}
@end
