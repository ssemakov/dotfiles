// A nonactivating, click-through HUD driven by SketchyVim's svim.sh hook.
#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#include <fcntl.h>
#include <math.h>
#include <sys/file.h>
#include <unistd.h>

@interface ModeOverlay : NSObject
@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) NSTextField *label;
@property(nonatomic, strong) NSView *dot;
@property(nonatomic, strong) NSTimer *hideTimer;
@property(nonatomic, copy) NSString *statePath;
@property(nonatomic, copy) NSString *lastMode;
@property(nonatomic) NSTimeInterval duration;
- (instancetype)initWithDirectory:(NSString *)directory;
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
      | NSWindowCollectionBehaviorFullScreenAuxiliary
      | NSWindowCollectionBehaviorIgnoresCycle;
  self.panel.opaque = NO;
  self.panel.backgroundColor = NSColor.clearColor;
  self.panel.hasShadow = YES;
  self.panel.ignoresMouseEvents = YES;
  self.panel.hidesOnDeactivate = NO;
  self.panel.releasedWhenClosed = NO;
  self.panel.title = @"SketchyVim mode";

  NSView *content = self.panel.contentView;
  content.wantsLayer = YES;
  content.layer.cornerRadius = 12;
  content.layer.backgroundColor = [NSColor colorWithWhite:0.10 alpha:0.94].CGColor;
  content.layer.borderWidth = 1;
  content.layer.borderColor = [NSColor colorWithWhite:1 alpha:0.12].CGColor;

  self.dot = [[NSView alloc] initWithFrame:NSMakeRect(18, 16, 10, 10)];
  self.dot.wantsLayer = YES;
  self.dot.layer.cornerRadius = 5;
  [content addSubview:self.dot];

  self.label = [NSTextField labelWithString:@""];
  self.label.frame = NSMakeRect(40, 11, 106, 20);
  self.label.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightSemibold];
  self.label.textColor = NSColor.whiteColor;
  [content addSubview:self.label];
  return self;
}

- (void)update {
  NSString *raw = [NSString stringWithContentsOfFile:self.statePath
      encoding:NSUTF8StringEncoding error:nil];
  if (!raw) return;
  NSString *mode = [raw stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
  if ([mode isEqualToString:@"stop"]) {
    [NSApp terminate:nil];
    return;
  }
  // SketchyVim also calls the hook while editing its command line.
  if ([mode isEqualToString:self.lastMode]) return;
  self.lastMode = mode;
  [self.hideTimer invalidate];
  self.hideTimer = nil;

  NSDictionary *labels = @{@"N": @"NORMAL", @"I": @"INSERT", @"V": @"VISUAL",
                            @"C": @"COMMAND", @"_": @"OTHER"};
  NSString *label = labels[mode];
  if (!label) {
    [self.panel orderOut:nil];
    return;
  }
  NSDictionary *colors = @{@"N": NSColor.systemGreenColor, @"I": NSColor.systemBlueColor,
      @"V": NSColor.systemPurpleColor, @"C": NSColor.systemOrangeColor,
      @"_": NSColor.systemGrayColor};
  self.label.stringValue = label;
  self.dot.layer.backgroundColor = ((NSColor *)colors[mode]).CGColor;

  // Place it on the display containing the pointer, above the Dock.
  NSScreen *screen = NSScreen.mainScreen;
  NSPoint pointer = NSEvent.mouseLocation;
  for (NSScreen *candidate in NSScreen.screens) {
    if (NSPointInRect(pointer, candidate.frame)) {
      screen = candidate;
      break;
    }
  }
  if (!screen) return;
  NSRect frame = screen.visibleFrame;
  [self.panel setFrameOrigin:NSMakePoint(NSMidX(frame) - self.panel.frame.size.width / 2,
                                        NSMinY(frame) + 48)];
  [self.panel orderFrontRegardless];
  self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:self.duration repeats:NO
      block:^(NSTimer *timer) {
        (void)timer;
        [self.panel orderOut:nil];
      }];
}
@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc != 2) return 2;
    NSString *directory = [NSString stringWithUTF8String:argv[1]];
    NSString *lockPath = [directory stringByAppendingPathComponent:@"overlay.lock"];
    int lockFD = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
    if (lockFD == -1) { perror("overlay lock"); return 1; }
    if (flock(lockFD, LOCK_EX | LOCK_NB) != 0) {
      close(lockFD);
      return 0;
    }

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    if (NSScreen.screens.count == 0) {
      fputs("SketchyVim overlay needs access to a macOS graphical session.\n", stderr);
      return 1;
    }
    ModeOverlay *overlay = [[ModeOverlay alloc] initWithDirectory:directory];
    int directoryFD = open(directory.fileSystemRepresentation, O_EVTONLY);
    if (directoryFD == -1) { perror("overlay directory"); return 1; }
    // Watch the directory because each mode write replaces the file atomically.
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
