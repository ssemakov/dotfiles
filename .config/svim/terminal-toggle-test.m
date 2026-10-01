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
  if (self.running) self.recovery = YES;
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
  if ([self manuallyStopped]) return;
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

@interface ServiceControlTest : QuickTerminal
@end
@implementation ServiceControlTest
- (void)discoverService {}
- (BOOL)serviceLoaded { return YES; }
@end

@interface ServiceDiscoveryTest : QuickTerminal
@property NSDictionary<NSString *, NSArray<NSString *> *> *paths;
@property NSString *loadedLabel;
@end
@implementation ServiceDiscoveryTest
- (NSArray<NSString *> *)servicePlistPathsForLabel:(NSString *)label { return self.paths[label] ?: @[]; }
- (BOOL)serviceLoaded { return [self.serviceTarget.lastPathComponent isEqual:self.loadedLabel]; }
@end

static NSDictionary *Command(QuickTerminal *helper, NSString *action) {
  NSString *identifier = NSUUID.UUID.UUIDString;
  NSDictionary *request = @{@"id": identifier, @"action": action};
  assert([request writeToFile:[helper.directory stringByAppendingPathComponent:@"control-request.plist"] atomically:YES]);
  [helper poll];
  NSDictionary *result = [NSDictionary dictionaryWithContentsOfFile:[helper.directory stringByAppendingPathComponent:@"control-result.plist"]];
  assert([result[@"id"] isEqual:identifier]);
  return result;
}

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

    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    assert([[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL]);
    NSString *formulaPlist = [directory stringByAppendingPathComponent:@"formula.plist"];
    NSString *homePlist = [directory stringByAppendingPathComponent:@"home.plist"];
    assert([@{@"Label": @"sh.brew.svim"} writeToFile:formulaPlist atomically:YES]);
    ServiceDiscoveryTest *discovery = [ServiceDiscoveryTest new];
    discovery.directory = directory;
    discovery.recoveryFile = [directory stringByAppendingPathComponent:@"discovery-recovery.plist"];
    discovery.paths = @{@"sh.brew.svim": @[homePlist, formulaPlist]};
    discovery.loadedLabel = @"sh.brew.svim";
    [discovery discoverService];
    assert([discovery.sourcePlist isEqual:formulaPlist]); // Missing home plist must not hide a running job.
    assert([discovery serviceLoaded]);
    assert(([@{@"Label": @"sh.brew.svim", @"custom": @YES} writeToFile:homePlist atomically:YES]));
    [discovery discoverService];
    assert([discovery.sourcePlist isEqual:homePlist]); // Prefer existing custom settings.
    discovery.loadedLabel = @"homebrew.mxcl.svim";
    [discovery discoverService];
    assert([discovery serviceLoaded] && !discovery.sourcePlist); // Report an unsnapshotable live job.
    assert(![discovery pauseService]);
    discovery.loadedLabel = nil;
    [discovery discoverService];
    assert([discovery.sourcePlist isEqual:homePlist] && ![discovery serviceLoaded]);
    assert([@{@"Label": @"homebrew.mxcl.svim"} writeToFile:discovery.recoveryFile atomically:YES]);
    discovery.loadedLabel = @"homebrew.mxcl.svim";
    [discovery discoverService]; assert([discovery serviceLoaded]);

    FakeQuickTerminal *manual = [FakeQuickTerminal new];
    manual.directory = directory;
    [manual toggle]; manual.visible = 1; [manual poll];
    assert([Command(manual, @"stop")[@"success"] boolValue]);
    assert([manual manuallyStopped] && manual.recovery && !manual.running);
    assert([Command(manual, @"stop")[@"success"] boolValue]); // Repeated stop preserves recovery.
    manual.visible = 0; [manual poll]; [manual poll];
    assert(!manual.running && ![manual.calls containsObject:@"start"]);
    manual.lastHotkey = 0; [manual toggle];
    manual.visible = 1; [manual poll];
    assert([Command(manual, @"start")[@"success"] boolValue]);
    assert(![manual manuallyStopped] && !manual.running); // Start from the panel waits for dismissal.
    assert([Command(manual, @"start")[@"success"] boolValue]);
    manual.visible = -1; [manual poll]; assert(!manual.running);
    manual.visible = 0; [manual poll]; assert(manual.running);
    NSUInteger starts = [manual.calls filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'start'"]].count;
    assert(starts == 1);

    // Stopping during blacklist initialization cancels that restore too.
    manual.restoring = YES; manual.waitingForActivation = YES;
    assert([Command(manual, @"stop")[@"success"] boolValue]);
    assert(!manual.restoring && !manual.waitingForActivation && !manual.running);
    assert([Command(manual, @"start")[@"success"] boolValue]);
    assert(manual.running); // Normal terminal: no panel, so restore immediately.

    ServiceControlTest *guard = [ServiceControlTest new];
    guard.directory = directory;
    guard.recoveryFile = [directory stringByAppendingPathComponent:@"recovery.plist"];
    assert([@{@"Label": @"sh.brew.svim"} writeToFile:guard.recoveryFile atomically:YES]);
    NSString *marker = [directory stringByAppendingPathComponent:@"manual-stop"];
    assert([@"paused" writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
    [guard restoreService]; assert(!guard.restoring); // Exercise the real restore guard.
    assert([[NSFileManager defaultManager] removeItemAtPath:marker error:NULL]);
    [guard restoreService]; assert(guard.restoring);

    // Starting an originally stopped service creates its restoration record.
    assert([[NSFileManager defaultManager] removeItemAtPath:guard.recoveryFile error:NULL]);
    guard.sourcePlist = [directory stringByAppendingPathComponent:@"service.plist"];
    assert([@{@"Label": @"sh.brew.svim"} writeToFile:guard.sourcePlist atomically:YES]);
    guard.restoring = NO;
    assert([Command(guard, @"start")[@"success"] boolValue]);
    assert([[[NSDictionary dictionaryWithContentsOfFile:guard.recoveryFile] objectForKey:@"Label"] isEqual:@"sh.brew.svim"]);
    assert([[NSFileManager defaultManager] removeItemAtPath:guard.recoveryFile error:NULL]);
    guard.sourcePlist = nil;
    assert([@"paused" writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
    assert(![Command(guard, @"start")[@"success"] boolValue]);
    assert([guard manuallyStopped]); // Failed enable keeps the manual pause.
    assert([[NSFileManager defaultManager] removeItemAtPath:directory error:NULL]);
    puts("Passed: lifecycle, recovery, activation, reentrancy, manual control, and service discovery with missing home plists.");
  }
  return 0;
}
