/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTActionSheetManager.h"

#import "RCTLog.h"
#import "RCTUtils.h"

@interface RCTActionSheetManager () <UIActionSheetDelegate>

@end

@implementation RCTActionSheetManager
{
  NSMutableDictionary *_callbacks;
}

RCT_EXPORT_MODULE()

- (instancetype)init
{
  if ((self = [super init])) {
    _callbacks = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(showActionSheetWithOptions:(NSDictionary *)options
                  failureCallback:(RCTResponseSenderBlock)failureCallback
                  successCallback:(RCTResponseSenderBlock)successCallback)
{
  UIActionSheet *actionSheet = [[UIActionSheet alloc] init];

  actionSheet.title = options[@"title"];

  for (NSString *option in options[@"options"]) {
    [actionSheet addButtonWithTitle:option];
  }

  if (options[@"destructiveButtonIndex"]) {
    actionSheet.destructiveButtonIndex = [options[@"destructiveButtonIndex"] integerValue];
  }
  if (options[@"cancelButtonIndex"]) {
    actionSheet.cancelButtonIndex = [options[@"cancelButtonIndex"] integerValue];
  }

  actionSheet.delegate = self;

  _callbacks[RCTKeyForInstance(actionSheet)] = successCallback;

  UIWindow *appWindow = [[[UIApplication sharedApplication] delegate] window];
  if (appWindow == nil) {
    RCTLogError(@"Tried to display action sheet but there is no application window. options: %@", options);
    return;
  }
  [actionSheet showInView:appWindow];
}

RCT_EXPORT_METHOD(showShareActionSheetWithOptions:(NSDictionary *)options
                  failureCallback:(RCTResponseSenderBlock)failureCallback
                  successCallback:(RCTResponseSenderBlock)successCallback)
{
  NSMutableArray *items = [NSMutableArray array];
  id message = options[@"message"];
  id url = options[@"url"];
  if ([message isKindOfClass:[NSString class]]) {
    [items addObject:message];
  }
  if ([url isKindOfClass:[NSString class]]) {
    [items addObject:[NSURL URLWithString:url]];
  }
  if ([items count] == 0) {
    failureCallback(@[@"No `url` or `message` to share"]);
    return;
  }
  UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
  UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
  if ([share respondsToSelector:@selector(setCompletionWithItemsHandler:)]) {
    share.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
      if (activityError) {
        failureCallback(@[[activityError localizedDescription]]);
      } else {
        successCallback(@[@(completed), RCTNullIfNil(activityType)]);
      }
    };
  } else {

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0

    if (![UIActivityViewController instancesRespondToSelector:@selector(completionWithItemsHandler)]) {
      // Legacy iOS 7 implementation
      share.completionHandler = ^(NSString *activityType, BOOL completed) {
        successCallback(@[@(completed), RCTNullIfNil(activityType)]);
      };
    } else

#endif

    {
      // iOS 8 version
      share.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        successCallback(@[@(completed), RCTNullIfNil(activityType)]);
      };
    }
  }
  [ctrl presentViewController:share animated:YES completion:nil];
}

#pragma mark UIActionSheetDelegate Methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSString *key = RCTKeyForInstance(actionSheet);
  RCTResponseSenderBlock callback = _callbacks[key];
  if (callback) {
    callback(@[@(buttonIndex)]);
    [_callbacks removeObjectForKey:key];
  } else {
    RCTLogWarn(@"No callback registered for action sheet: %@", actionSheet.title);
  }

  [[[[UIApplication sharedApplication] delegate] window] makeKeyWindow];
}

#pragma mark Private

static NSString *RCTKeyForInstance(id instance)
{
  return [NSString stringWithFormat:@"%p", instance];
}

@end
