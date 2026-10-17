#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LegacyWebKitBridge : NSObject
+ (nullable NSSet<NSString *> *)diagnosticAllNativeDataTypes:(NSError * _Nullable * _Nullable)error;
+ (pid_t)diagnosticNetworkPID:(WKWebsiteDataStore *)store;
+ (BOOL)restartDiagnosticNetwork:(WKWebsiteDataStore *)store error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)flushDiagnosticNetwork:(WKWebsiteDataStore *)store completion:(void(^)(void))completion
    NS_SWIFT_NAME(flushDiagnosticNetwork(_:completion:));
+ (nullable WKWebsiteDataStore *)makeStoreAtURL:(NSURL *)directory
                           proxyConfiguration:(nullable NSDictionary *)proxy
                                        error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeStore(at:proxy:));
+ (nullable WKWebsiteDataStore *)makeQuotaStoreAtURL:(NSURL *)directory
                                              quota:(NSUInteger)quota
                                              error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeQuotaStore(at:quota:));
+ (NSDictionary<NSString *, NSNumber *> *)capabilities;
+ (nullable WKProcessPool *)makeProcessPoolWithTimeZone:(NSString *)timeZone
                                                error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeProcessPool(timeZone:));
+ (nullable NSObject *)makeFontStyleWithFamily:(NSString *)family
                                        error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeFontStyle(family:));
+ (void)installFontStyle:(NSObject *)style controller:(WKUserContentController *)controller;
+ (BOOL)applyDiagnosticOptions:(NSDictionary<NSString *, id> *)options
                 configuration:(WKWebViewConfiguration *)configuration
                         error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(applyDiagnosticOptions(_:configuration:));
+ (BOOL)applyDiagnosticPlatform:(nullable NSString *)platform
                    preferences:(WKWebpagePreferences *)preferences
                          error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(applyDiagnosticPlatform(_:preferences:));
@end

NS_ASSUME_NONNULL_END
