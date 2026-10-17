#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LegacyWebKitBridge : NSObject
+ (nullable WKWebsiteDataStore *)makeStoreAtURL:(NSURL *)directory
                           proxyConfiguration:(nullable NSDictionary *)proxy
                                        error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(makeStore(at:proxy:));
+ (NSDictionary<NSString *, NSNumber *> *)capabilities;
@end

NS_ASSUME_NONNULL_END
