// Crée un second écran virtuel (CGVirtualDisplay, API privée de CoreGraphics)
// et le garde tant que le processus tourne.
//
//   vdisplay <largeur> <hauteur> <secondes> [échelle 1|2]
//
// Sert aux tests de déplacement de fenêtre entre écrans sur les runners, qui
// n'ont qu'un écran. Écrit « display id N » en cas de succès.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(unsigned int)w height:(unsigned int)h refreshRate:(double)r;
@end

@interface CGVirtualDisplaySettings : NSObject
@property(nonatomic) unsigned int hiDPI;
@property(retain, nonatomic) NSArray *modes;
@end

@interface CGVirtualDisplayDescriptor : NSObject
@property(retain, nonatomic) NSString *name;
@property(nonatomic) unsigned int maxPixelsWide;
@property(nonatomic) unsigned int maxPixelsHigh;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) unsigned int productID;
@property(nonatomic) unsigned int vendorID;
@property(nonatomic) unsigned int serialNum;
@property(retain, nonatomic) dispatch_queue_t queue;
@end

@interface CGVirtualDisplay : NSObject
@property(readonly, nonatomic) CGDirectDisplayID displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)d;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)s;
@end

static CGVirtualDisplay *make(unsigned int w, unsigned int h, int scale, int variant) {
  CGVirtualDisplayDescriptor *d = [CGVirtualDisplayDescriptor new];
  d.name = @"Test display";
  d.maxPixelsWide = w * scale;
  d.maxPixelsHigh = h * scale;
  d.sizeInMillimeters = CGSizeMake(w * 0.26, h * 0.26);
  d.productID = 0x1234;
  d.vendorID = 0x3456;
  d.serialNum = 1;
  d.queue = dispatch_get_main_queue();
  CGVirtualDisplay *v = [[CGVirtualDisplay alloc] initWithDescriptor:d];
  if (!v) return nil;
  CGVirtualDisplaySettings *s = [CGVirtualDisplaySettings new];
  s.hiDPI = scale > 1;
  // variante 0 : mode en points ; variante 1 : mode en pixels
  unsigned int mw = variant == 0 ? w : w * scale, mh = variant == 0 ? h : h * scale;
  s.modes = @[[[CGVirtualDisplayMode alloc] initWithWidth:mw height:mh refreshRate:60]];
  if (![v applySettings:s]) return nil;
  return v;
}

static double scale_of(CGDirectDisplayID id) {
  for (NSScreen *sc in [NSScreen screens]) {
    if ([sc.deviceDescription[@"NSScreenNumber"] unsignedIntValue] == id) return sc.backingScaleFactor;
  }
  return 0;
}

// Un écran virtuel HiDPI offre un mode « looks like w x h » en 2x à côté du
// mode en pixels : il faut le sélectionner pour que l'écran passe en 2x.
static BOOL select_hidpi(CGDirectDisplayID id, unsigned int w) {
  const void *keys[] = { kCGDisplayShowDuplicateLowResolutionModes };
  const void *vals[] = { kCFBooleanTrue };
  CFDictionaryRef opts = CFDictionaryCreate(NULL, keys, vals, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFArrayRef modes = CGDisplayCopyAllDisplayModes(id, opts);
  CFRelease(opts);
  CGDisplayModeRef pick = NULL;
  for (CFIndex i = 0; modes && i < CFArrayGetCount(modes); i++) {
    CGDisplayModeRef m = (CGDisplayModeRef)CFArrayGetValueAtIndex(modes, i);
    printf("  mode %zux%zu, pixels %zux%zu\n", CGDisplayModeGetWidth(m), CGDisplayModeGetHeight(m),
           CGDisplayModeGetPixelWidth(m), CGDisplayModeGetPixelHeight(m));
    if (CGDisplayModeGetWidth(m) == w && CGDisplayModeGetPixelWidth(m) == 2 * w) pick = m;
  }
  BOOL ok = NO;
  if (pick) {
    CGDisplayConfigRef cfg;
    if (CGBeginDisplayConfiguration(&cfg) == kCGErrorSuccess) {
      CGConfigureDisplayWithDisplayMode(cfg, id, pick, NULL);
      ok = CGCompleteDisplayConfiguration(cfg, kCGConfigureForSession) == kCGErrorSuccess;
    }
  } else {
    printf("  pas de mode %ux? en 2x\n", w);
  }
  if (modes) CFRelease(modes);
  return ok;
}

int main(int argc, char **argv) {
  setvbuf(stdout, NULL, _IONBF, 0);  // le script lit le journal pendant l'exécution
  @autoreleasepool {
    unsigned int w = (unsigned int)atoi(argv[1]), h = (unsigned int)atoi(argv[2]);
    double seconds = atof(argv[3]);
    int scale = argc > 4 ? atoi(argv[4]) : 1;
    CGVirtualDisplay *v = nil;
    // variante 1 : modes en pixels (puis sélection du mode 2x), variante 0 : modes en points
    for (int variant = (scale > 1 ? 1 : 0); variant >= 0; variant--) {
      v = make(w, h, scale, variant);
      if (!v) { printf("échec : CGVirtualDisplay indisponible\n"); return 1; }
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4]];
      double got = scale_of(v.displayID);
      printf("variante %d : display id %u, échelle %.0f\n", variant, v.displayID, got);
      if (scale > 1 && (int)got != scale) {
        printf("  sélection du mode 2x : %s\n", select_hidpi(v.displayID, w) ? "demandée" : "impossible");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4]];
        got = scale_of(v.displayID);
        printf("  échelle après sélection : %.0f\n", got);
      }
      if ((int)got == scale || scale == 1) break;
      v = nil;  // libère l'écran avant d'essayer l'autre variante
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];
    }
    if (!v) { printf("échec : échelle %d indisponible\n", scale); return 1; }
    printf("display id %u\n", v.displayID);
    fflush(stdout);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
  }
  return 0;
}
