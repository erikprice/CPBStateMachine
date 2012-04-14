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


@interface CPBStateMachineTests : SenTestCase
{
    CPBStateMachine *machine;
    NSString *initial;
    NSMutableArray *transitionMatrix;
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
    [m mapEventsToTransitions:transitionMatrix];
    [m dispatchEvent:kEvent3];
    [self assertState:kStateC inMachine:m];
}

- (void)testDispatchEvent_SameEvent3MappedToTwoTransitionsFromStateC_MovesToStateB
{
    CPBStateMachine *m = [[[CPBStateMachine alloc] initWithState:kStateC] autorelease];
    [m mapEventsToTransitions:transitionMatrix];
    [m dispatchEvent:kEvent3];
    [self assertState:kStateB inMachine:m];
}

- (void)testDispatchEvent_Event4MappedFromStarToStateA_MovesToStateAFromAnyState
{
    CPBStateMachine *ma = [[[CPBStateMachine alloc] initWithState:kStateA] autorelease];
    [ma mapEventsToTransitions:transitionMatrix];
    [self assertState:kStateA inMachine:ma];
    [ma dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:ma];
    
    CPBStateMachine *mb = [[[CPBStateMachine alloc] initWithState:kStateB] autorelease];
    [mb mapEventsToTransitions:transitionMatrix];
    [self assertState:kStateB inMachine:mb];
    [mb dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:mb];
    
    CPBStateMachine *mc = [[[CPBStateMachine alloc] initWithState:kStateC] autorelease];
    [mc mapEventsToTransitions:transitionMatrix];
    [self assertState:kStateC inMachine:mc];
    [mc dispatchEvent:kEvent4];
    [self assertState:kStateA inMachine:mc];
    
    CPBStateMachine *md = [[[CPBStateMachine alloc] initWithState:kStateD] autorelease];
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
