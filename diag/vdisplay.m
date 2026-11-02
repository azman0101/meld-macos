// Crée un second écran virtuel (CGVirtualDisplay, API privée de CoreGraphics)
// et le garde tant que le processus tourne.
//
//   vdisplay <largeur> <hauteur> <secondes>
//
// Sert aux tests de déplacement de fenêtre entre écrans sur les runners, qui
// n'ont qu'un écran. Écrit « display id N » en cas de succès.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

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

int main(int argc, char **argv) {
  @autoreleasepool {
    unsigned int w = (unsigned int)atoi(argv[1]), h = (unsigned int)atoi(argv[2]);
    double seconds = atof(argv[3]);
    CGVirtualDisplayDescriptor *d = [CGVirtualDisplayDescriptor new];
    d.name = @"Test display";
    d.maxPixelsWide = w;
    d.maxPixelsHigh = h;
    d.sizeInMillimeters = CGSizeMake(w * 0.26, h * 0.26);
    d.productID = 0x1234;
    d.vendorID = 0x3456;
    d.serialNum = 1;
    d.queue = dispatch_get_main_queue();
    CGVirtualDisplay *v = [[CGVirtualDisplay alloc] initWithDescriptor:d];
    if (!v) { printf("échec : CGVirtualDisplay indisponible\n"); return 1; }
    CGVirtualDisplaySettings *s = [CGVirtualDisplaySettings new];
    s.hiDPI = 0;
    s.modes = @[[[CGVirtualDisplayMode alloc] initWithWidth:w height:h refreshRate:60]];
    if (![v applySettings:s]) { printf("échec : applySettings\n"); return 1; }
    printf("display id %u\n", v.displayID);
    fflush(stdout);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
  }
  return 0;
}
