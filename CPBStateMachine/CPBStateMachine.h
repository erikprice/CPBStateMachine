//
//  CPBStateMachine.h
//  CPBStateMachine
//
//  Created by Erik Price on 2012-04-08.
//  Copyright (c) 2012 Erik Price. All rights reserved.
//

#import <Foundation/Foundation.h>


@class CPBStateMachineEvent;


// An action is a block that is called in response
// to a state machine transition or event dispatch.
// It is passed the transition's old and new states,
// and the event object which prompted the transition.
// (If the event dispatched was an NSString, then a
// CPBStateMachineEvent object is synthesized from
// the string and passed into the action.)
typedef void(^CPBStateMachineAction)(id event, NSString *fromState, NSString *toState);

// Should return nil if the state machine should skip
// transitions, or the new current state (no actions will be
// called). The default error handler will raise an exception.
typedef NSString *(^CPBStateMachineErrorHandler)(id event);


@interface CPBStateMachine : NSObject

@property (nonatomic, readonly) NSString *currentState;
@property (nonatomic, retain) CPBStateMachineErrorHandler errorHandler;
@property (nonatomic, retain) NSString *eventPropertyName; // Defaults to "event".
@property (nonatomic, readonly) NSArray *transitions;

- (id)initWithState:(NSString *)initialState;

// 'event' can be a NSString or an object with a property
// whose name corresponds to 'eventPropertyName'. If an
// NSString is supplied, it will be converted to a CPBStateMachineEvent
// in any actions invoked by this event or its transition.
- (void)dispatchEvent:(id)event;

- (CPBStateMachineEvent *)eventWithName:(NSString *)eventName;
- (CPBStateMachineEvent *)eventWithName:(NSString *)eventName context:(id)context;

- (void)mapEvent:(NSString *)eventName from:(id)fromStateOrStates to:(NSString *)toState;
- (void)mapEventToTransition:(NSDictionary *)eventMapping;
- (void)mapEventsToTransitions:(NSArray *)eventMappings;

- (void)registerAction:(CPBStateMachineAction)action afterEvent:(NSString *)event;
- (void)registerAction:(CPBStateMachineAction)action beforeEvent:(NSString *)event;
- (void)registerAction:(CPBStateMachineAction)action enteringState:(NSString *)toState;
- (void)registerAction:(CPBStateMachineAction)action leavingState:(NSString *)fromState;

// 'actionMethod' must conform to the following method signature:
// (id event, NSString *fromState, NSString *toState).
- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject afterEvent:(NSString *)eventName;
- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject beforeEvent:(NSString *)eventName;
- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject enteringState:(NSString *)toState;
- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject leavingState:(NSString *)fromState;

@end
