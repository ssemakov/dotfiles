// A nonactivating, click-through HUD driven by SketchyVim's svim.sh hook.
#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#include <fcntl.h>
#include <math.h>
#include <sys/file.h>
#include <unistd.h>

@interface OverlayState : NSObject
@property(nonatomic, copy) NSString *mode;
@property(nonatomic, copy) NSString *commandType;
@property(nonatomic, copy) NSString *commandLine;
@property(nonatomic, readonly) BOOL commandActive;
@property(nonatomic, readonly) BOOL searching;
@property(nonatomic, readonly) NSString *title;
@property(nonatomic, readonly) NSColor *accent;
+ (instancetype)fromRecord:(NSString *)record;
- (BOOL)hasSameContent:(OverlayState *)other;
@end

@implementation OverlayState
+ (instancetype)fromRecord:(NSString *)record {
  OverlayState *state = [self new];
  NSRange separator = [record rangeOfString:@"\n"];
  state.mode = separator.location == NSNotFound ? record : [record substringToIndex:separator.location];
  state.commandType = @"";
  state.commandLine = @"";
  if (state.commandActive && separator.location != NSNotFound) {
    NSString *payload = [record substringFromIndex:NSMaxRange(separator)];
    separator = [payload rangeOfString:@"\n"];
    if (separator.location != NSNotFound) {
      NSString *type = [payload substringToIndex:separator.location];
      if ([@[@":", @"/", @"?"] containsObject:type]) state.commandType = type;
      state.commandLine = [payload substringFromIndex:NSMaxRange(separator)];
    }
  }
  return state;
}
- (BOOL)commandActive { return [self.mode isEqualToString:@"C"]; }
- (BOOL)searching { return [@[@"/", @"?"] containsObject:self.commandType]; }
- (NSString *)title {
  if (self.commandActive) {
    if ([self.commandType isEqualToString:@"/"]) return @"SEARCH FORWARD";
    if ([self.commandType isEqualToString:@"?"]) return @"SEARCH BACKWARD";
    return [self.commandType isEqualToString:@":"] ? @"COMMAND" : @"COMMAND / SEARCH";
  }
  return @{@"N": @"NORMAL", @"I": @"INSERT", @"V": @"VISUAL", @"_": @"OTHER"}[self.mode];
}
- (NSColor *)accent {
  if (self.commandActive) {
    if ([self.commandType isEqualToString:@":"]) return NSColor.systemOrangeColor;
    return [NSColor colorWithSRGBRed:210.0/255 green:180.0/255 blue:140.0/255 alpha:1];
  }
  return @{@"N": NSColor.systemGreenColor, @"I": NSColor.systemBlueColor,
      @"V": NSColor.systemPurpleColor, @"_": NSColor.systemGrayColor}[self.mode];
}
- (BOOL)hasSameContent:(OverlayState *)other {
  return other && [self.mode isEqualToString:other.mode]
      && [self.commandType isEqualToString:other.commandType]
      && [self.commandLine isEqualToString:other.commandLine];
}
@end

static void DrawText(NSString *text, NSRect rect, NSFont *font, NSColor *color,
    NSLineBreakMode lineBreak, NSTextAlignment alignment) {
  NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
  paragraph.lineBreakMode = lineBreak;
  paragraph.alignment = alignment;
  [text drawInRect:rect withAttributes:@{NSFontAttributeName: font,
      NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: paragraph}];
}

@interface OverlayView : NSView
@property(nonatomic, strong) OverlayState *state;
@end

@implementation OverlayView
- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirtyRect {
  (void)dirtyRect;
  OverlayState *state = self.state;
  NSRect bounds = self.bounds;
  NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5)
      xRadius:state.commandActive ? 14 : 12 yRadius:state.commandActive ? 14 : 12];
  [[NSColor colorWithWhite:0.10 alpha:0.96] setFill];
  [background fill];
  [[state.accent colorWithAlphaComponent:state.commandActive ? 0.45 : 0.20] setStroke];
  [background stroke];

  [state.accent setFill];
  if (!state.commandActive) {
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(18, 16, 10, 10)] fill];
    DrawText(state.title ?: @"", NSMakeRect(40, 11, bounds.size.width - 50, 20),
      [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightSemibold], NSColor.whiteColor,
      NSLineBreakByClipping, NSTextAlignmentLeft);
    return;
  }

  [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(18, 80, 7, 7)] fill];
  DrawText(state.title, NSMakeRect(34, 75, bounds.size.width - 52, 17),
      [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold], state.accent,
      NSLineBreakByClipping, NSTextAlignmentLeft);

  DrawText(state.commandType.length ? state.commandType : @"›", NSMakeRect(18, 37, 20, 28),
      [NSFont monospacedSystemFontOfSize:19 weight:NSFontWeightMedium], state.accent,
      NSLineBreakByClipping, NSTextAlignmentLeft);
  // Keep the input on one line, showing whitespace controls visibly. Preserve
  // actual spaces and Unicode, and keep the newest text visible in long queries.
  NSString *text = [[state.commandLine stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"]
      stringByReplacingOccurrencesOfString:@"\t" withString:@"⇥"];
  text = [text stringByReplacingOccurrencesOfString:@"\r" withString:@"↵"];
  BOOL empty = text.length == 0;
  if (empty) text = state.searching ? @"Type your search…"
      : [state.commandType isEqualToString:@":"] ? @"Type a command…" : @"Type a command or search…";
  DrawText(text, NSMakeRect(42, 37, bounds.size.width - 60, 28),
      [NSFont monospacedSystemFontOfSize:18 weight:NSFontWeightRegular],
      [NSColor colorWithWhite:1 alpha:empty ? 0.38 : 0.95],
      NSLineBreakByTruncatingHead, NSTextAlignmentLeft);

  NSString *hint = state.searching ? @"Enter ↵ search     Esc cancel"
      : [state.commandType isEqualToString:@":"] ? @"Enter ↵ run     Esc cancel" : @"Enter ↵ confirm     Esc cancel";
  DrawText(hint, NSMakeRect(18, 13, bounds.size.width - 36, 15),
      [NSFont systemFontOfSize:11 weight:NSFontWeightRegular], [NSColor colorWithWhite:1 alpha:0.48],
      NSLineBreakByClipping, NSTextAlignmentRight);
}
@end

@interface ModeOverlay : NSObject
@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) OverlayView *view;
@property(nonatomic, strong) NSTimer *hideTimer;
@property(nonatomic, strong) NSScreen *displayScreen;
@property(nonatomic, copy) NSString *statePath;
@property(nonatomic) NSTimeInterval duration;
- (instancetype)initWithDirectory:(NSString *)directory;
- (NSRect)screenFrameContinuingCommand:(BOOL)continuingCommand;
- (void)update;
@end

@implementation ModeOverlay
- (instancetype)initWithDirectory:(NSString *)directory {
  if (!(self = [super init])) return nil;
  self.statePath = [directory stringByAppendingPathComponent:@"mode"];
  double duration = [NSProcessInfo.processInfo.environment[@"SVIM_OVERLAY_DURATION"] doubleValue];
  self.duration = isfinite(duration) && duration > 0 ? duration : 0.9;
  self.panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 156, 42)
      styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
      backing:NSBackingStoreBuffered defer:NO];
  self.panel.level = NSStatusWindowLevel;
  self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
      | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorIgnoresCycle;
  self.panel.opaque = NO;
  self.panel.backgroundColor = NSColor.clearColor;
  self.panel.hasShadow = YES;
  self.panel.ignoresMouseEvents = YES;
  self.panel.hidesOnDeactivate = NO;
  self.panel.releasedWhenClosed = NO;
  self.panel.title = @"SketchyVim mode";
  self.view = [[OverlayView alloc] initWithFrame:self.panel.contentView.bounds];
  self.panel.contentView = self.view;
  return self;
}

- (NSRect)screenFrameContinuingCommand:(BOOL)continuingCommand {
  // Pin the command bar to its initial display while typing.
  if (!continuingCommand || ![NSScreen.screens containsObject:self.displayScreen]) {
    self.displayScreen = NSScreen.mainScreen;
    for (NSScreen *candidate in NSScreen.screens) {
      if (!NSPointInRect(NSEvent.mouseLocation, candidate.frame)) continue;
      self.displayScreen = candidate;
      break;
    }
  }
  return self.displayScreen ? self.displayScreen.visibleFrame : NSZeroRect;
}

- (void)update {
  NSString *record = [NSString stringWithContentsOfFile:self.statePath encoding:NSUTF8StringEncoding error:nil];
  if (!record) return;
  OverlayState *state = [OverlayState fromRecord:record];
  if ([state.mode isEqualToString:@"stop"]) { [NSApp terminate:nil]; return; }
  if ([state hasSameContent:self.view.state]) return;
  BOOL continuingCommand = state.commandActive && self.view.state.commandActive;
  self.view.state = state;
  [self.hideTimer invalidate];
  self.hideTimer = nil;
  if (!state.title) { [self.panel orderOut:nil]; return; }

  NSRect screen = [self screenFrameContinuingCommand:continuingCommand];
  if (NSIsEmptyRect(screen)) return;
  CGFloat width = state.commandActive ? MIN(420, screen.size.width - 32) : 156;
  CGFloat height = state.commandActive ? 104 : 42;
  [self.panel setFrame:NSMakeRect(NSMidX(screen) - width / 2, NSMinY(screen) + 48, width, height) display:NO];
  self.view.needsDisplay = YES;
  [self.panel orderFrontRegardless];

  // Command/search text stays visible until SketchyVim leaves command mode.
  if (!state.commandActive) {
    __weak ModeOverlay *weakSelf = self;
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:self.duration repeats:NO block:^(NSTimer *timer) {
      (void)timer;
      [weakSelf.panel orderOut:nil];
      weakSelf.hideTimer = nil;
    }];
  }
}
@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc != 2) return 2;
    NSString *directory = [NSString stringWithUTF8String:argv[1]];
    NSString *lockPath = [directory stringByAppendingPathComponent:@"overlay.lock"];
    int lockFD = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
    if (lockFD == -1) { perror("overlay lock"); return 1; }
    if (flock(lockFD, LOCK_EX | LOCK_NB) != 0) { close(lockFD); return 0; }
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    if (NSScreen.screens.count == 0) {
      fputs("SketchyVim overlay needs access to a macOS graphical session.\n", stderr);
      return 1;
    }
    ModeOverlay *overlay = [[ModeOverlay alloc] initWithDirectory:directory];
    int directoryFD = open(directory.fileSystemRepresentation, O_EVTONLY);
    if (directoryFD == -1) { perror("overlay directory"); return 1; }
    dispatch_source_t changes = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
        directoryFD, DISPATCH_VNODE_WRITE, dispatch_get_main_queue());
    if (!changes) return 1;
    dispatch_source_set_event_handler(changes, ^{ [overlay update]; });
    dispatch_source_set_cancel_handler(changes, ^{ close(directoryFD); });
    dispatch_resume(changes);
    dispatch_async(dispatch_get_main_queue(), ^{ [overlay update]; });
    [NSApp run];
    dispatch_source_cancel(changes);
    close(lockFD);
  }
  return 0;
}
