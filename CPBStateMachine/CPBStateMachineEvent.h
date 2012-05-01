//
//  CPBStateMachineEvent.h
//  CPBStateMachine
//
//  Created by Erik Price on 2012-04-08.
//  Copyright (c) 2012 Erik Price. All rights reserved.
//

#import <Foundation/Foundation.h>


@class CPBStateMachine;


@interface CPBStateMachineEvent : NSObject

@property (nonatomic, retain) id context;
@property (nonatomic, copy) NSString *eventName;
@property (nonatomic, retain) CPBStateMachine *stateMachine;

@end
