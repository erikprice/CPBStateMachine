CPBStateMachine
===============
CPBStateMachine is a simple library for implementing finite state machines in Objective-C. If you find that you are using a handful of instance variables as flags to track some aspect of your application's state and your code is becoming unwieldy, you may be able to make your code more readable/maintainable by refactoring it to a FSM (or using the State design pattern, which is not implemented by this library).

Although it can theoretically scale to a FSM of any size, CPBStateMachine was developed for FSMs with relatively few states whose transitions do not warrant being described in a separate file and then compiled into source code. There are [other tools][statec] which offer that level of sophistication. With CPBStateMachine, transitions and actions are defined directly in your source code. However, because transitions are registered with simple data structures (NSArrays, NSDictionaries, and NSStrings), you can use a string containing any language you like to define them. For example, you can use any YAML/JSON/XML parser to easily convert a string of transition mappings to an NSArray of NSDictionaries.

Note that CPBStateMachine does not perform or emulate any continuation-passing or trampolining. This means that CPBStateMachine should not be used if the entire flow of the application is handled by state machine transitions, because it would be possible to run out of stack memory in that case. CPBStateMachine adds a frame to the function call stack for each transition, so it is intended for applications that make use of a run loop and which need to handle events asynchronously, such as most GUI applications.

[statec]: https://github.com/mmower/statec 

Instructions
------------
**TODO** - add instructions and a quick example. For now, see the [unit tests][tests].

The easiest way to get started with CPBStateMachine in your project is to add the following files to your Xcode project (using "copy files to new location"):

* `CPBStateMachine.h`
* `CPBStateMachine.m`
* `CPBStateMachineEvent.h`
* `CPBStateMachineEvent.m`

[tests]: https://github.com/erikprice/CPBStateMachine/blob/master/CPBStateMachineTests/CPBStateMachineTests.m

Implementation Notes
--------------------
CPBStateMachine isn't designed to be subclassed, nor is it designed to be concurrently accessed from different threads.
