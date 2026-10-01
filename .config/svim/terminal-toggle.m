// Own Cmd+` so SketchyVim is stopped before Ghostty shows its nonactivating panel.
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include <sys/file.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>

static NSString *const GhosttyID = @"com.mitchellh.ghostty";
static NSString *const PanelID = @"com.mitchellh.ghostty.quickTerminal";

static id Attribute(AXUIElementRef element, CFStringRef name, AXError *error) {
  CFTypeRef value = NULL;
  AXError result = AXUIElementCopyAttributeValue(element, name, &value);
  if (error) *error = result;
  return result == kAXErrorSuccess ? CFBridgingRelease(value) : nil;
}

static id FindMenu(AXUIElementRef element, NSString *title, NSUInteger depth) {
  if ([Attribute(element, kAXTitleAttribute, NULL) isEqual:title]) {
    return (__bridge id)element;
  }
  if (depth == 0) return nil;
  for (id child in Attribute(element, kAXChildrenAttribute, NULL)) {
    id found = FindMenu((__bridge AXUIElementRef)child, title, depth - 1);
    if (found) return found;
  }
  return nil;
}

static int Run(NSString *executable, NSArray<NSString *> *arguments, NSString **output) {
  NSTask *task = [NSTask new];
  task.executableURL = [NSURL fileURLWithPath:executable];
  task.arguments = arguments;
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSFileHandle fileHandleWithNullDevice];
  NSError *error = nil;
  if (![task launchAndReturnError:&error]) {
    NSLog(@"Could not launch %@: %@", executable, error.localizedDescription);
    return -1;
  }
  NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
  [task waitUntilExit];
  if (output) *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  return task.terminationStatus;
}

@interface QuickTerminal : NSObject
@property NSString *directory;
@property NSString *recoveryFile;
@property NSString *serviceTarget;
@property NSString *sourcePlist;
@property id menu;
@property NSRunningApplication *ghostty;
@property BOOL waitingForOpen;
@property BOOL sawOpen;
@property BOOL stopping;
@property BOOL restoring;
@property BOOL waitingForActivation;
@property BOOL toggling;
@property BOOL polling;
@property NSTimeInterval openDeadline;
@property NSTimeInterval restoreDeadline;
@property NSTimeInterval lastHotkey;
@property NSRunningApplication *returnApp;
@property NSWindow *focusWindow;
@property NSTimer *timer;
- (BOOL)connect;
- (NSInteger)visibility;
- (BOOL)pauseService;
- (BOOL)pressMenu;
- (void)restoreService;
- (void)toggle;
- (void)poll;
- (BOOL)manuallyStopped;
- (void)handleControlRequest;
- (NSArray<NSString *> *)servicePlistPathsForLabel:(NSString *)label;
@end

@implementation QuickTerminal
- (BOOL)connect {
  if (self.menu && self.ghostty && !self.ghostty.terminated) return YES;
  self.ghostty = [NSRunningApplication runningApplicationsWithBundleIdentifier:GhosttyID].firstObject;
  self.menu = nil;
  if (!self.ghostty) return NO;
  AXUIElementRef app = AXUIElementCreateApplication(self.ghostty.processIdentifier);
  AXUIElementSetMessagingTimeout(app, 0.5);
  id bar = Attribute(app, kAXMenuBarAttribute, NULL);
  if (bar) self.menu = FindMenu((__bridge AXUIElementRef)bar, @"Quick Terminal", 5);
  CFRelease(app);
  return self.menu != nil;
}

// -1 means unknown. An AX failure must never be mistaken for a closed panel.
- (NSInteger)visibility {
  if (self.ghostty.terminated) { self.menu = nil; return 0; }
  if (!self.menu && ![self connect]) return self.ghostty ? -1 : 0;
  AXError error;
  id enabled = Attribute((__bridge AXUIElementRef)self.menu, kAXEnabledAttribute, &error);
  if (error != kAXErrorSuccess || !enabled) { self.menu = nil; return -1; }
  NSString *mark = Attribute((__bridge AXUIElementRef)self.menu, kAXMenuItemMarkCharAttribute, &error);
  if (error != kAXErrorSuccess && error != kAXErrorNoValue) return -1;
  if (mark.length) return 1;

  // The menu unchecks at the start of the hide animation. Wait until the panel
  // also leaves AXWindows, so its last keystroke cannot race the service restart.
  AXUIElementRef app = AXUIElementCreateApplication(self.ghostty.processIdentifier);
  NSArray *windows = Attribute(app, kAXWindowsAttribute, &error);
  CFRelease(app);
  if (error != kAXErrorSuccess) return -1;
  for (id window in windows) {
    if ([Attribute((__bridge AXUIElementRef)window, kAXIdentifierAttribute, NULL) isEqual:PanelID]) return 1;
  }
  return 0;
}

- (BOOL)serviceLoaded {
  if (!self.serviceTarget) return NO;
  return Run(@"/bin/launchctl", @[@"print", self.serviceTarget], NULL) == 0;
}

- (NSArray<NSString *> *)servicePlistPathsForLabel:(NSString *)label {
  NSString *filename = [label stringByAppendingPathExtension:@"plist"];
  return @[
    [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"] stringByAppendingPathComponent:filename],
    [@"/opt/homebrew/opt/svim" stringByAppendingPathComponent:filename],
    [@"/usr/local/opt/svim" stringByAppendingPathComponent:filename]
  ];
}

- (void)discoverService {
  if ([self hasRecovery]) {
    NSString *label = [NSDictionary dictionaryWithContentsOfFile:self.recoveryFile][@"Label"];
    self.serviceTarget = label ? [NSString stringWithFormat:@"gui/%u/%@", getuid(), label] : nil;
    return;
  }
  NSString *stoppedTarget = nil;
  NSString *stoppedPlist = nil;
  for (NSString *label in @[@"sh.brew.svim", @"homebrew.mxcl.svim"]) {
    self.serviceTarget = [NSString stringWithFormat:@"gui/%u/%@", getuid(), label];
    self.sourcePlist = nil;
    for (NSString *file in [self servicePlistPathsForLabel:label]) {
      if (![[[NSDictionary dictionaryWithContentsOfFile:file] objectForKey:@"Label"] isEqual:label]) continue;
      self.sourcePlist = file;
      break;
    }
    // A bootstrapped job can outlive its original plist. Query launchd even
    // when ~/Library/LaunchAgents has no file, and retain a loaded job whose
    // plist is missing so pauseService reports the error instead of ignoring it.
    if ([self serviceLoaded]) return;
    if (!stoppedPlist && self.sourcePlist) {
      stoppedTarget = self.serviceTarget;
      stoppedPlist = self.sourcePlist;
    }
  }
  self.serviceTarget = stoppedTarget;
  self.sourcePlist = stoppedPlist;
}

- (pid_t)servicePID {
  if (!self.serviceTarget) return 0;
  NSString *state;
  if (Run(@"/bin/launchctl", @[@"print", self.serviceTarget], &state) != 0) return 0;
  NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"\\bpid = ([0-9]+)" options:0 error:NULL];
  NSTextCheckingResult *match = [pattern firstMatchInString:state options:0 range:NSMakeRange(0, state.length)];
  return match ? [[state substringWithRange:[match rangeAtIndex:1]] intValue] : 0;
}

- (BOOL)hasRecovery {
  return [[NSFileManager defaultManager] fileExistsAtPath:self.recoveryFile];
}

- (BOOL)manuallyStopped {
  if (!self.directory) return NO;
  return [[NSFileManager defaultManager] fileExistsAtPath:[self.directory stringByAppendingPathComponent:@"manual-stop"]];
}

// Commands are handled by the running helper, serially with its timer and
// hotkey callbacks. A CLI must not race launchctl against an ongoing restore.
- (void)handleControlRequest {
  if (!self.directory) return;
  NSString *requestFile = [self.directory stringByAppendingPathComponent:@"control-request.plist"];
  NSDictionary *request = [NSDictionary dictionaryWithContentsOfFile:requestFile];
  if (!request) return;
  NSString *action = request[@"action"];
  NSString *marker = [self.directory stringByAppendingPathComponent:@"manual-stop"];
  BOOL success = NO;
  NSString *message = @"Unknown SketchyVim command.";
  if ([action isEqual:@"stop"]) {
    success = [@"paused\n" writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    if (success) success = [self pauseService];
    if (success) {
      self.waitingForActivation = NO;
      self.restoring = NO;
      self.returnApp = nil;
      [self.focusWindow orderOut:nil];
      if (NSApp.active) [NSApp hide:nil];
    }
    message = success ? @"SketchyVim stopped until you run svim-start."
      : @"Could not stop SketchyVim; manual pause remains requested. Check helper.log.";
  } else if ([action isEqual:@"start"]) {
    success = YES;
    if (![self hasRecovery]) {
      [self discoverService];
      NSData *plist = self.sourcePlist ? [NSData dataWithContentsOfFile:self.sourcePlist] : nil;
      success = plist && [plist writeToFile:self.recoveryFile atomically:YES];
    }
    if (success && [self manuallyStopped]) {
      success = [[NSFileManager defaultManager] removeItemAtPath:marker error:NULL];
    }
    message = success ? @"SketchyVim enabled; it resumes when the quick terminal is closed."
      : @"Could not enable SketchyVim. Install its Homebrew service first; check helper.log.";
  }
  // Remove the request before acknowledging it so it cannot run twice.
  [[NSFileManager defaultManager] removeItemAtPath:requestFile error:NULL];
  [@{@"id": request[@"id"] ?: @"", @"success": @(success), @"message": message}
      writeToFile:[self.directory stringByAppendingPathComponent:@"control-result.plist"] atomically:YES];
}

- (BOOL)pauseService {
  [self discoverService];
  if (![self serviceLoaded]) {
    NSLog(@"No loaded SketchyVim service found (target=%@, plist=%@).", self.serviceTarget, self.sourcePlist);
    return YES;
  }
  pid_t pid = [self servicePID];
  // Save before bootout. Launchd relaunches this helper after a crash, and the
  // saved plist lets it finish restoring the exact service it stopped.
  if (![self hasRecovery]) {
    NSData *plist = self.sourcePlist ? [NSData dataWithContentsOfFile:self.sourcePlist] : nil;
    if (!plist || ![plist writeToFile:self.recoveryFile atomically:YES]) {
      NSLog(@"Could not save the SketchyVim service %@ from %@; keeping the quick terminal closed.", self.serviceTarget, self.sourcePlist);
      return NO;
    }
  }
  if (Run(@"/bin/launchctl", @[@"bootout", self.serviceTarget], NULL) != 0 && [self serviceLoaded]) {
    [[NSFileManager defaultManager] removeItemAtPath:self.recoveryFile error:NULL];
    NSLog(@"Could not stop SketchyVim; keeping the quick terminal closed.");
    return NO;
  }
  // Removing the launchd job is not sufficient if its old process is still
  // shutting down. Do not expose the panel until the interceptor has exited.
  NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 2;
  while (pid > 0 && (kill(pid, 0) == 0 || errno != ESRCH)) {
    if (NSProcessInfo.processInfo.systemUptime >= deadline) {
      NSLog(@"SketchyVim has not exited; keeping the quick terminal closed.");
      return NO;
    }
    [NSThread sleepForTimeInterval:0.01];
  }
  NSString *hook = [NSHomeDirectory() stringByAppendingPathComponent:@".config/svim/svim.sh"];
  Run(@"/bin/sh", @[hook, @"--stop"], NULL);
  NSLog(@"SketchyVim stopped before opening the quick terminal.");
  return YES;
}

- (void)restoreService {
  if ([self manuallyStopped]) { if (self.stopping) [NSApp terminate:nil]; return; }
  if (![self hasRecovery]) { if (self.stopping) [NSApp terminate:nil]; return; }
  if (![self serviceLoaded]) {
    NSString *domain = [NSString stringWithFormat:@"gui/%u", getuid()];
    if (Run(@"/bin/launchctl", @[@"bootstrap", domain, self.recoveryFile], NULL) != 0) {
      NSLog(@"SketchyVim restore failed; retaining recovery.plist and retrying.");
      return;
    }
  }
  self.restoring = YES;
  self.restoreDeadline = NSProcessInfo.processInfo.systemUptime + 5;
}

- (BOOL)serviceReady {
  pid_t pid = [self servicePID];
  if (!pid) return NO;
  uint32_t count = 0;
  if (CGGetEventTapList(0, NULL, &count) != kCGErrorSuccess || !count) return NO;
  CGEventTapInformation *taps = calloc(count, sizeof(*taps));
  BOOL ready = NO;
  if (CGGetEventTapList(count, taps, &count) == kCGErrorSuccess) {
    for (uint32_t i = 0; i < count; i++) if (taps[i].tappingProcess == pid && taps[i].enabled) ready = YES;
  }
  free(taps);
  return ready;
}

- (void)finishRestore {
  // A windowless activate request can be ignored. Give the accessory app an
  // offscreen key window, then wait for actual NSWorkspace notifications. The
  // service isn't restored until a non-helper app has really become active.
  self.waitingForActivation = YES;
  self.restoreDeadline = NSProcessInfo.processInfo.systemUptime + 3;
  NSLog(@"SketchyVim keyboard handler ready; initializing app focus.");
  self.returnApp = NSWorkspace.sharedWorkspace.frontmostApplication;
  if (!self.focusWindow) {
    self.focusWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, 1, 1)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    self.focusWindow.alphaValue = 0;
    self.focusWindow.releasedWhenClosed = NO;
    self.focusWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    [self.focusWindow setAccessibilityElement:NO];
  }
  [self.focusWindow makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationActivated:(NSNotification *)notification {
  if (!self.waitingForActivation) return;
  NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
  if (!app) return;
  if (app.processIdentifier == getpid()) {
    NSLog(@"Helper activation confirmed; returning focus.");
    dispatch_async(dispatch_get_main_queue(), ^{
      if (!self.waitingForActivation || !NSApp.active) return;
      if (!self.returnApp || self.returnApp.terminated || self.returnApp.processIdentifier == getpid()
          || ![self.returnApp activateWithOptions:NSApplicationActivateIgnoringOtherApps]) {
        [NSApp hide:nil];
      }
    });
    return;
  }
  [self completeRestore];
}

- (void)completeRestore {
  // This is the same activation SketchyVim receives to refresh its blacklist.
  [self.focusWindow orderOut:nil];
  self.returnApp = nil;
  self.waitingForActivation = NO;
  self.restoring = NO;
  [[NSFileManager defaultManager] removeItemAtPath:self.recoveryFile error:NULL];
  NSLog(@"SketchyVim restored; app activation confirmed.");
  if (self.stopping) [NSApp terminate:nil];
}

- (BOOL)pressMenu {
  AXError error = AXUIElementPerformAction((__bridge AXUIElementRef)self.menu, kAXPressAction);
  if (error != kAXErrorSuccess) NSLog(@"Quick Terminal menu action failed (%d).", error);
  return error == kAXErrorSuccess;
}

- (void)toggle {
  NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
  if (self.toggling || self.polling || self.stopping || self.restoring || self.waitingForOpen || now - self.lastHotkey < 0.3) return;
  self.lastHotkey = now;
  NSLog(@"Cmd+` received.");
  // NSTask.waitUntilExit pumps the run loop. The timer must not interpret the
  // saved recovery file as a dismissed panel while bootout/AXPress is running.
  self.toggling = YES;
  @try {
    if (![self connect]) { NSLog(@"Open Ghostty first; its Quick Terminal menu is unavailable."); NSBeep(); return; }
    NSInteger visible = [self visibility];
    if (visible < 0) { NSLog(@"Cannot read quick-terminal visibility; leaving the service alone."); NSBeep(); return; }
    NSTimeInterval stopStarted = NSProcessInfo.processInfo.systemUptime;
    if (visible == 0 && ![self pauseService]) { NSBeep(); return; }
    NSTimeInterval stopped = NSProcessInfo.processInfo.systemUptime;
    [self pressMenu];
    // The action may have reached Ghostty despite an AX timeout; poll actual
    // visibility before deciding it is safe to restart SketchyVim.
    self.waitingForOpen = visible == 0;
    self.sawOpen = visible == 1;
    self.openDeadline = NSProcessInfo.processInfo.systemUptime + 5;
    NSLog(@"Toggle requested: lookup %.0f ms, service stop %.0f ms, menu action %.0f ms.",
        (stopStarted - now) * 1000, (stopped - stopStarted) * 1000,
        (NSProcessInfo.processInfo.systemUptime - stopped) * 1000);
  } @finally {
    self.toggling = NO;
  }
}

- (void)poll {
  if (self.toggling || self.polling) return;
  self.polling = YES;
  @try {
    [self handleControlRequest];
    [self pollState];
  } @finally {
    self.polling = NO;
  }
}

- (void)pollState {
  if (self.restoring) {
    if (self.waitingForActivation) {
      if (NSProcessInfo.processInfo.systemUptime > self.restoreDeadline) {
        // Never leave a transparent helper window holding keyboard focus.
        [self.focusWindow orderOut:nil];
        if (NSApp.active) [NSApp hide:nil];
        self.restoreDeadline = NSProcessInfo.processInfo.systemUptime + 30;
        NSLog(@"SketchyVim is running; waiting for an app switch to initialize its blacklist.");
      }
    } else if ([self serviceReady]) [self finishRestore];
    else if (NSProcessInfo.processInfo.systemUptime > self.restoreDeadline) {
      self.restoring = NO;
      NSLog(@"Waiting for SketchyVim's keyboard handler; recovery state retained.");
    }
    return;
  }
  if (![self hasRecovery] && !self.waitingForOpen && !self.sawOpen && !self.stopping) return;
  NSInteger visible = [self visibility];
  if (visible < 0) return;
  if (visible == 1) {
    self.waitingForOpen = NO;
    self.sawOpen = YES;
    if (self.stopping && [Attribute((__bridge AXUIElementRef)self.menu, kAXMenuItemMarkCharAttribute, NULL) length]) [self pressMenu];
    return;
  }
  if (self.waitingForOpen && NSProcessInfo.processInfo.systemUptime < self.openDeadline) return;
  self.waitingForOpen = NO;
  self.sawOpen = NO;
  [self restoreService];
}
@end

static OSStatus Hotkey(EventHandlerCallRef next, EventRef event, void *context) {
  (void)next; (void)event;
  [(__bridge QuickTerminal *)context toggle];
  return noErr;
}

#ifndef TERMINAL_TOGGLE_TEST
static int Control(NSString *directory, NSString *action) {
  NSString *target = [NSString stringWithFormat:@"gui/%u/com.ssemakov.terminal-toggle", getuid()];
  if (Run(@"/bin/launchctl", @[@"print", target], NULL) != 0) {
    fprintf(stderr, "Terminal Toggle is not running. Run ~/.config/svim/terminal-toggle.sh --install first.\n");
    return 1;
  }
  int lock = open([[directory stringByAppendingPathComponent:@"control.lock"] fileSystemRepresentation], O_CREAT | O_RDWR, 0600);
  if (lock < 0 || flock(lock, LOCK_EX | LOCK_NB) != 0) {
    if (lock >= 0) close(lock);
    fprintf(stderr, "Another SketchyVim command is running; retry shortly.\n");
    return 1;
  }
  NSString *identifier = NSUUID.UUID.UUIDString;
  NSDictionary *request = @{@"id": identifier, @"action": action};
  NSString *requestFile = [directory stringByAppendingPathComponent:@"control-request.plist"];
  if (![request writeToFile:requestFile atomically:YES]) {
    close(lock);
    fprintf(stderr, "Could not send the SketchyVim command.\n");
    return 1;
  }
  NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 8;
  while (NSProcessInfo.processInfo.systemUptime < deadline) {
    NSDictionary *result = [NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:@"control-result.plist"]];
    if ([result[@"id"] isEqual:identifier]) {
      BOOL success = [result[@"success"] boolValue];
      fprintf(success ? stdout : stderr, "%s\n", [result[@"message"] UTF8String]);
      close(lock);
      return success ? 0 : 1;
    }
    [NSThread sleepForTimeInterval:0.05];
  }
  close(lock);
  fprintf(stderr, "Terminal Toggle did not respond; the command may still be pending. Check its Accessibility permission and helper.log.\n");
  return 1;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    umask(077);
    if (argc != 3) { fprintf(stderr, "Usage: terminal-toggle CACHE_DIR --run|--check|--reload|--svim-stop|--svim-start\n"); return 2; }
    NSString *mode = @(argv[2]);
    if ([mode isEqual:@"--svim-stop"] || [mode isEqual:@"--svim-start"]) {
      return Control(@(argv[1]), [mode isEqual:@"--svim-stop"] ? @"stop" : @"start");
    }
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    if (!AXIsProcessTrusted()) {
      if (![mode isEqual:@"--run"]) {
        NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
        NSLog(@"Accessibility permission is missing. After a rebuild, remove the old Terminal Toggle entry and add the current app again.");
        return 1;
      }
      // Do not exit and let KeepAlive produce a new permission prompt every
      // ten seconds. This process stays idle and checks silently for a grant.
      NSLog(@"Waiting silently for Accessibility permission. Remove any stale Terminal Toggle entry and add this app again: %@",
          NSBundle.mainBundle.bundlePath);
      NSTimer *permissionTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        if (AXIsProcessTrusted()) CFRunLoopStop(CFRunLoopGetMain());
      }];
      CFRunLoopRun();
      [permissionTimer invalidate];
      NSLog(@"Accessibility permission granted.");
    }
    QuickTerminal *helper = [QuickTerminal new];
    helper.directory = @(argv[1]);
    helper.recoveryFile = [helper.directory stringByAppendingPathComponent:@"recovery.plist"];
    if ([mode isEqual:@"--check"] || [mode isEqual:@"--reload"]) {
      if (![helper connect]) { NSLog(@"Ghostty Quick Terminal menu unavailable."); return 1; }
      if ([mode isEqual:@"--check"]) {
        NSLog(@"Accessibility available; quick terminal visibility=%ld (0=closed, 1=open, -1=unknown)", (long)[helper visibility]);
        return [helper visibility] < 0 ? 1 : 0;
      }
      AXUIElementRef app = AXUIElementCreateApplication(helper.ghostty.processIdentifier);
      id bar = Attribute(app, kAXMenuBarAttribute, NULL);
      id reload = bar ? FindMenu((__bridge AXUIElementRef)bar, @"Reload Configuration", 5) : nil;
      AXError error = reload ? AXUIElementPerformAction((__bridge AXUIElementRef)reload, kAXPressAction) : kAXErrorFailure;
      CFRelease(app);
      return error == kAXErrorSuccess ? 0 : 1;
    }
    if (![mode isEqual:@"--run"]) return 2;
    int lock = open([[helper.directory stringByAppendingPathComponent:@"helper.lock"] fileSystemRepresentation], O_CREAT | O_RDWR, 0600);
    if (lock < 0 || flock(lock, LOCK_EX | LOCK_NB) != 0) { NSLog(@"Helper already running or lock unavailable."); return 1; }
    [helper discoverService];
    if ([helper hasRecovery] && !helper.serviceTarget) { NSLog(@"Invalid recovery.plist; inspect it before restarting."); return 1; }
    // A reboot can reload the original Homebrew service while recovery state
    // still exists. Keep it stopped if Ghostty restored an open quick terminal.
    if (([helper manuallyStopped] || ([helper hasRecovery] && [helper visibility] != 0)) && ![helper pauseService]) return 1;
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:helper selector:@selector(applicationActivated:)
        name:NSWorkspaceDidActivateApplicationNotification object:nil];
    EventTypeSpec event = {kEventClassKeyboard, kEventHotKeyPressed};
    InstallApplicationEventHandler(Hotkey, 1, &event, (__bridge void *)helper, NULL);
    EventHotKeyRef key;
    OSStatus error = RegisterEventHotKey(kVK_ANSI_Grave, cmdKey, (EventHotKeyID){'SVQT', 1}, GetApplicationEventTarget(), 0, &key);
    if (error != noErr) { NSLog(@"Could not register Cmd+` (%d). Reload Ghostty's config first.", (int)error); return 1; }
    NSMutableArray *signals = [NSMutableArray new];
    for (NSNumber *number in @[@(SIGTERM), @(SIGINT)]) {
      signal(number.intValue, SIG_IGN);
      dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, number.intValue, 0, dispatch_get_main_queue());
      dispatch_source_set_event_handler(source, ^{ helper.stopping = YES; [helper poll]; });
      dispatch_resume(source);
      [signals addObject:source];
    }
    // Pay for menu discovery once at startup instead of on the first shortcut.
    [helper connect];
    helper.timer = [NSTimer scheduledTimerWithTimeInterval:0.15 repeats:YES block:^(NSTimer *timer) { (void)timer; [helper poll]; }];
    [helper poll];
    NSLog(@"Ready: Cmd+` toggles Ghostty with SketchyVim paused.");
    [NSApp run];
    (void)signals;
  }
  return 0;
}
#endif
