//
//  CPBStateMachineTests.m
//  CPBStateMachineTests
//
//  Created by Erik Price on 2012-04-08.
//  Copyright (c) 2012 Erik Price. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "CPBStateMachine.h"

static NSString * const kEvent0 = @"event0";
static NSString * const kEvent1 = @"event1";
static NSString * const kEvent2 = @"event2";
static NSString * const kEvent3 = @"event3";
static NSString * const kEvent4 = @"event4";

static NSString * const kStateA = @"stateA";
static NSString * const kStateB = @"stateB";
static NSString * const kStateC = @"stateC";
static NSString * const kStateD = @"stateD";


NSString * const kStateMachineCurrentStateChangeSentinel0 = @"StateMachineCurrentStateChange0";
NSString * const kStateMachineCurrentStateChangeSentinel1 = @"StateMachineCurrentStateChange1";


@interface CPBStateMachineTests : SenTestCase
{
    CPBStateMachine *machine;
    NSString *initial;
    NSMutableArray *transitionMatrix;
    BOOL currentStateChanged;
}

- (void)assertState:(NSString *)state inMachine:(CPBStateMachine *)stateMachine;
- (NSDictionary *)transitionForEvent:(NSString *)event from:(id)from to:(NSString *)to;

@end


@implementation CPBStateMachineTests

- (void)setUp
{
    [super setUp];
    
    initial = kStateA;
    machine = [[[CPBStateMachine alloc] initWithState:initial] autorelease];
    machine.eventPropertyName = @"event";
    
    // [{ event: event0 from: stateA            to: stateB },
    //  { event: event1 from: stateA            to: stateC },
    //  { event: event2 from: [stateB, stateC], to: stateD },
    //  { event: event4 from: stateB            to: stateC },
    //  { event: event4 from: stateC            to: stateB },
    //  { event: event4 from: stateD            to: stateC },
    //  { event: event3 from: *                 to: stateA }]
    transitionMatrix = [NSMutableArray array];
    [transitionMatrix addObject:[self transitionForEvent:kEvent0 from:kStateA to:kStateB]];
    [transitionMatrix addObject:[self transitionForEvent:kEvent1 from:kStateA to:kStateC]];
    [transitionMatrix addObject:[self transitionForEvent:kEvent2 from:[NSArray arrayWithObjects:kStateB, kStateC, nil] to:kStateD]];
    [transitionMatrix addObject:[self transitionForEvent:kEvent3 from:kStateB to:kStateC]];
    [transitionMatrix addObject:[self transitionForEvent:kEvent3 from:kStateC to:kStateB]];
    [transitionMatrix addObject:[self transitionForEvent:kEvent3 from:kStateD to:kStateC]];
    [transitionMatrix addObject:[self transitionForEvent:kEvent4 from:@"*" to:kStateA]];
    
    currentStateChanged = NO;
}

- (void)testInitWithState_InitialState_CurrentStateIsInitialState
{
    [self assertState:initial inMachine:machine];
}

- (void)testMapEventFromTo_SimpleEventFromAndTo_TransitionStored
{
    [machine mapEvent:kEvent0 from:kStateA to:kStateB];
    
    STAssertEquals((NSUInteger)1, [machine.transitions count], nil);
    NSDictionary *expected = [self transitionForEvent:kEvent0 from:kStateA to:kStateB];
    STAssertEqualObjects(expected, [machine.transitions objectAtIndex:0], nil);
}

- (void)testMapEventFromTo_TwoEventsFromsAndTos_TransitionsStored
{
    [machine mapEvent:kEvent0 from:kStateA to:kStateB];
    [machine mapEvent:kEvent1 from:kStateB to:kStateC];
    
    STAssertEquals((NSUInteger)2, [machine.transitions count], nil);
    NSDictionary *expected0 = [self transitionForEvent:kEvent0 from:kStateA to:kStateB];
    NSDictionary *expected1 = [self transitionForEvent:kEvent1 from:kStateB to:kStateC];
    STAssertEqualObjects(expected0, [machine.transitions objectAtIndex:0], nil);
    STAssertEqualObjects(expected1, [machine.transitions objectAtIndex:1], nil);
}

- (void)testMapEventToTransition_OneMapping_TransitionStored
{
    NSDictionary *transition = [self transitionForEvent:kEvent0 from:kStateA to:kStateB];
    
    [machine mapEventToTransition:transition];
    
    STAssertEqualObjects(transition, [machine.transitions objectAtIndex:0], nil);
}

- (void)testMapEventToTransition_TwoMappings_TransitionsStored
{
    NSDictionary *transition0 = [self transitionForEvent:kEvent0 from:kStateA to:kStateB];
    NSDictionary *transition1 = [self transitionForEvent:kEvent1 from:kStateB to:kStateC];
    
    [machine mapEventToTransition:transition0];
    [machine mapEventToTransition:transition1];

    STAssertEqualObjects(transition0, [machine.transitions objectAtIndex:0], nil);
    STAssertEqualObjects(transition1, [machine.transitions objectAtIndex:1], nil);
}

- (void)testMapEventsToTransitions_FullTransitionMatrix_TransitionsStored
{
    [machine mapEventsToTransitions:transitionMatrix];
    
    NSMutableArray *expected = [NSMutableArray arrayWithCapacity:[transitionMatrix count] + 1];
    [expected addObject:[self transitionForEvent:kEvent0 from:kStateA to:kStateB]];
    [expected addObject:[self transitionForEvent:kEvent1 from:kStateA to:kStateC]];
    [expected addObject:[self transitionForEvent:kEvent2 from:kStateB to:kStateD]];
    [expected addObject:[self transitionForEvent:kEvent2 from:kStateC to:kStateD]];
    [expected addObject:[self transitionForEvent:kEvent3 from:kStateB to:kStateC]];
    [expected addObject:[self transitionForEvent:kEvent3 from:kStateC to:kStateB]];
    [expected addObject:[self transitionForEvent:kEvent3 from:kStateD to:kStateC]];
    [expected addObject:[self transitionForEvent:kEvent4 from:@"*" to:kStateA]];
    
    STAssertEqualObjects(expected, machine.transitions, nil);
}

- (void)testDispatchEvent_Event0MapsStateAToStateB_MovesToStateB
{
    [machine mapEvent:kEvent0 from:kStateA to:kStateB];
    
    [machine dispatchEvent:kEvent0];
    
    [self assertState:kStateB inMachine:machine];
}

- (void)testDispatchEvent_Event1MapsStateBToStateC_MovesToStateC
{
    [machine mapEvent:kEvent0 from:kStateA to:kStateB];
    [machine mapEvent:kEvent1 from:kStateB to:kStateC];
    
    [machine dispatchEvent:kEvent0];
    [machine dispatchEvent:kEvent1];
    
    [self assertState:kStateC inMachine:machine];
}

- (void)testDispatchEvent_ComplexTransitionSequence_MovesToExpectedStates
{
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    [self assertState:kStateB inMachine:machine];
    [machine dispatchEvent:kEvent3];
    [self assertState:kStateC inMachine:machine];
    [machine dispatchEvent:kEvent3];
    [self assertState:kStateB inMachine:machine];
    [machine dispatchEvent:kEvent2];
    [self assertState:kStateD inMachine:machine];
    [machine dispatchEvent:kEvent3];
    [self assertState:kStateC inMachine:machine];
    [machine dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:machine];
    [machine dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:machine];
    [machine dispatchEvent:kEvent1];
    [self assertState:kStateC inMachine:machine];
}

- (void)testDispatchEvent_SameEvent3MappedToTwoTransitionsFromStateB_MovesToStateC
{
    CPBStateMachine *m = [[[CPBStateMachine alloc] initWithState:kStateB] autorelease];
    m.eventPropertyName = @"event";
    [m mapEventsToTransitions:transitionMatrix];
    [m dispatchEvent:kEvent3];
    [self assertState:kStateC inMachine:m];
}

- (void)testDispatchEvent_SameEvent3MappedToTwoTransitionsFromStateC_MovesToStateB
{
    CPBStateMachine *m = [[[CPBStateMachine alloc] initWithState:kStateC] autorelease];
    m.eventPropertyName = @"event";
    [m mapEventsToTransitions:transitionMatrix];
    [m dispatchEvent:kEvent3];
    [self assertState:kStateB inMachine:m];
}

- (void)testDispatchEvent_Event4MappedFromStarToStateA_MovesToStateAFromAnyState
{
    CPBStateMachine *ma = [[[CPBStateMachine alloc] initWithState:kStateA] autorelease];
    ma.eventPropertyName = @"event";
    [ma mapEventsToTransitions:transitionMatrix];
    [self assertState:kStateA inMachine:ma];
    [ma dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:ma];
    
    CPBStateMachine *mb = [[[CPBStateMachine alloc] initWithState:kStateB] autorelease];
    mb.eventPropertyName = @"event";
    [mb mapEventsToTransitions:transitionMatrix];
    [self assertState:kStateB inMachine:mb];
    [mb dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:mb];
    
    CPBStateMachine *mc = [[[CPBStateMachine alloc] initWithState:kStateC] autorelease];
    mc.eventPropertyName = @"event";
    [mc mapEventsToTransitions:transitionMatrix];
    [self assertState:kStateC inMachine:mc];
    [mc dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:mc];
    
    CPBStateMachine *md = [[[CPBStateMachine alloc] initWithState:kStateD] autorelease];
    md.eventPropertyName = @"event";
    [md mapEventsToTransitions:transitionMatrix];
    [self assertState:kStateD inMachine:md];
    [md dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:md];
}

- (void)testDispatchEvent_TransitionRegistered_ErrorHandlerNotCalled
{
    __block BOOL errorHandlerCalled = NO;
    machine.errorHandler = ^NSString *(id event) {
        
        errorHandlerCalled = YES;
        return nil;
        
    };
    
    [machine mapEventsToTransitions:transitionMatrix];
    [machine dispatchEvent:kEvent0];
    
    STAssertFalse(errorHandlerCalled, nil);
    [self assertState:kStateB inMachine:machine];
}

- (void)testDispatchEvent_NoTransitionRegistered_ErrorHandlerCalled
{
    __block BOOL errorHandlerCalled = NO;
    machine.errorHandler = ^NSString *(id event) {
        
        errorHandlerCalled = YES;
        return nil;
        
    };
    
    [machine mapEventsToTransitions:transitionMatrix];
    [machine dispatchEvent:kEvent3];
    
    STAssertTrue(errorHandlerCalled, nil);
    [self assertState:kStateA inMachine:machine];
}

- (void)testDispatchEvent_NoTransitionRegistered_ErrorHandlerReturnValueUpdatesCurrentState
{
    machine.errorHandler = ^NSString *(id event) {
        
        return kStateD;
        
    };
    
    [machine mapEventsToTransitions:transitionMatrix];
    [machine dispatchEvent:kEvent3];
    
    [self assertState:kStateD inMachine:machine];
}

- (void)testDispatchEvent_NoTransitionRegistered_NoActionsCalled
{
    __block BOOL actionCalled = NO;
    CPBStateMachineAction action = ^(id event, NSString *fromState, NSString *toState) {
        
        actionCalled = YES;
        
    };
    
    [machine registerAction:action leavingState:kStateA];
    [machine registerAction:action beforeEvent:kEvent2];
    [machine registerAction:action enteringState:kStateD];
    [machine registerAction:action afterEvent:kEvent2];
    
    machine.errorHandler = ^NSString *(id event) {
        
        return nil;
        
    };
    
    [machine mapEventsToTransitions:transitionMatrix];
    [machine dispatchEvent:kEvent2];
    
    [self assertState:kStateA inMachine:machine];
    STAssertFalse(actionCalled, nil);
}

- (void)testDispatchEvent_EventPromptsStateTransition_LeaveStateActionsCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } leavingState:kStateA];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } leavingState:kStateA];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertTrue(action0Called, nil);
    STAssertTrue(action1Called, nil);
}

- (void)testDispatchEvent_EventPromptsStateTransition_EnterStateActionsCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } enteringState:kStateB];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } enteringState:kStateB];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertTrue(action0Called, nil);
    STAssertTrue(action1Called, nil);
}

- (void)testDispatchEvent_EventPromptsStateTransition_BeforeEventActionsCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } beforeEvent:kEvent0];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } beforeEvent:kEvent0];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertTrue(action0Called, nil);
    STAssertTrue(action1Called, nil);
}

- (void)testDispatchEvent_EventPromptsStateTransition_AfterEventActionsCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } afterEvent:kEvent0];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } afterEvent:kEvent0];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertTrue(action0Called, nil);
    STAssertTrue(action1Called, nil);
}

- (void)testDispatchEvent_EventDoesntPromptStateTransition_LeaveStateActionsNotCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } leavingState:kStateB];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } leavingState:kStateA];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    STAssertFalse(action0Called, nil);
    STAssertTrue(action1Called, nil);
}

- (void)testDispatchEvent_EventDoesntPromptStateTransition_EnterStateActionsNotCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } enteringState:kStateB];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } enteringState:kStateC];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    STAssertFalse(action0Called, nil);
    STAssertTrue(action1Called, nil);
}

- (void)testDispatchEvent_EventDoesntPromptStateTransition_BeforeEventActionsCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } beforeEvent:kEvent1];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } beforeEvent:kEvent0];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertFalse(action0Called, nil);
    STAssertTrue(action1Called, nil);
}

- (void)testDispatchEvent_EventDoesntPromptStateTransition_AfterEventActionsCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } afterEvent:kEvent0];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } afterEvent:kEvent1];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertTrue(action0Called, nil);
    STAssertFalse(action1Called, nil);
}

- (void)testDispatchEvent_NoActionsRegisteredForEvent_BeforeEventActionsNotCalled
{
    __block BOOL action0called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0called = YES;
        
    } beforeEvent:kEvent1];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertFalse(action0called, nil);
}

- (void)testDispatchEvent_NoActionsRegisteredForEvent_AfterEventActionsNotCalled
{
    __block BOOL action0called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0called = YES;
        
    } afterEvent:kEvent1];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertFalse(action0called, nil);
}

- (void)testDispatchEvent_CustomEventObject_CustomEventObjectPassedToAction
{
    static NSString * const kTestPrivateData = @"only known to the custom event object";
    
    __block BOOL actionCalled = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        actionCalled = YES;
        NSDictionary *eventObj = (NSDictionary *)event;
        STAssertEquals(kTestPrivateData, [eventObj objectForKey:@"customKey"], nil);
        
    } enteringState:kStateB];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:[NSDictionary dictionaryWithObjectsAndKeys:kEvent0, @"event", kTestPrivateData, @"customKey", nil]];
    
    STAssertTrue(actionCalled, nil);
}

- (void)testDispatchEvent_EventPromptsStateTransition_CurrentStateChangeNotificationToKeyValueObservers
{
    [machine addObserver:self forKeyPath:@"currentState" options:NSKeyValueObservingOptionNew context:kStateMachineCurrentStateChangeSentinel0];
    [machine mapEventsToTransitions:transitionMatrix];

    [machine dispatchEvent:kEvent0];
    
    [machine removeObserver:self forKeyPath:@"currentState"];
    
    STAssertTrue(currentStateChanged, nil);
}

- (void)testDispatchEvent_EventDoesntPromptStateTransition_NoCurrentStateChangeNotificationToKeyValueObservers
{
    // Need to configure the state machine for leniency.
    machine.errorHandler = ^NSString *(id event) {
        
        return nil;
        
    };
    [machine mapEventsToTransitions:transitionMatrix];
    [machine addObserver:self forKeyPath:@"currentState" options:NSKeyValueObservingOptionNew context:kStateMachineCurrentStateChangeSentinel1];

    [machine dispatchEvent:kEvent2];

    [machine removeObserver:self forKeyPath:@"currentState"];
    
    STAssertFalse(currentStateChanged, nil);
    STAssertEqualObjects(kStateA, machine.currentState, nil);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kStateMachineCurrentStateChangeSentinel0)
    {
        currentStateChanged = YES;
    }
    else if (context == kStateMachineCurrentStateChangeSentinel1)
    {
        currentStateChanged = YES;
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)testEventPropertyName_DefaultValue_IsDefault
{
    STAssertEqualObjects(@"event", machine.eventPropertyName, nil);
}

- (void)assertState:(NSString *)state inMachine:(CPBStateMachine *)stateMachine
{
    STAssertEqualObjects(state, stateMachine.currentState, nil);
}

- (NSDictionary *)transitionForEvent:(NSString *)event from:(id)from to:(NSString *)to
{
    return [NSDictionary dictionaryWithObjectsAndKeys:event, @"event", from, @"from", to, @"to", nil];
}

@end
