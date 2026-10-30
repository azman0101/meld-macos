// Diagnostic : version de macOS vue par l'app et par le GTK embarqué dans Meld.app.
//
//   gdkver /Applications/Meld.app/Contents/Frameworks/libgdk-3.0.dylib
//
// Le SDK avec lequel ce binaire est lié influe sur la version retournée par
// NSProcessInfo (compatibilité macOS) : on le compile avec le même SDK
// déclaré que Meld (11.3) pour voir ce que GTK voit réellement.

#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>
#include <dlfcn.h>
#include <stdio.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

int main(int argc, char **argv) {
  @autoreleasepool {
    NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
    printf("NSProcessInfo: %ld.%ld.%ld\n", (long)v.majorVersion, (long)v.minorVersion,
           (long)v.patchVersion);

    SInt32 major = -1, minor = -1;
    Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
    printf("Gestalt: major=%d minor=%d\n", (int)major, (int)minor);

    [NSApplication sharedApplication];
    for (NSScreen *s in [NSScreen screens])
      printf("NSScreen: %.0fx%.0f backingScaleFactor=%.1f\n", s.frame.size.width,
             s.frame.size.height, s.backingScaleFactor);

    if (argc < 2)
      return 0;
    void *h = dlopen(argv[1], RTLD_NOW);
    if (!h) {
      printf("dlopen: %s\n", dlerror());
      return 1;
    }
    int (*osx_version)(void) = (int (*)(void))dlsym(h, "gdk_quartz_osx_version");
    if (!osx_version) {
      printf("dlsym: %s\n", dlerror());
      return 1;
    }
    // GdkOSXVersion : 0 = UNSUPPORTED, 4..18 = Tiger..Ventura, 99 = NEW
    printf("gdk_quartz_osx_version() = %d\n", osx_version());
  }
  return 0;
}
