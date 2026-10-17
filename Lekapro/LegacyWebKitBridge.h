#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LegacyWebKitBridge : NSObject
+ (nullable WKWebsiteDataStore *)makeStoreAtURL:(NSURL *)directory
                           proxyConfiguration:(nullable NSDictionary *)proxy
                                        error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeStore(at:proxy:));
+ (NSDictionary<NSString *, NSNumber *> *)capabilities;
+ (nullable WKProcessPool *)makeProcessPoolWithTimeZone:(NSString *)timeZone
                                                error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeProcessPool(timeZone:));
+ (nullable NSObject *)makeFontStyleWithFamily:(NSString *)family
                                        error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeFontStyle(family:));
+ (void)installFontStyle:(NSObject *)style controller:(WKUserContentController *)controller;
@end

NS_ASSUME_NONNULL_END
