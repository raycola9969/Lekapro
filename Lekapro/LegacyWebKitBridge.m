#import "LegacyWebKitBridge.h"
#import <objc/message.h>

// Runtime-checked WebKit SPI for locally installed iOS 16 builds.
// All paths belong to this app's own Application Support container.
@implementation LegacyWebKitBridge
+ (NSSet<NSString *> *)diagnosticAllNativeDataTypes:(NSError **)error {
    @try {
#if DEBUG
        SEL selector = NSSelectorFromString(@"_allWebsiteDataTypesIncludingPrivate");
        if (![WKWebsiteDataStore respondsToSelector:selector]) @throw [NSException exceptionWithName:@"UnsupportedDiagnostic" reason:@"Private data enumeration is unavailable." userInfo:nil];
        return ((id (*)(id, SEL))objc_msgSend)(WKWebsiteDataStore.class, selector);
#else
        @throw [NSException exceptionWithName:@"DiagnosticsDisabled" reason:@"Private state experiments require DEBUG." userInfo:nil];
#endif
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"Lekapro.StateDiagnostic" code:1 userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        return nil;
    }
}
+ (pid_t)diagnosticNetworkPID:(WKWebsiteDataStore *)store {
#if DEBUG
    SEL selector = NSSelectorFromString(@"_networkProcessIdentifier");
    if ([store respondsToSelector:selector]) return ((pid_t (*)(id, SEL))objc_msgSend)(store, selector);
#endif
    return 0;
}
+ (BOOL)restartDiagnosticNetwork:(WKWebsiteDataStore *)store error:(NSError **)error {
    @try {
#if DEBUG
        SEL selector = NSSelectorFromString(@"_terminateNetworkProcess");
        if (![store respondsToSelector:selector] || [self diagnosticNetworkPID:store] <= 0) @throw [NSException exceptionWithName:@"UnsupportedDiagnostic" reason:@"The selected WebKit network process is unavailable." userInfo:nil];
        ((void (*)(id, SEL))objc_msgSend)(store, selector);
        return YES;
#else
        @throw [NSException exceptionWithName:@"DiagnosticsDisabled" reason:@"Private state experiments require DEBUG." userInfo:nil];
#endif
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"Lekapro.StateDiagnostic" code:2 userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        return NO;
    }
}
+ (BOOL)flushDiagnosticNetwork:(WKWebsiteDataStore *)store completion:(void(^)(void))completion {
#if DEBUG
    SEL flush = NSSelectorFromString(@"_flushCookiesToDiskWithCompletionHandler:");
    SEL prepare = NSSelectorFromString(@"_sendNetworkProcessPrepareToSuspend:");
    SEL resume = NSSelectorFromString(@"_sendNetworkProcessDidResume");
    if (![store.httpCookieStore respondsToSelector:flush] || ![store respondsToSelector:prepare] || ![store respondsToSelector:resume]) return NO;
    ((void (*)(id, SEL, id))objc_msgSend)(store.httpCookieStore, flush, ^{
        ((void (*)(id, SEL, id))objc_msgSend)(store, prepare, ^{
            ((void (*)(id, SEL))objc_msgSend)(store, resume);
            completion();
        });
    });
    return YES;
#else
    return NO;
#endif
}
+ (BOOL)applyDiagnosticOptions:(NSDictionary<NSString *, id> *)options configuration:(WKWebViewConfiguration *)configuration error:(NSError **)error {
    @try {
#if DEBUG
        NSDictionary<NSString *, NSString *> *setters = @{
            @"webAudioEnabled": @"_setWebAudioEnabled:",
            @"acceleratedDrawing": @"_setAcceleratedDrawingEnabled:",
            @"allowInstalledFonts": @"_setShouldAllowUserInstalledFonts:",
            @"allowDesignSystemFonts": @"_setShouldAllowDesignSystemUIFonts:",
            @"storageAPIEnabled": @"_setStorageAPIEnabled:",
            @"standalone": @"_setStandalone:"
        };
        for (NSString *key in setters) {
            NSNumber *value = options[key];
            if (!value) continue;
            SEL setter = NSSelectorFromString(setters[key]);
            if (![value isKindOfClass:NSNumber.class] || ![configuration.preferences respondsToSelector:setter]) {
                @throw [NSException exceptionWithName:@"UnsupportedDiagnosticOption" reason:[@"WebKit cannot apply " stringByAppendingString:key] userInfo:nil];
            }
            ((void (*)(id, SEL, BOOL))objc_msgSend)(configuration.preferences, setter, value.boolValue);
        }
#else
        if (options.count) @throw [NSException exceptionWithName:@"DiagnosticsDisabled" reason:@"Engine experiments require a DEBUG build." userInfo:nil];
#endif
        return YES;
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"Lekapro.EngineDiagnostic" code:1 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Engine diagnostic configuration failed."}];
        return NO;
    }
}
+ (BOOL)applyDiagnosticPlatform:(NSString *)platform preferences:(WKWebpagePreferences *)preferences error:(NSError **)error {
    @try {
#if DEBUG
        SEL setter = NSSelectorFromString(@"_setCustomNavigatorPlatform:");
        if ((platform && ![@[@"iPhone", @"iPad", @"MacIntel", @"Linux aarch64", @"Win32"] containsObject:platform]) || ![preferences respondsToSelector:setter]) {
            @throw [NSException exceptionWithName:@"UnsupportedDiagnosticPlatform" reason:@"WebKit cannot apply this navigator platform." userInfo:nil];
        }
        ((void (*)(id, SEL, id))objc_msgSend)(preferences, setter, platform);
#else
        if (platform) @throw [NSException exceptionWithName:@"DiagnosticsDisabled" reason:@"Engine experiments require a DEBUG build." userInfo:nil];
#endif
        return YES;
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"Lekapro.EngineDiagnostic" code:2 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Navigator platform configuration failed."}];
        return NO;
    }
}
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
    return [self makeConfiguredStoreAtURL:directory proxyConfiguration:proxy quota:nil error:error];
}
+ (WKWebsiteDataStore *)makeQuotaStoreAtURL:(NSURL *)directory quota:(NSUInteger)quota error:(NSError **)error {
    return [self makeConfiguredStoreAtURL:directory proxyConfiguration:nil quota:@(quota) error:error];
}
+ (WKWebsiteDataStore *)makeConfiguredStoreAtURL:(NSURL *)directory proxyConfiguration:(NSDictionary *)proxy quota:(NSNumber *)quota error:(NSError **)error {
    @try {
        Class cls = NSClassFromString(@"_WKWebsiteDataStoreConfiguration");
        SEL initializer = NSSelectorFromString(@"_initWithConfiguration:");
        if (!cls || ![WKWebsiteDataStore instancesRespondToSelector:initializer]) {
            @throw [NSException exceptionWithName:@"UnsupportedWebKit" reason:@"WebKit does not expose isolated storage configuration on this OS." userInfo:nil];
        }
        id configuration = [[cls alloc] init];
        if (quota) {
            SEL setter = NSSelectorFromString(@"setPerOriginStorageQuota:");
            if (quota.unsignedLongLongValue < 16 * 1024 * 1024 || quota.unsignedLongLongValue > 64ULL * 1024 * 1024 * 1024 || ![configuration respondsToSelector:setter]) {
                @throw [NSException exceptionWithName:@"UnsupportedQuota" reason:@"WebKit cannot apply the requested storage limit." userInfo:nil];
            }
            ((void (*)(id, SEL, NSUInteger))objc_msgSend)(configuration, setter, quota.unsignedIntegerValue);
            // Use the actual fixed origin limit rather than a ratio of disk size
            // or a standard reported volume. No StorageManager JS replacement.
            for (NSString *name in @[@"setOriginQuotaRatio:", @"setStandardVolumeCapacity:"]) {
                SEL optionalSetter = NSSelectorFromString(name);
                if ([configuration respondsToSelector:optionalSetter]) ((void (*)(id, SEL, id))objc_msgSend)(configuration, optionalSetter, nil);
            }
        }
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
