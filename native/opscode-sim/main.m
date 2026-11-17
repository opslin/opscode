// opscode-sim: touches, keys and hardware buttons for an iOS Simulator, sent
// straight to the simulated device (no Simulator.app window, no Accessibility
// permission). Written for Opscode.
//
// It loads Xcode's private CoreSimulator + SimulatorKit at run time and uses
// SimulatorKit's own Indigo HID message builders, so the message layout always
// matches the installed Xcode (checked against Xcode 26.6: touch payload x/y
// ratios at +0x3c/+0x44, two payloads per one-finger message).
//
//   opscode-sim check                 -> JSON: can the frameworks load?
//   opscode-sim serve --udid <UDID>   -> JSON lines on stdin/stdout:
//       {"id":1,"cmd":"info"}
//       {"id":2,"cmd":"touch","phase":"down|move|up","x":100,"y":200[,"x2":..,"y2":..]}
//       {"id":3,"cmd":"button","name":"home|lock|side|siri|applepay","phase":"down|up"}
//       {"id":4,"cmd":"key","usage":40,"phase":"down|up"}
//   x/y are device points from the top-left. Answers {"id":n,"ok":true,...} or {"id":n,"ok":false,"error":"..."}.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <stdio.h>

typedef void *(*MouseFn)(CGPoint *, CGPoint *, unsigned int, unsigned long, unsigned long, CGSize);
typedef void *(*ButtonFn)(unsigned int, unsigned int, unsigned int);
typedef void *(*KeyFn)(unsigned int, unsigned int);

static MouseFn gMouse;
static ButtonFn gButton;
static KeyFn gKey;
static id gDevice;
static id gClient;
static CGSize gPoints; // screen size in points

static const unsigned int TARGET_TOUCH = 0x32;
static const unsigned int TARGET_BUTTON = 0x33;

static void emit(NSDictionary *d) {
  NSData *j = [NSJSONSerialization dataWithJSONObject:d options:0 error:nil];
  fwrite(j.bytes, 1, j.length, stdout);
  fputc('\n', stdout);
  fflush(stdout);
}

static NSString *developerDir(void) {
  NSString *env = NSProcessInfo.processInfo.environment[@"DEVELOPER_DIR"];
  if (env.length) return env;
  NSTask *t = [NSTask new];
  t.launchPath = @"/usr/bin/xcode-select";
  t.arguments = @[ @"-p" ];
  NSPipe *p = [NSPipe pipe];
  t.standardOutput = p;
  t.standardError = [NSPipe pipe];
  @try { [t launch]; [t waitUntilExit]; } @catch (NSException *e) { return @"/Applications/Xcode.app/Contents/Developer"; }
  NSString *s = [[NSString alloc] initWithData:[p.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  s = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  return s.length ? s : @"/Applications/Xcode.app/Contents/Developer";
}

/** Loads the frameworks and the message builders; returns an error text or nil. */
static NSString *loadFrameworks(NSString *dev) {
  if (!dlopen("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator", RTLD_NOW | RTLD_GLOBAL))
    return [NSString stringWithFormat:@"CoreSimulator did not load (%s). Is Xcode installed?", dlerror()];
  NSArray *candidates = @[
    [dev stringByAppendingPathComponent:@"Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit"],
    [dev stringByAppendingPathComponent:@"../SharedFrameworks/SimulatorKit.framework/SimulatorKit"],
  ];
  void *sk = NULL;
  for (NSString *c in candidates) { sk = dlopen(c.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL); if (sk) break; }
  if (!sk) return [NSString stringWithFormat:@"SimulatorKit did not load from %@ (%s)", dev, dlerror()];
  gMouse = (MouseFn)dlsym(sk, "IndigoHIDMessageForMouseNSEvent");
  gButton = (ButtonFn)dlsym(sk, "IndigoHIDMessageForButton");
  gKey = (KeyFn)dlsym(sk, "IndigoHIDMessageForKeyboardArbitrary");
  if (!gMouse || !gButton || !gKey) return @"This Xcode's SimulatorKit has no Indigo HID message builders.";
  if (!NSClassFromString(@"_TtC12SimulatorKit24SimDeviceLegacyHIDClient")) return @"This Xcode's SimulatorKit has no HID client.";
  return nil;
}

static NSString *findDevice(NSString *dev, NSString *udid) {
  NSError *err = nil;
  Class ctxC = NSClassFromString(@"SimServiceContext");
  if (!ctxC) return @"CoreSimulator has no SimServiceContext.";
  id ctx = ((id(*)(id, SEL, NSString *, NSError **))objc_msgSend)(ctxC, sel_registerName("sharedServiceContextForDeveloperDir:error:"), dev, &err);
  if (!ctx) return [NSString stringWithFormat:@"No simulator service: %@", err.localizedDescription];
  id set = ((id(*)(id, SEL, NSError **))objc_msgSend)(ctx, sel_registerName("defaultDeviceSetWithError:"), &err);
  if (!set) return [NSString stringWithFormat:@"No device set: %@", err.localizedDescription];
  for (id d in [set valueForKey:@"devices"]) {
    NSUUID *u = [d valueForKey:@"UDID"];
    if ([u.UUIDString caseInsensitiveCompare:udid] == NSOrderedSame) { gDevice = d; break; }
  }
  if (!gDevice) return [NSString stringWithFormat:@"No simulator %@.", udid];
  id type = [gDevice valueForKey:@"deviceType"];
  CGSize px = [[type valueForKey:@"mainScreenSize"] sizeValue];
  float scale = [[type valueForKey:@"mainScreenScale"] floatValue];
  if (scale <= 0) scale = 1;
  gPoints = CGSizeMake(px.width / scale, px.height / scale);
  return nil;
}

static NSString *connectClient(void) {
  NSError *err = nil;
  Class c = NSClassFromString(@"_TtC12SimulatorKit24SimDeviceLegacyHIDClient");
  id obj = ((id(*)(id, SEL))objc_msgSend)(c, sel_registerName("alloc"));
  gClient = ((id(*)(id, SEL, id, NSError **))objc_msgSend)(obj, sel_registerName("initWithDevice:error:"), gDevice, &err);
  if (!gClient) return [NSString stringWithFormat:@"Could not connect to the simulator's input: %@", err.localizedDescription ?: @"unknown error"];
  return nil;
}

/** Sends one message (SimulatorKit frees it) and waits for delivery. */
static NSString *sendMessage(void *msg) {
  if (!msg) return @"could not build the input message";
  __block NSString *failure = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_queue_t q = dispatch_queue_create("opscode.sim.hid", DISPATCH_QUEUE_SERIAL);
  void (^done)(NSError *) = ^(NSError *e) { if (e) failure = e.localizedDescription ?: @"send failed"; dispatch_semaphore_signal(sem); };
  ((void (*)(id, SEL, void *, BOOL, dispatch_queue_t, id))objc_msgSend)(gClient, sel_registerName("sendWithMessage:freeWhenDone:completionQueue:completion:"), msg, YES, q, done);
  if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) return @"the simulator did not take the input within 5 seconds (is it booted?)";
  return failure;
}

static unsigned long phaseOf(NSString *p) {
  if ([p isEqualToString:@"down"]) return 1;      // NSEventTypeLeftMouseDown
  if ([p isEqualToString:@"up"]) return 2;        // NSEventTypeLeftMouseUp
  return 6;                                       // NSEventTypeLeftMouseDragged
}

static NSDictionary *handle(NSDictionary *m) {
  NSString *cmd = m[@"cmd"];
  if ([cmd isEqualToString:@"info"]) {
    return @{ @"ok": @YES, @"name": [gDevice valueForKey:@"name"] ?: @"", @"state": [gDevice valueForKey:@"stateString"] ?: @"", @"width": @(gPoints.width), @"height": @(gPoints.height) };
  }
  if ([cmd isEqualToString:@"touch"]) {
    double x = [m[@"x"] doubleValue], y = [m[@"y"] doubleValue];
    if (!(x >= 0 && y >= 0 && x <= gPoints.width && y <= gPoints.height)) return @{ @"ok": @NO, @"error": [NSString stringWithFormat:@"(%g, %g) is outside the screen (%gx%g points)", x, y, gPoints.width, gPoints.height] };
    CGPoint p = CGPointMake(x, y);
    void *msg;
    if (m[@"x2"] && m[@"y2"]) {
      CGPoint q = CGPointMake([m[@"x2"] doubleValue], [m[@"y2"] doubleValue]);
      msg = gMouse(&p, &q, TARGET_TOUCH, phaseOf(m[@"phase"]), 0, gPoints);
    } else msg = gMouse(&p, NULL, TARGET_TOUCH, phaseOf(m[@"phase"]), [m[@"edge"] unsignedLongValue], gPoints);
    NSString *e = sendMessage(msg);
    return e ? @{ @"ok": @NO, @"error": e } : @{ @"ok": @YES };
  }
  if ([cmd isEqualToString:@"button"]) {
    NSDictionary *src = @{ @"home": @0x0, @"lock": @0x1, @"side": @0xbb8, @"siri": @0x400002, @"applepay": @0x1f4 };
    NSNumber *s = src[m[@"name"]];
    if (!s) return @{ @"ok": @NO, @"error": @"button must be home, lock, side, siri or applepay" };
    NSString *e = sendMessage(gButton(s.unsignedIntValue, [m[@"phase"] isEqualToString:@"up"] ? 2 : 1, TARGET_BUTTON));
    return e ? @{ @"ok": @NO, @"error": e } : @{ @"ok": @YES };
  }
  if ([cmd isEqualToString:@"key"]) {
    unsigned int usage = [m[@"usage"] unsignedIntValue];
    if (usage == 0 || usage > 0xffff) return @{ @"ok": @NO, @"error": @"usage must be a HID keyboard usage code" };
    NSString *e = sendMessage(gKey(usage, [m[@"phase"] isEqualToString:@"up"] ? 2 : 1));
    return e ? @{ @"ok": @NO, @"error": e } : @{ @"ok": @YES };
  }
  return @{ @"ok": @NO, @"error": [NSString stringWithFormat:@"unknown cmd %@", cmd] };
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;
    NSString *dev = developerDir();
    NSString *problem = loadFrameworks(dev);
    if (argc >= 2 && strcmp(argv[1], "check") == 0) {
      emit(problem ? @{ @"ok": @NO, @"error": problem } : @{ @"ok": @YES, @"developer_dir": dev });
      return problem ? 1 : 0;
    }
    NSUInteger at = [args indexOfObject:@"--udid"];
    if (argc < 2 || strcmp(argv[1], "serve") != 0 || at == NSNotFound || at + 1 >= args.count) {
      fprintf(stderr, "usage: opscode-sim check | serve --udid <UDID>\n");
      return 2;
    }
    if (!problem) problem = findDevice(dev, args[at + 1]);
    if (!problem) problem = connectClient();
    if (problem) { emit(@{ @"id": @0, @"ok": @NO, @"error": problem }); return 1; }
    emit(@{ @"id": @0, @"ok": @YES, @"ready": @YES, @"width": @(gPoints.width), @"height": @(gPoints.height) });
    char *line = NULL;
    size_t cap = 0;
    while (getline(&line, &cap, stdin) > 0) {
      @autoreleasepool {
        NSData *d = [NSData dataWithBytes:line length:strlen(line)];
        NSDictionary *m = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (![m isKindOfClass:NSDictionary.class]) { emit(@{ @"id": @(-1), @"ok": @NO, @"error": @"bad JSON" }); continue; }
        NSMutableDictionary *r = [handle(m) mutableCopy];
        r[@"id"] = m[@"id"] ?: @(-1);
        emit(r);
      }
    }
    free(line);
  }
  return 0;
}
