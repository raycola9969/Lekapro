#import "LegacyWebKitBridge.h"
#import <objc/message.h>

// Runtime-checked WebKit SPI for locally installed iOS 16 builds.
// All paths belong to this app's own Application Support container.
@implementation LegacyWebKitBridge
+ (NSObject *)makeFontStyleWithFamily:(NSString *)family error:(NSError **)error {
    @try {
        Class cls = NSClassFromString(@"_WKUserStyleSheet");
        SEL initializer = NSSelectorFromString(@"initWithSource:forWKWebView:forMainFrameOnly:includeMatchPatternStrings:excludeMatchPatternStrings:baseURL:level:contentWorld:");
        if (![@[@"serif", @"sans-serif", @"monospace"] containsObject:family] || !cls || ![cls instancesRespondToSelector:initializer] || ![WKUserContentController instancesRespondToSelector:NSSelectorFromString(@"_addUserStyleSheet:")]) {
            @throw [NSException exceptionWithName:@"UnsupportedFontStyle" reason:@"WebKit cannot apply this profile font style on this OS." userInfo:nil];
        }
        NSString *source = [NSString stringWithFormat:@"* { font-family: %@ !important; }", family];
        // User-origin CSS: inline author styles cannot silently undo the user's choice.
        return ((id (*)(id, SEL, id, id, BOOL, id, id, id, NSInteger, id))objc_msgSend)([cls alloc], initializer, source, nil, NO, nil, nil, nil, 0, WKContentWorld.pageWorld);
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"Lekapro.LegacyWebKit" code:3 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Font configuration failed."}];
        return nil;
    }
}
+ (void)installFontStyle:(NSObject *)style controller:(WKUserContentController *)controller {
    ((void (*)(id, SEL, id))objc_msgSend)(controller, NSSelectorFromString(@"_addUserStyleSheet:"), style);
}
+ (WKProcessPool *)makeProcessPoolWithTimeZone:(NSString *)timeZone error:(NSError **)error {
    @try {
        Class cls = NSClassFromString(@"_WKProcessPoolConfiguration");
        SEL setter = NSSelectorFromString(@"setTimeZoneOverride:");
        SEL initializer = NSSelectorFromString(@"_initWithConfiguration:");
        if (![NSTimeZone timeZoneWithName:timeZone] || !cls || ![cls instancesRespondToSelector:setter] || ![WKProcessPool instancesRespondToSelector:initializer]) {
            @throw [NSException exceptionWithName:@"UnsupportedTimeZone" reason:@"WebKit cannot configure this profile time zone on this OS." userInfo:nil];
        }
        id configuration = [[cls alloc] init];
        ((void (*)(id, SEL, id))objc_msgSend)(configuration, setter, timeZone);
        return ((id (*)(id, SEL, id))objc_msgSend)([WKProcessPool alloc], initializer, configuration);
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"Lekapro.LegacyWebKit" code:2 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Time zone configuration failed."}];
        return nil;
    }
}
+ (NSDictionary<NSString *, NSNumber *> *)capabilities {
    Class cls = NSClassFromString(@"_WKWebsiteDataStoreConfiguration");
    return @{
        @"configurationClass": @(cls != Nil),
        @"customPaths": @(cls && [cls instancesRespondToSelector:NSSelectorFromString(@"_setWebStorageDirectory:")]),
        @"customCookies": @(cls && [cls instancesRespondToSelector:NSSelectorFromString(@"_setCookieStorageFile:")]),
        @"proxyConfiguration": @(cls && [cls instancesRespondToSelector:NSSelectorFromString(@"setProxyConfiguration:")]),
        @"storeInitializer": @([WKWebsiteDataStore instancesRespondToSelector:NSSelectorFromString(@"_initWithConfiguration:")])
    };
}
+ (WKWebsiteDataStore *)makeStoreAtURL:(NSURL *)directory proxyConfiguration:(NSDictionary *)proxy error:(NSError **)error {
    @try {
        Class cls = NSClassFromString(@"_WKWebsiteDataStoreConfiguration");
        SEL initializer = NSSelectorFromString(@"_initWithConfiguration:");
        if (!cls || ![WKWebsiteDataStore instancesRespondToSelector:initializer]) {
            @throw [NSException exceptionWithName:@"UnsupportedWebKit" reason:@"WebKit does not expose isolated storage configuration on this OS." userInfo:nil];
        }
        id configuration = [[cls alloc] init];
        NSArray<NSArray<NSString *> *> *paths = @[
            @[@"_setWebStorageDirectory:", @"LocalStorage"],
            @[@"_setIndexedDBDatabaseDirectory:", @"IndexedDB"],
            @[@"_setWebSQLDatabaseDirectory:", @"WebSQL"],
            @[@"_setCookieStorageFile:", @"Cookies/Cookies.binarycookies"],
            @[@"_setResourceLoadStatisticsDirectory:", @"Statistics"],
            @[@"_setCacheStorageDirectory:", @"CacheStorage"],
            @[@"_setServiceWorkerRegistrationDirectory:", @"ServiceWorkers"],
            @[@"setNetworkCacheDirectory:", @"NetworkCache"],
            @[@"setDeviceIdHashSaltsStorageDirectory:", @"DeviceSalts"],
            @[@"setApplicationCacheDirectory:", @"ApplicationCache"],
            @[@"setMediaCacheDirectory:", @"MediaCache"],
            @[@"setMediaKeysStorageDirectory:", @"MediaKeys"],
            @[@"setHSTSStorageDirectory:", @"HSTS"],
            @[@"setAlternativeServicesStorageDirectory:", @"AlternativeServices"],
            @[@"setGeneralStorageDirectory:", @"GeneralStorage"]
        ];
        for (NSArray<NSString *> *entry in paths) {
            SEL setter = NSSelectorFromString(entry[0]);
            BOOL required = [entry[0] isEqualToString:@"_setWebStorageDirectory:"] || [entry[0] isEqualToString:@"_setIndexedDBDatabaseDirectory:"] || [entry[0] isEqualToString:@"_setCookieStorageFile:"];
            if (![configuration respondsToSelector:setter]) {
                if (required) @throw [NSException exceptionWithName:@"UnsupportedWebKit" reason:[@"Missing " stringByAppendingString:entry[0]] userInfo:nil];
                continue;
            }
            NSURL *path = [directory URLByAppendingPathComponent:entry[1]];
            NSURL *folder = [entry[0] isEqualToString:@"_setCookieStorageFile:"] ? path.URLByDeletingLastPathComponent : path;
            if (![[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:error]) return nil;
            ((void (*)(id, SEL, id))objc_msgSend)(configuration, setter, path);
        }
        SEL customPaths = NSSelectorFromString(@"setShouldUseCustomStoragePaths:");
        if ([configuration respondsToSelector:customPaths]) ((void (*)(id, SEL, BOOL))objc_msgSend)(configuration, customPaths, YES);
        if (proxy) {
            SEL setter = NSSelectorFromString(@"setProxyConfiguration:");
            if (![configuration respondsToSelector:setter]) @throw [NSException exceptionWithName:@"UnsupportedProxy" reason:@"This WebKit has no per-store proxy configuration." userInfo:nil];
            ((void (*)(id, SEL, id))objc_msgSend)(configuration, setter, proxy);
            SEL preconnect = NSSelectorFromString(@"setAllowsServerPreconnect:");
            if ([configuration respondsToSelector:preconnect]) ((void (*)(id, SEL, BOOL))objc_msgSend)(configuration, preconnect, NO);
        }
        return ((id (*)(id, SEL, id))objc_msgSend)([WKWebsiteDataStore alloc], initializer, configuration);
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"Lekapro.LegacyWebKit" code:1 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"WebKit configuration failed."}];
        return nil;
    }
}
@end
