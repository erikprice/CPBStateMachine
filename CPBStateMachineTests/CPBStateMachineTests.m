//
//  CPBStateMachineTests.m
//  CPBStateMachineTests
//
//  Created by Erik Price on 2012-04-08.
//  Copyright (c) 2012 Erik Price. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "CPBStateMachine.h"
#import "CPBStateMachineEvent.h"

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


// This helper class serves as the target in calls to
// -registerAction:withTarget:*State methods.
@interface ActionWithTarget : NSObject

@end


@implementation ActionWithTarget
{
    NSMutableArray *_action0CallHistory;
    NSMutableArray *_action1CallHistory;
}

- (void)dealloc
{
    [_action0CallHistory release];
    [_action1CallHistory release];
    
    [super dealloc];
}

- (id)init
{
    if (self = [super init])
    {
        _action0CallHistory = [[NSMutableArray alloc] init];
        _action1CallHistory = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)action0ForEvent:(id)event fromState:(NSString *)fromState toState:(NSString *)toState
{
    NSDictionary *call = [NSDictionary dictionaryWithObjectsAndKeys:fromState, @"fromState", toState, @"toState", event, @"event", nil];
    [_action0CallHistory addObject:call];
}

- (void)action1ForEvent:(id)event fromState:(NSString *)fromState toState:(NSString *)toState
{
    NSDictionary *call = [NSDictionary dictionaryWithObjectsAndKeys:fromState, @"fromState", toState, @"toState", event, @"event", nil];
    [_action1CallHistory addObject:call];
}

- (BOOL)assertTransition:(NSDictionary *)transition inActionCallHistory:(NSArray *)callHistory
{
    for (NSDictionary *t in callHistory)
    {
        id calledEvent = [t objectForKey:@"event"];
        NSString *calledFromState = [t objectForKey:@"fromState"];
        NSString *calledToState = [t objectForKey:@"toState"];
        
        if (!(calledEvent && calledFromState && calledToState))
        {
            return NO;
        }
        
        BOOL found = YES;
        found = found && [calledFromState isEqualToString:[transition objectForKey:@"fromState"]];
        found = found && [calledToState isEqualToString:[transition objectForKey:@"toState"]];
        
        // Only cast to CPBStateMachineEvent if it is a a CPBStateMachineEvent
        // (not even a subclass). If not, it must be a custom event.
        if ([calledEvent isMemberOfClass:[CPBStateMachineEvent class]])
        {
            CPBStateMachineEvent *event = calledEvent;
            found = found && [event.eventName isEqualToString:[transition objectForKey:@"event"]];
        }
        else
        {
            // calledEvent is a custom event, we can test its identity against
            // the event object passed in the transition.
            found = found && [transition objectForKey:@"event"] == calledEvent;
        }
        
        if (found)
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)assertTransitionInAction0CallHistory:(NSDictionary *)transition
{
    return [self assertTransition:transition inActionCallHistory:_action0CallHistory];
}

- (BOOL)assertTransitionInAction1CallHistory:(NSDictionary *)transition
{
    return [self assertTransition:transition inActionCallHistory:_action1CallHistory];
}

@end




@interface CPBStateMachineTests : SenTestCase
{
    CPBStateMachine *machine;
    NSString *initial;
    NSMutableArray *transitionMatrix;
    BOOL currentStateChanged;
    ActionWithTarget *actionWithTarget0;
    ActionWithTarget *actionWithTarget1;
}

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
    
    actionWithTarget0 = [[[ActionWithTarget alloc] init] autorelease];
    actionWithTarget1 = [[[ActionWithTarget alloc] init] autorelease];
    
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

- (void)testDispatchStringEvent_ErrorOccurs_EventPassedToErrorHandler
{
    __block BOOL errorHandlerCalled = NO;
    machine.errorHandler = ^NSString *(id event) {
        
        errorHandlerCalled = YES;
        STAssertEqualObjects(kEvent3, [event valueForKey:machine.eventPropertyName], nil);
        return nil;
        
    };
    
    [machine mapEventsToTransitions:transitionMatrix];
    [machine dispatchEvent:kEvent3];
    
    STAssertTrue(errorHandlerCalled, nil);
}

- (void)testDispatchCustomEvent_ErrorOccurs_EventPassedToErrorHandler
{
    static NSString * const customKey = @"customKey";
    static NSString * const customValue = @"customValue";
    __block BOOL errorHandlerCalled = NO;
    machine.errorHandler = ^NSString *(id event) {
        
        errorHandlerCalled = YES;
        STAssertEqualObjects(kEvent3, [event valueForKey:machine.eventPropertyName], nil);
        STAssertEqualObjects(customValue, [event valueForKey:customKey], nil);
        return nil;
        
    };
    
    [machine mapEventsToTransitions:transitionMatrix];
    NSDictionary *customEvent = @{ machine.eventPropertyName: kEvent3, customKey: customValue };
    [machine dispatchEvent:customEvent];
    
    STAssertTrue(errorHandlerCalled, nil);
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

- (void)testRegisterActionLeavingState_DispatchEventPromptsStateTransition_ActionsCalled
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

- (void)testRegisterActionEnteringState_DispatchEventPromptsStateTransition_ActionsCalled
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

- (void)testRegisterActionBeforeEvent_DispatchEventPromptsStateTransition_ActionsCalled
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

- (void)testRegisterActionAfterEvent_DispatchEventPromptsStateTransition_ActionsCalled
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

- (void)testRegisterActionLeavingState_DispatchEventDoesntPromptStateTransition_ActionsNotCalled
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

- (void)testRegisterActionEnteringState_DispatchEventDoesntPromptStateTransition_ActionsNotCalled
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

- (void)testRegisterActionBeforeEvent_DispatchEventDoesntPromptStateTransition_ActionsCalled
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

- (void)testRegisterActionAfterEvent_DispatchEventDoesntPromptStateTransition_ActionsCalled
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

- (void)testRegisterActionBeforeEvent_NoActionsRegisteredForEvent_ActionsNotCalled
{
    __block BOOL action0called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0called = YES;
        
    } beforeEvent:kEvent1];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertFalse(action0called, nil);
}

- (void)testRegisterActionAfterEvent_NoActionsRegisteredForEvent_ActionsNotCalled
{
    __block BOOL action0called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0called = YES;
        
    } afterEvent:kEvent1];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    STAssertFalse(action0called, nil);
}

- (void)testRegisterActionEnteringStateFromState_DispatchEventPromptsStateTransition_ActionCalled
{
    __block BOOL action0Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action0Called = YES;
        
    } enteringState:kStateC fromState:kStateA];
    
    __block BOOL action1Called = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        action1Called = YES;
        
    } enteringState:kStateC fromState:kStateB];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    STAssertTrue(action0Called, nil);
    STAssertFalse(action1Called, nil);
}

- (void)testRegisterActionWithTargetLeavingState_DispatchEventPromptsStateTransition_ActionsCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 leavingState:kStateA];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 leavingState:kStateA];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    NSDictionary *expectedTransition = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent0, @"event", nil];
    STAssertTrue([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition], nil);
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition], nil);
}

- (void)testRegisterActionWithTargetEnteringState_DispatchEventPromptsStateTransition_ActionsCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 enteringState:kStateB];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 enteringState:kStateB];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    NSDictionary *expectedTransition = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent0, @"event", nil];
    STAssertTrue([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition], nil);
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition], nil);
}

- (void)testRegisterActionWithTargetBeforeEvent_DispatchEventPromptsStateTransition_ActionsCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 beforeEvent:kEvent0];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 beforeEvent:kEvent0];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    NSDictionary *expectedTransition = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent0, @"event", nil];
    STAssertTrue([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition], nil);
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition], nil);
}

- (void)testRegisterActionWithTargetAfterEvent_DispatchEventPromptsStateTransition_ActionsCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 afterEvent:kEvent0];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 afterEvent:kEvent0];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    NSDictionary *expectedTransition = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent0, @"event", nil];
    STAssertTrue([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition], nil);
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition], nil);
}

- (void)testRegisterActionWithTargetLeavingState_DispatchEventDoesntPromptStateTransition_ActionsNotCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 leavingState:kStateB];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 leavingState:kStateA];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    NSDictionary *expectedTransition0 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition0], nil);

    NSDictionary *expectedTransition1 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateC, @"toState", kEvent1, @"event", nil];
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition1], nil);
}

- (void)testRegisterActionWithTargetEnteringState_DispatchEventDoesntPromptStateTransition_ActionsNotCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 enteringState:kStateB];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 enteringState:kStateC];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    NSDictionary *expectedTransition0 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition0], nil);
    
    NSDictionary *expectedTransition1 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateC, @"toState", kEvent1, @"event", nil];
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition1], nil);
}

- (void)testRegisterActionWithTargetBeforeEvent_DispatchEventDoesntPromptStateTransition_ActionsCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 beforeEvent:kEvent1];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 beforeEvent:kEvent1];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    NSDictionary *expectedTransition0 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition0], nil);
    
    NSDictionary *expectedTransition1 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateC, @"toState", kEvent1, @"event", nil];
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition1], nil);
}

- (void)testRegisterActionWithTargetAfterEvent_DispatchEventDoesntPromptStateTransition_ActionsCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 afterEvent:kEvent1];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 afterEvent:kEvent1];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    NSDictionary *expectedTransition0 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition0], nil);
    
    NSDictionary *expectedTransition1 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateC, @"toState", kEvent1, @"event", nil];
    STAssertTrue([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition1], nil);
}

- (void)testDispatchEvent_NoActionsWithTargetsRegisteredForEvent_BeforeEventActionsWithTargetsNotCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 beforeEvent:kEvent1];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 beforeEvent:kEvent1];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    NSDictionary *expectedTransition0 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition0], nil);
    
    NSDictionary *expectedTransition1 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateC, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition1], nil);
}

- (void)testDispatchEvent_NoActionsWithTargetsRegisteredForEvent_AfterEventActionsWithTargetsNotCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 afterEvent:kEvent1];
    [machine registerAction:@selector(action1ForEvent:fromState:toState:) withTarget:actionWithTarget1 afterEvent:kEvent1];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent0];
    
    NSDictionary *expectedTransition0 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateB, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition0], nil);
    
    NSDictionary *expectedTransition1 = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateC, @"toState", kEvent1, @"event", nil];
    STAssertFalse([actionWithTarget1 assertTransitionInAction1CallHistory:expectedTransition1], nil);
}

- (void)testRegisterActionWithTargetEnteringStateFromState_DispatchEventPromptsStateTransition_ActionsCalled
{
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 enteringState:kStateC fromState:kStateA];
    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget1 enteringState:kStateC fromState:kStateB];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:kEvent1];
    
    NSDictionary *expectedTransition = [NSDictionary dictionaryWithObjectsAndKeys:kStateA, @"fromState", kStateC, @"toState", kEvent1, @"event", nil];
    STAssertTrue([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition], nil);
    STAssertFalse([actionWithTarget1 assertTransitionInAction0CallHistory:expectedTransition], nil);
}

- (void)testDispatchEvent_DispatchCustomEventObject_CustomEventObjectPassedToAction
{
    static NSString * const kTestPrivateData = @"only known to the custom event object";
    
    __block BOOL actionCalled = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        actionCalled = YES;
        NSDictionary *eventObj = (NSDictionary *)event;
        STAssertEquals(kTestPrivateData, [eventObj objectForKey:@"customKey"], nil);
        
    } enteringState:kStateB];
    
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:[NSDictionary dictionaryWithObjectsAndKeys:kEvent0, @"eventName", kTestPrivateData, @"customKey", nil]];
    
    STAssertTrue(actionCalled, nil);
}

- (void)testDispatchEvent_DispatchCustomEventObject_CustomEventObjectPassedToActionWithTarget
{
    static NSString * const kTestPrivateData = @"only known to the custom event object";
    NSDictionary *customEvent = @{ @"eventName": kEvent0, @"customKey": kTestPrivateData };

    [machine registerAction:@selector(action0ForEvent:fromState:toState:) withTarget:actionWithTarget0 enteringState:kStateB];
    [machine mapEventsToTransitions:transitionMatrix];
    
    [machine dispatchEvent:customEvent];
    
    NSDictionary *expectedTransition = @{ @"fromState": kStateA, @"toState": kStateB, @"event": customEvent };
    STAssertTrue([actionWithTarget0 assertTransitionInAction0CallHistory:expectedTransition], nil);
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
    STAssertEqualObjects(@"eventName", machine.eventPropertyName, nil);
}

- (void)testSetEventPropertyName_CustomValue_StateMachineExpectsEventsWithCustomEventPropertyName
{
    machine.eventPropertyName = @"customEventPropertyName";
    [machine mapEvent:kEvent0 from:kStateA to:kStateB];
    
    __block BOOL actionCalled = NO;
    [machine registerAction:^(id event, NSString *fromState, NSString *toState) {
        
        actionCalled = YES;
        
    } enteringState:kStateB];

    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:kEvent0, machine.eventPropertyName, nil];
    [machine dispatchEvent:event];
    
    STAssertTrue(actionCalled, nil);
}

- (void)testCurrentState_DefaultInitialState_CPBStateMachineStateInitial
{
    CPBStateMachine *sm = [[[CPBStateMachine alloc] init] autorelease];
    
    STAssertEqualObjects(kCPBStateMachineStateInitial, sm.currentState, nil);
}

- (void)assertState:(NSString *)state inMachine:(CPBStateMachine *)stateMachine
{
    STAssertEqualObjects(state, stateMachine.currentState, nil);
}

- (NSDictionary *)transitionForEvent:(NSString *)event from:(id)from to:(NSString *)to
{
    return [NSDictionary dictionaryWithObjectsAndKeys:event, @"eventName", from, @"from", to, @"to", nil];
}

@end
