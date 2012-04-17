//
//  CPBStateMachine.m
//  CPBStateMachine
//
//  Created by Erik Price on 2012-04-08.
//  Copyright (c) 2012 Erik Price. All rights reserved.
//

#import "CPBStateMachine.h"

#import "CPBStateMachineEvent.h"


@interface CPBStateMachine ()

@property (nonatomic, retain) NSMutableDictionary *transitionsByEvent;
@property (nonatomic, retain) NSMutableArray *transitionsInternal;

// Maps events to actions to be performed after that event.
@property (nonatomic, retain) NSMutableDictionary *actionsByAfterEvent;
// Maps events to actions to be performed before that event.
@property (nonatomic, retain) NSMutableDictionary *actionsByBeforeEvent;
// Maps states to actions to be performed when entering that state.
@property (nonatomic, retain) NSMutableDictionary *actionsByEnteringState;
// Maps states to actions to be performed when leaving that state.
@property (nonatomic, retain) NSMutableDictionary *actionsByLeavingState;

// Maps events to action invocations to be performed after that event.
@property (nonatomic, retain) NSMutableDictionary *afterEventInvocations;
// Maps events to action invocations to be performed before that event.
@property (nonatomic, retain) NSMutableDictionary *beforeEventInvocations;
// Maps states to action invocations to be performed when entering that state.
@property (nonatomic, retain) NSMutableDictionary *enteringStateInvocations;
// Maps states to action invocations to be performed when leaving that state.
@property (nonatomic, retain) NSMutableDictionary *leavingStateInvocations;

- (void)storeAction:(CPBStateMachineAction)action forKey:(NSString *)key inActionMapping:(NSMutableDictionary *)actionsForKey;
- (void)storeInvocationForAction:(SEL)actionMethod withTarget:(id)targetObject forKey:(NSString *)key inInvocationMapping:(NSMutableDictionary *)invocationsForKey;

@end


@implementation CPBStateMachine

@synthesize currentState = currentStateInternal_;
@synthesize eventPropertyName = eventPropertyName_;
@synthesize errorHandler = errorHandler_;
@dynamic transitions;
@synthesize transitionsInternal = transitionsInternal_;

@synthesize transitionsByEvent = transitionsByEvent_;

@synthesize actionsByAfterEvent = actionsByAfterEvent_;
@synthesize actionsByBeforeEvent = actionsByBeforeEvent_;
@synthesize actionsByEnteringState = actionsByEnteringState_;
@synthesize actionsByLeavingState = actionsByLeavingState_;

@synthesize afterEventInvocations = afterEventInvocations_;
@synthesize beforeEventInvocations = beforeEventInvocations_;
@synthesize enteringStateInvocations = enteringStateInvocations_;
@synthesize leavingStateInvocations = leavingStateInvocations_;

- (void)dealloc
{
    [currentStateInternal_ release];
    
    self.errorHandler = nil;
    self.eventPropertyName = nil;
    
    self.transitionsByEvent = nil;
    self.transitionsInternal = nil;
    
    self.actionsByAfterEvent = nil;
    self.actionsByBeforeEvent = nil;
    self.actionsByEnteringState = nil;
    self.actionsByLeavingState = nil;
    
    self.afterEventInvocations = nil;
    self.beforeEventInvocations = nil;
    self.enteringStateInvocations = nil;
    self.leavingStateInvocations = nil;
    
    [super dealloc];
}

- (id)init
{
    return [self initWithState:nil];
}

- (id)initWithState:(NSString *)initialState
{
    if (self = [super init])
    {
        currentStateInternal_ = initialState;
        self.transitionsInternal = [NSMutableArray array];
        
        self.eventPropertyName = @"event";
        self.errorHandler = ^NSString *(id event) {
            
            NSString *eventName = [event valueForKey:self.eventPropertyName];
            [NSException raise:@"InvalidStateTransitionException" format:@"No transition registered on current state '%@' for event '%@' in %@", self.currentState, eventName, self];
            return nil;
            
        };
        
        self.transitionsByEvent = [NSMutableDictionary dictionary];
        
        self.actionsByAfterEvent = [NSMutableDictionary dictionary];
        self.actionsByBeforeEvent = [NSMutableDictionary dictionary];
        self.actionsByEnteringState = [NSMutableDictionary dictionary];
        self.actionsByLeavingState = [NSMutableDictionary dictionary];
        
        self.afterEventInvocations = [NSMutableDictionary dictionary];
        self.beforeEventInvocations = [NSMutableDictionary dictionary];
        self.enteringStateInvocations = [NSMutableDictionary dictionary];
        self.leavingStateInvocations = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)setCurrentState:(NSString *)newState
{
    [self willChangeValueForKey:@"currentState"];
    
    if (currentStateInternal_ != newState)
    {
        [newState retain];
        NSString *oldState = currentStateInternal_;
        currentStateInternal_ = newState;
        [oldState release];
    }
    
    [self didChangeValueForKey:@"currentState"];
}

- (void)setErrorHandler:(CPBStateMachineErrorHandler)errorHandler
{
    [errorHandler_ release];
    errorHandler_ = [errorHandler copy];
}

- (NSArray *)transitions
{
    NSMutableArray *ret = [[[NSMutableArray alloc] initWithCapacity:[self.transitionsInternal count]] autorelease];
    for (NSDictionary *transition in self.transitionsInternal)
    {
        NSDictionary *transitionCopy = [transition copy];
        [ret addObject:transitionCopy];
        [transitionCopy release];
    }
    
    return ret;
}

- (void)dispatchEvent:(id)event
{
    NSString *eventName = nil;
    CPBStateMachineEvent *smEvent = nil;
    if ([event isKindOfClass:[NSString class]])
    {
        eventName = (NSString *)event;
        smEvent = [self eventWithName:eventName];
    }
    else
    {
        smEvent = event;
        eventName = [smEvent valueForKey:self.eventPropertyName];
    }
    
    NSDictionary *transitionsForEvent = [self.transitionsByEvent objectForKey:eventName];
    NSDictionary *transitionForCurrentState = [transitionsForEvent objectForKey:self.currentState];
    if (!transitionForCurrentState)
    {
        transitionForCurrentState = [transitionsForEvent objectForKey:@"*"];
    }
    
    if (!transitionForCurrentState)
    {
        NSString *newState = self.errorHandler(smEvent);
        if (newState)
        {
            self.currentState = newState;
        }
        
        return;
    }
    
    NSString *newState = [transitionForCurrentState objectForKey:@"to"];
    NSString *oldState = self.currentState;
    
    for (CPBStateMachineAction action in [self.actionsByBeforeEvent objectForKey:eventName])
    {
        action(smEvent, oldState, newState);
    }

    for (NSInvocation *action in [self.beforeEventInvocations objectForKey:eventName])
    {
        // Indices 0 and 1 are for target and selector, so we start with 2.
        [action setArgument:smEvent atIndex:2];
        [action setArgument:oldState atIndex:3];
        [action setArgument:newState atIndex:4];
        
        [action invoke];
    }
    
    for (CPBStateMachineAction action in [self.actionsByLeavingState objectForKey:oldState])
    {
        action(smEvent, oldState, newState);
    }
    
    for (NSInvocation *action in [self.actionsByLeavingState objectForKey:oldState])
    {
        // Indices 0 and 1 are for target and selector, so we start with 2.
        [action setArgument:smEvent atIndex:2];
        [action setArgument:oldState atIndex:3];
        [action setArgument:newState atIndex:4];
        
        [action invoke];
    }
    
    self.currentState = newState;
    
    for (CPBStateMachineAction action in [self.actionsByEnteringState objectForKey:newState])
    {
        action(smEvent, oldState, newState);
    }
    
    for (NSInvocation *action in [self.actionsByEnteringState objectForKey:newState])
    {
        // Indices 0 and 1 are for target and selector, so we start with 2.
        [action setArgument:smEvent atIndex:2];
        [action setArgument:oldState atIndex:3];
        [action setArgument:newState atIndex:4];
        
        [action invoke];
    }
    
    for (CPBStateMachineAction action in [self.actionsByAfterEvent objectForKey:eventName])
    {
        action(smEvent, oldState, newState);
    }
    
    for (NSInvocation *action in [self.actionsByAfterEvent objectForKey:eventName])
    {
        // Indices 0 and 1 are for target and selector, so we start with 2.
        [action setArgument:smEvent atIndex:2];
        [action setArgument:oldState atIndex:3];
        [action setArgument:newState atIndex:4];
        
        [action invoke];
    }
}

- (CPBStateMachineEvent *)eventWithName:(NSString *)eventName
{
    CPBStateMachineEvent *event = [[[CPBStateMachineEvent alloc] init] autorelease];
    event.eventName = eventName;
    event.stateMachine = self;
    
    return event;
}

- (CPBStateMachineEvent *)eventWithName:(NSString *)eventName context:(id)context
{
    CPBStateMachineEvent *event = [[[CPBStateMachineEvent alloc] init] autorelease];
    event.context = context;
    event.eventName = eventName;
    event.stateMachine = self;
    
    return event;
}

- (void)mapEvent:(NSString *)eventName from:(id)fromStateOrStates to:(NSString *)toState
{
    if ([fromStateOrStates isKindOfClass:[NSArray class]])
    {
        for (NSString *fromState in fromStateOrStates)
        {
            [self mapEvent:eventName from:fromState to:toState];
        }
        
        return;
    }
    
    NSString *fromState = (NSString *)fromStateOrStates;
    NSDictionary *transition = [NSDictionary dictionaryWithObjectsAndKeys:eventName, self.eventPropertyName, fromState, @"from", toState, @"to", nil];
    [self.transitionsInternal addObject:transition];
    NSMutableDictionary *transitionsForEvent = [self.transitionsByEvent objectForKey:eventName];
    if (!transitionsForEvent)
    {
        transitionsForEvent = [NSMutableDictionary dictionary];
        [self.transitionsByEvent setObject:transitionsForEvent forKey:eventName];
    }
    
    [transitionsForEvent setObject:transition forKey:fromState];
}

- (void)mapEventToTransition:(NSDictionary *)eventMapping
{
    NSString *eventName = [eventMapping objectForKey:self.eventPropertyName];
    NSString *fromState = [eventMapping objectForKey:@"from"];
    NSString *toState = [eventMapping objectForKey:@"to"];
    
    [self mapEvent:eventName from:fromState to:toState];
}

- (void)mapEventsToTransitions:(NSArray *)eventMappings
{
    for (NSDictionary *eventMapping in eventMappings)
    {
        [self mapEventToTransition:eventMapping];
    }
}

- (void)registerAction:(CPBStateMachineAction)action afterEvent:(NSString *)event
{
    [self storeAction:action forKey:event inActionMapping:self.actionsByAfterEvent];
}

- (void)registerAction:(CPBStateMachineAction)action beforeEvent:(NSString *)event
{
    [self storeAction:action forKey:event inActionMapping:self.actionsByBeforeEvent];
}

- (void)registerAction:(CPBStateMachineAction)action enteringState:(NSString *)toState
{
    [self storeAction:action forKey:toState inActionMapping:self.actionsByEnteringState];
}

- (void)registerAction:(CPBStateMachineAction)action leavingState:(NSString *)fromState
{
    [self storeAction:action forKey:fromState inActionMapping:self.actionsByLeavingState];
}

- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject afterEvent:(NSString *)eventName
{
    [self storeInvocationForAction:actionMethod withTarget:targetObject forKey:eventName inInvocationMapping:self.afterEventInvocations];
}

- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject beforeEvent:(NSString *)eventName
{
    [self storeInvocationForAction:actionMethod withTarget:targetObject forKey:eventName inInvocationMapping:self.beforeEventInvocations];
}

- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject enteringState:(NSString *)toState
{
    [self storeInvocationForAction:actionMethod withTarget:targetObject forKey:toState inInvocationMapping:self.enteringStateInvocations];
}

- (void)registerAction:(SEL)actionMethod withTarget:(id)targetObject leavingState:(NSString *)fromState
{
    [self storeInvocationForAction:actionMethod withTarget:targetObject forKey:fromState inInvocationMapping:self.leavingStateInvocations];
}

- (NSString *)description
{
    NSMutableString *desc = [NSMutableString stringWithFormat:@"<%@: %p;", [self class], self];
    
    [desc appendFormat:@" currentState: %@;", self.currentState];
    
    NSMutableString *table = [NSMutableString stringWithString:@" transitionsByEvent:\n"];
    for (NSString *eventName in self.transitionsByEvent)
    {
        NSDictionary *transitionsForEvent = [self.transitionsByEvent objectForKey:eventName];
        for (NSString *fromState in transitionsForEvent)
        {
            NSDictionary *transition = [transitionsForEvent objectForKey:fromState];
            [table appendFormat:@"\t{ event: %@, from: %@, to: %@ },\n", eventName, fromState, [transition objectForKey:@"to"]];
        }
    }
    
    // Drop the last comma.
    if ([table length] > 0)
    {
        NSRange lastChars;
        lastChars.location = [table length] - 2;
        lastChars.length = 1;
        [table deleteCharactersInRange:lastChars];
    }
    [desc appendString:table];
    [desc appendFormat:@">"];
    
    return desc;
}

- (void)storeAction:(CPBStateMachineAction)action forKey:(NSString *)key inActionMapping:(NSMutableDictionary *)actionsForKey
{
    NSMutableArray *actions = [actionsForKey objectForKey:key];
    if (!actions)
    {
        actions = [NSMutableArray array];
        [actionsForKey setObject:actions forKey:key];
    }
    
    [actions addObject:[[action copy] autorelease]];
}

- (void)storeInvocationForAction:(SEL)actionMethod withTarget:(id)targetObject forKey:(NSString *)key inInvocationMapping:(NSMutableDictionary *)invocationsForKey
{
    NSMutableArray *invocations = [invocationsForKey objectForKey:key];
    if (!invocations)
    {
        invocations = [NSMutableArray array];
        [invocationsForKey setObject:invocations forKey:key];
    }
    
    NSMethodSignature *signature = [NSMethodSignature instanceMethodSignatureForSelector:actionMethod];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:targetObject];
    [invocations addObject:invocation];
    [invocation retainArguments];
}

@end
