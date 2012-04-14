//
//  CPBStateMachineEvent.m
//  CPBStateMachine
//
//  Created by Erik Price on 2012-04-08.
//  Copyright (c) 2012 Erik Price. All rights reserved.
//

#import "CPBStateMachineEvent.h"

@implementation CPBStateMachineEvent

@synthesize context = context_;
@synthesize eventName = eventName_;
@synthesize stateMachine = stateMachine_;

- (void)dealloc
{
    self.context = nil;
    self.eventName = nil;
    self.stateMachine = nil;
    
    [super dealloc];
}

@end
