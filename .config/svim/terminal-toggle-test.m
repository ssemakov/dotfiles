// Exercise lifecycle failures without changing launch agents or opening UI.
#define TERMINAL_TOGGLE_TEST
#include "terminal-toggle.m"
#include <assert.h>

@interface FakeQuickTerminal : QuickTerminal
@property NSInteger visible;
@property BOOL running;
@property BOOL recovery;
@property BOOL stopFails;
@property BOOL pollDuringStop;
@property BOOL pollDuringMenu;
@property BOOL pollDuringRestore;
@property NSMutableArray<NSString *> *calls;
@end
@implementation FakeQuickTerminal
- (instancetype)init {
  if ((self = [super init])) { self.calls = [NSMutableArray new]; self.running = YES; }
  return self;
}
- (BOOL)connect { return YES; }
- (NSInteger)visibility { return self.visible; }
- (BOOL)hasRecovery { return self.recovery; }
- (BOOL)pauseService {
  [self.calls addObject:@"stop"];
  if (self.stopFails) return NO;
  self.recovery = self.running;
  self.running = NO;
  if (self.pollDuringStop) [self poll];
  return YES;
}
- (BOOL)pressMenu {
  [self.calls addObject:@"toggle"];
  if (self.pollDuringMenu) [self poll];
  return YES;
}
- (void)restoreService {
  if (self.recovery) {
    if (self.pollDuringRestore) { self.pollDuringRestore = NO; [self poll]; }
    [self.calls addObject:@"start"]; self.running = YES; self.recovery = NO;
  }
}
@end

@interface ActivationTest : QuickTerminal
@property BOOL completed;
@end
@implementation ActivationTest
- (BOOL)serviceReady { return YES; }
- (void)finishRestore { self.waitingForActivation = YES; }
- (void)completeRestore { self.completed = YES; self.waitingForActivation = NO; self.restoring = NO; }
@end

@interface TestApplication : NSObject
@property pid_t processIdentifier;
@end
@implementation TestApplication
@end

int main(void) {
  @autoreleasepool {
    FakeQuickTerminal *normal = [FakeQuickTerminal new];
    [normal toggle];
    assert(([normal.calls isEqual:@[@"stop", @"toggle"]]));
    [normal poll]; // Opening is asynchronous; a closed observation isn't dismissal.
    assert(!normal.running);
    [normal toggle]; // Double press while opening cannot resume the interceptor.
    assert(normal.calls.count == 2);
    normal.visible = 1; [normal poll];
    normal.visible = -1; [normal poll]; // AX outage isn't permission to restart.
    assert(!normal.running);
    normal.visible = 0; [normal poll]; // Includes click-away and shell exit.
    [normal poll];
    assert(([normal.calls isEqual:@[@"stop", @"toggle", @"start"]]));

    FakeQuickTerminal *closing = [FakeQuickTerminal new];
    closing.visible = 1; closing.recovery = YES; closing.running = NO;
    [closing toggle];
    assert(([closing.calls isEqual:@[@"toggle"]]));
    [closing poll]; assert(!closing.running); // Hide animation still on screen.
    closing.visible = 0; [closing poll]; assert(closing.running);

    FakeQuickTerminal *disabled = [FakeQuickTerminal new];
    disabled.running = NO;
    [disabled toggle]; disabled.visible = 1; [disabled poll];
    disabled.visible = 0; [disabled poll];
    assert(!disabled.running); // Preserve a service the user already stopped.
    assert(![disabled.calls containsObject:@"start"]);

    FakeQuickTerminal *failed = [FakeQuickTerminal new];
    failed.stopFails = YES; [failed toggle];
    assert(([failed.calls isEqual:@[@"stop"]])); // Never show before stop succeeds.

    FakeQuickTerminal *timeout = [FakeQuickTerminal new];
    [timeout toggle]; timeout.openDeadline = 0; [timeout poll];
    assert(timeout.running); // Failed opening restores the original service.

    FakeQuickTerminal *crashed = [FakeQuickTerminal new];
    crashed.recovery = YES; crashed.running = NO;
    crashed.visible = -1; [crashed poll]; assert(!crashed.running);
    crashed.visible = 1; [crashed poll]; assert(!crashed.running);
    crashed.visible = 0; [crashed poll]; assert(crashed.running);

    FakeQuickTerminal *nested = [FakeQuickTerminal new];
    nested.pollDuringStop = YES;
    nested.pollDuringMenu = YES;
    nested.pollDuringRestore = YES;
    [nested toggle]; // Simulate NSTask/AX spinning the run loop during opening.
    assert(([nested.calls isEqual:@[@"stop", @"toggle"]]));
    assert(!nested.running && nested.recovery && nested.waitingForOpen);
    nested.visible = 1; [nested poll];
    nested.visible = 0; [nested poll];
    assert(([nested.calls isEqual:@[@"stop", @"toggle", @"start"]]));

    ActivationTest *activation = [ActivationTest new];
    activation.restoring = YES;
    activation.restoreDeadline = NSProcessInfo.processInfo.systemUptime + 10;
    [activation poll]; // A running keyboard handler does not initialize the blacklist.
    assert(activation.restoring && activation.waitingForActivation && !activation.completed);
    TestApplication *otherApp = [TestApplication new];
    otherApp.processIdentifier = getpid() + 1;
    [activation applicationActivated:[NSNotification notificationWithName:NSWorkspaceDidActivateApplicationNotification
        object:nil userInfo:@{NSWorkspaceApplicationKey: otherApp}]];
    assert(activation.completed && !activation.restoring);
    puts("Passed: open/close, autohide, pre-stopped service, failures, recovery, activation, and nested timer callbacks during stop/open/restore.");
  }
  return 0;
}
