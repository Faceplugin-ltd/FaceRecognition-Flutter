#import "FaceRecognitionSdkPlugin.h"
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>

#if __has_include(<facerecognitionsdk/FaceRecognitionSDK.h>)
#import <facerecognitionsdk/FaceRecognitionSDK.h>
#define FRS_HAS_SDK 1
#elif __has_include("FaceRecognitionSDK.h")
#import "FaceRecognitionSDK.h"
#define FRS_HAS_SDK 1
#endif

@implementation FaceRecognitionSdkPlugin {
  FlutterEventSink eventSink;
  BOOL videoFrameBusy;
  UIImage *lastLiveImage;
  NSInteger lastLiveWidth;
  NSInteger lastLiveHeight;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"FaceRecognitionSdk"
                                  binaryMessenger:[registrar messenger]];
  FaceRecognitionSdkPlugin *instance = [[FaceRecognitionSdkPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];

  FlutterEventChannel *events =
      [FlutterEventChannel eventChannelWithName:@"FaceRecognitionSdk/videoWorker"
                                binaryMessenger:[registrar messenger]];
  [events setStreamHandler:instance];
}

#pragma mark - FlutterStreamHandler

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events {
  self->eventSink = events;
  return nil;
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
  self->eventSink = nil;
  return nil;
}

- (void)emitVideoWorkerEvent:(NSString *)json {
  FlutterEventSink sink = self->eventSink;
  if (sink == nil) {
    return;
  }
  NSString *payload = json ?: @"{}";
  NSDictionary *body = @{ @"json": payload };
  if ([NSThread isMainThread]) {
    sink(body);
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      FlutterEventSink s = self->eventSink;
      if (s != nil) {
        s(body);
      }
    });
  }
}

#pragma mark - Helpers

static dispatch_queue_t FRSQueue(void) {
  static dispatch_queue_t q;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    q = dispatch_queue_create("com.facerecognitionsdk.bridge", DISPATCH_QUEUE_SERIAL);
  });
  return q;
}

static FlutterError *FRSMissingSdkError(void) {
  return [FlutterError
      errorWithCode:@"E_SDK"
            message:@"facerecognitionsdk.framework not linked. Download from Google Drive and place under ios/Frameworks/."
            details:nil];
}

static NSDictionary *FRSArgsDict(id arguments) {
  if ([arguments isKindOfClass:[NSDictionary class]]) {
    return (NSDictionary *)arguments;
  }
  return @{};
}

static NSString *FRSStringArg(NSDictionary *args, NSString *key) {
  id v = args[key];
  if ([v isKindOfClass:[NSString class]]) {
    return (NSString *)v;
  }
  if ([v isKindOfClass:[NSNumber class]]) {
    return [(NSNumber *)v stringValue];
  }
  return @"";
}

static BOOL FRSBoolArg(NSDictionary *args, NSString *key, BOOL def) {
  id v = args[key];
  if (v == nil || [v isKindOfClass:[NSNull class]]) {
    return def;
  }
  return [v boolValue];
}

static NSNumber *FRSNumberArg(NSDictionary *args, NSString *key, NSNumber *def) {
  id v = args[key];
  if ([v isKindOfClass:[NSNumber class]]) {
    return (NSNumber *)v;
  }
  if ([v isKindOfClass:[NSString class]]) {
    return @([(NSString *)v doubleValue]);
  }
  return def;
}

static NSString *FRSParamJsonFromArg(id paramArg) {
  if ([paramArg isKindOfClass:[NSString class]]) {
    return (NSString *)paramArg;
  }
  if ([paramArg isKindOfClass:[NSDictionary class]]) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:paramArg options:0 error:nil];
    if (data == nil) {
      return @"";
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
  }
  return @"";
}

static UIImage *FRSImageFromUriOrBase64(NSString *uriOrBase64) {
  if (uriOrBase64 == nil || uriOrBase64.length == 0) {
    return nil;
  }

  BOOL looksBase64 = [uriOrBase64 hasPrefix:@"data:"] ||
    ([uriOrBase64 length] > 256 &&
     [uriOrBase64 rangeOfString:@"://"].location == NSNotFound &&
     ![uriOrBase64 hasPrefix:@"/"] &&
     ![uriOrBase64 hasPrefix:@"file:"]);

  if (looksBase64) {
    NSString *payload = uriOrBase64;
    NSRange range = [uriOrBase64 rangeOfString:@"base64,"];
    if (range.location != NSNotFound) {
      payload = [uriOrBase64 substringFromIndex:range.location + range.length];
    }
    NSData *data = [[NSData alloc] initWithBase64EncodedString:payload
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (data == nil) {
      return nil;
    }
    return [UIImage imageWithData:data];
  }

  if ([uriOrBase64 hasPrefix:@"/"] || [uriOrBase64 hasPrefix:@"file:"]) {
    NSString *path = uriOrBase64;
    if ([path hasPrefix:@"file:"]) {
      NSURL *fileURL = [NSURL URLWithString:path];
      path = fileURL.path ?: path;
    }
    UIImage *fromFile = [UIImage imageWithContentsOfFile:path];
    if (fromFile != nil) {
      return fromFile;
    }
  }

  NSURL *url = [NSURL URLWithString:uriOrBase64];
  if (url == nil) {
    return nil;
  }
  NSData *data = [NSData dataWithContentsOfURL:url];
  if (data == nil) {
    return nil;
  }
  return [UIImage imageWithData:data];
}

static UIImage *FRSFixOrientation(UIImage *image) {
  if (image == nil) {
    return nil;
  }
  // Always bake into a CGImage bitmap. Camera snapshots often build a
  // CIImage-backed UIImage; jpegData often leaves landscape sensor pixels with
  // orientation=Up, so an early-return on .Up would feed sideways frames.
  if (image.imageOrientation == UIImageOrientationUp && image.scale == 1.0 && image.CGImage != nil) {
    return image;
  }
  CGSize pixelSize = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
  if (pixelSize.width < 1 || pixelSize.height < 1) {
    return nil;
  }
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = 1;
  format.opaque = YES;
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:pixelSize format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull ctx) {
    [image drawInRect:CGRectMake(0, 0, pixelSize.width, pixelSize.height)];
  }];
}

static UIImage *FRSRotateDegrees(UIImage *image, CGFloat degrees) {
  if (image == nil) {
    return nil;
  }
  const CGFloat radians = degrees * (CGFloat)M_PI / 180.0f;
  CGSize size = CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
  if (size.width < 1 || size.height < 1) {
    return nil;
  }
  CGRect bound = CGRectApplyAffineTransform(
      CGRectMake(0, 0, size.width, size.height),
      CGAffineTransformMakeRotation(radians));
  CGSize outSize = CGSizeMake(floor(fabs(bound.size.width)), floor(fabs(bound.size.height)));
  if (outSize.width < 1 || outSize.height < 1) {
    return nil;
  }
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = 1;
  format.opaque = YES;
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:outSize format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull ctx) {
    CGContextRef c = ctx.CGContext;
    CGContextTranslateCTM(c, outSize.width * 0.5, outSize.height * 0.5);
    CGContextRotateCTM(c, radians);
    [image drawInRect:CGRectMake(-size.width * 0.5, -size.height * 0.5, size.width, size.height)];
  }];
}

static UIImage *FRSScaledMaxEdge(UIImage *image, CGFloat maxEdge) {
  if (image == nil) {
    return nil;
  }
  UIImage *upright = FRSFixOrientation(image);
  if (upright == nil) {
    return nil;
  }
  CGFloat pw = upright.size.width * upright.scale;
  CGFloat ph = upright.size.height * upright.scale;
  CGFloat edge = MAX(pw, ph);
  if (edge <= maxEdge) {
    return upright;
  }
  CGFloat scale = maxEdge / edge;
  CGSize size = CGSizeMake(floor(pw * scale), floor(ph * scale));
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = 1;
  format.opaque = YES;
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull ctx) {
    [upright drawInRect:CGRectMake(0, 0, size.width, size.height)];
  }];
}

/**
 * Bake camera/EXIF to display-upright pixels only (no front/back logic).
 * Dart liveFramePrep owns rotateDegrees; native only applies.
 */
static UIImage *FRSBakeOrientation(UIImage *image) {
  return FRSFixOrientation(image);
}

static UIImage *FRSApplyLiveTransform(UIImage *image, CGFloat rotateDegrees, CGFloat maxEdge) {
  if (image == nil) {
    return nil;
  }
  UIImage *frame = FRSBakeOrientation(image);
  if (frame == nil) {
    return nil;
  }
  CGFloat deg = fmod(rotateDegrees, 360.0);
  if (fabs(deg) > 0.01) {
    frame = FRSRotateDegrees(frame, deg);
  }
  if (frame == nil) {
    return nil;
  }
  CGFloat edge = maxEdge > 0 ? maxEdge : 640.0;
  return FRSScaledMaxEdge(frame, edge);
}

static NSDictionary *FRSLiveFrameResult(UIImage *image, BOOL ingested, NSString *uri) {
  CGFloat w = image ? image.size.width * image.scale : 0;
  CGFloat h = image ? image.size.height * image.scale : 0;
  return @{
    @"ingested": @(ingested),
    @"width": @(w),
    @"height": @(h),
    @"uri": uri ?: [NSNull null],
  };
}

static NSString *FRSWriteTempJpeg(UIImage *image, CGFloat quality) {
  if (image == nil) {
    return nil;
  }
  NSData *data = UIImageJPEGRepresentation(image, quality);
  if (data.length == 0) {
    return nil;
  }
  NSString *name = [NSString stringWithFormat:@"frs_live_%@.jpg", NSUUID.UUID.UUIDString];
  NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
  if (![data writeToFile:path atomically:YES]) {
    return nil;
  }
  return [@"file://" stringByAppendingString:path];
}

static id FRSAttrLookup(NSDictionary *attrs, NSArray<NSString *> *keys) {
  if (![attrs isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  for (NSString *key in keys) {
    id v = attrs[key];
    if (v != nil) {
      return v;
    }
  }
  return nil;
}

static NSString *FRSAttrValue(id attr) {
  if ([attr isKindOfClass:[NSDictionary class]]) {
    id v = ((NSDictionary *)attr)[@"value"];
    if (v == nil) {
      return @"";
    }
    return [NSString stringWithFormat:@"%@", v];
  }
  if (attr == nil) {
    return @"";
  }
  return [NSString stringWithFormat:@"%@", attr];
}

static double FRSAttrConfidence(id attr, double fallback) {
  if ([attr isKindOfClass:[NSDictionary class]]) {
    id c = ((NSDictionary *)attr)[@"confidence"];
    if ([c isKindOfClass:[NSNumber class]]) {
      return [(NSNumber *)c doubleValue];
    }
    if ([c isKindOfClass:[NSString class]]) {
      return [(NSString *)c doubleValue];
    }
  }
  return fallback;
}

/** Map EyesLeft/EyesRight label → closedness score (0 open … 1 closed), matching Android FaceBox. */
static double FRSEyeClosedScore(id attr) {
  NSString *label = [FRSAttrValue(attr) lowercaseString];
  double conf = FRSAttrConfidence(attr, NAN);
  if ([label containsString:@"clos"]) {
    return isnan(conf) ? 1.0 : MAX(0.0, MIN(1.0, conf));
  }
  if ([label containsString:@"open"]) {
    if (isnan(conf)) {
      return 0.0;
    }
    return MAX(0.0, MIN(1.0, 1.0 - conf));
  }
  if (!isnan(conf)) {
    return MAX(0.0, MIN(1.0, conf));
  }
  return 0.0;
}

static NSString *FRSFeatureB64FromExtractJSON(NSString *json) {
  if (json == nil) {
    return nil;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  if (data == nil) {
    return nil;
  }
  id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![obj isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  NSDictionary *dict = (NSDictionary *)obj;

  NSArray *results = dict[@"results"];
  if ([results isKindOfClass:[NSArray class]] && results.count > 0) {
    NSDictionary *first = results[0];
    if ([first isKindOfClass:[NSDictionary class]]) {
      NSArray *features = first[@"features"];
      if ([features isKindOfClass:[NSArray class]] && features.count > 0) {
        NSDictionary *f0 = features[0];
        if ([f0 isKindOfClass:[NSDictionary class]]) {
          id b64 = f0[@"feature"];
          if ([b64 isKindOfClass:[NSString class]] && [(NSString *)b64 length] > 0) {
            return (NSString *)b64;
          }
        }
      }
    }
  }
  NSArray *features = dict[@"features"];
  if ([features isKindOfClass:[NSArray class]] && features.count > 0) {
    NSDictionary *f0 = features[0];
    if ([f0 isKindOfClass:[NSDictionary class]]) {
      id b64 = f0[@"feature"];
      if ([b64 isKindOfClass:[NSString class]] && [(NSString *)b64 length] > 0) {
        return (NSString *)b64;
      }
    }
  }

  id feature = dict[@"feature"] ?: dict[@"data"] ?: dict[@"featureBase64"];
  if ([feature isKindOfClass:[NSString class]]) {
    return (NSString *)feature;
  }
  if ([feature isKindOfClass:[NSDictionary class]]) {
    id inner = ((NSDictionary *)feature)[@"data"] ?: ((NSDictionary *)feature)[@"feature"];
    if ([inner isKindOfClass:[NSString class]]) {
      return (NSString *)inner;
    }
  }
  return nil;
}

static NSArray *FRSBoxesFromDetectJSON(NSString *json) {
  NSMutableArray *out = [NSMutableArray array];
  if (json == nil) {
    return out;
  }
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSArray *faces = nil;
  if ([root isKindOfClass:[NSDictionary class]]) {
    faces = ((NSDictionary *)root)[@"data"];
    if (![faces isKindOfClass:[NSArray class]]) {
      faces = ((NSDictionary *)root)[@"faces"];
    }
  } else if ([root isKindOfClass:[NSArray class]]) {
    faces = (NSArray *)root;
  }
  if (![faces isKindOfClass:[NSArray class]]) {
    return out;
  }
  for (id item in faces) {
    if (![item isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSDictionary *face = (NSDictionary *)item;
    NSDictionary *region = face[@"faceRegion"];
    NSDictionary *pose = face[@"facePose"];
    NSDictionary *attrs = face[@"attributes"];
    NSMutableDictionary *box = [NSMutableDictionary dictionary];
    CGFloat x = [region[@"x"] doubleValue];
    CGFloat y = [region[@"y"] doubleValue];
    CGFloat w = [region[@"width"] doubleValue];
    CGFloat h = [region[@"height"] doubleValue];
    box[@"x1"] = @((int)x);
    box[@"y1"] = @((int)y);
    box[@"x2"] = @((int)(x + w));
    box[@"y2"] = @((int)(y + h));
    box[@"yaw"] = pose[@"yaw"] ?: @0;
    box[@"roll"] = pose[@"roll"] ?: @0;
    box[@"pitch"] = pose[@"pitch"] ?: @0;
    box[@"age"] = @0;
    box[@"gender"] = @0;
    box[@"liveness"] = @0;
    box[@"face_quality"] = @0;
    box[@"face_luminance"] = @0;
    box[@"left_eye_closed"] = @0;
    box[@"right_eye_closed"] = @0;
    box[@"face_occlusion"] = @0;
    box[@"mouth_opened"] = @0;
    box[@"livenessLabel"] = @"";
    box[@"genderLabel"] = @"";
    box[@"emotionLabel"] = @"";
    box[@"maskLabel"] = @"";
    box[@"qualityLabel"] = @"";
    box[@"eyesLeftLabel"] = @"";
    box[@"eyesRightLabel"] = @"";
    box[@"glassesLabel"] = @"";
    box[@"sunglassesLabel"] = @"";
    box[@"occlusionLabel"] = @"";
    box[@"attributes"] = [NSMutableDictionary dictionary];

    if (face[@"age"] != nil) {
      box[@"age"] = @([face[@"age"] intValue]);
    }

    if ([attrs isKindOfClass:[NSDictionary class]]) {
      NSMutableDictionary *attrOut = [NSMutableDictionary dictionary];
      for (id key in attrs) {
        if (![key isKindOfClass:[NSString class]]) continue;
        id rawAttr = attrs[key];
        NSString *val = FRSAttrValue(rawAttr);
        if (val.length == 0) continue;
        double conf = FRSAttrConfidence(rawAttr, NAN);
        if (!isnan(conf)) {
          attrOut[(NSString *)key] = [NSString stringWithFormat:@"%@ · %.0f%%", val, conf * 100.0];
        } else {
          attrOut[(NSString *)key] = val;
        }
      }
      box[@"attributes"] = attrOut;

      id ageAttr = FRSAttrLookup(attrs, @[ @"Age", @"age" ]);
      NSString *ageVal = FRSAttrValue(ageAttr);
      if (ageVal.length > 0) {
        box[@"age"] = @([ageVal intValue]);
      }

      id genderAttr = FRSAttrLookup(attrs, @[ @"Gender", @"gender" ]);
      NSString *genderVal = FRSAttrValue(genderAttr);
      box[@"genderLabel"] = genderVal;
      NSString *gLower = [genderVal lowercaseString];
      if ([gLower hasPrefix:@"m"]) {
        box[@"gender"] = @0;
      } else if ([gLower hasPrefix:@"f"]) {
        box[@"gender"] = @1;
      }

      id emotionAttr = FRSAttrLookup(attrs, @[ @"Emotion", @"emotion" ]);
      box[@"emotionLabel"] = FRSAttrValue(emotionAttr);

      id maskAttr = FRSAttrLookup(attrs, @[ @"MedicalMask", @"Mask", @"mask" ]);
      box[@"maskLabel"] = FRSAttrValue(maskAttr);

      id glassesAttr = FRSAttrLookup(attrs, @[ @"Glasses", @"glasses" ]);
      box[@"glassesLabel"] = FRSAttrValue(glassesAttr);
      id sunAttr = FRSAttrLookup(attrs, @[ @"Sunglasses", @"sunglasses" ]);
      box[@"sunglassesLabel"] = FRSAttrValue(sunAttr);

      id livAttr = FRSAttrLookup(attrs, @[ @"Liveness2D", @"liveness", @"Liveness" ]);
      NSString *livVal = FRSAttrValue(livAttr);
      box[@"livenessLabel"] = livVal;
      double livConf = FRSAttrConfidence(livAttr, NAN);
      if (!isnan(livConf)) {
        box[@"liveness"] = @(livConf);
      } else if (livVal.length > 0) {
        NSString *ll = [livVal lowercaseString];
        box[@"liveness"] = ([ll containsString:@"real"] || [ll containsString:@"genuine"] || [ll containsString:@"live"])
            ? @1.0
            : @0.0;
      }

      id qualityAttr = FRSAttrLookup(attrs, @[ @"FaceQuality", @"ExpressionLevel", @"face_quality" ]);
      NSString *qVal = FRSAttrValue(qualityAttr);
      box[@"qualityLabel"] = qVal;
      double qConf = FRSAttrConfidence(qualityAttr, NAN);
      if (!isnan(qConf)) {
        box[@"face_quality"] = @(qConf);
      } else if (qVal.length > 0) {
        box[@"face_quality"] = @([qVal doubleValue]);
      }

      id eyesL = FRSAttrLookup(attrs, @[ @"EyesLeft", @"eyesLeft" ]);
      id eyesR = FRSAttrLookup(attrs, @[ @"EyesRight", @"eyesRight" ]);
      box[@"eyesLeftLabel"] = FRSAttrValue(eyesL);
      box[@"eyesRightLabel"] = FRSAttrValue(eyesR);
      box[@"left_eye_closed"] = @(FRSEyeClosedScore(eyesL));
      box[@"right_eye_closed"] = @(FRSEyeClosedScore(eyesR));

      id occ = FRSAttrLookup(attrs, @[ @"Occlusion", @"FaceOcclusion", @"occlusion" ]);
      if (occ != nil) {
        NSString *occVal = FRSAttrValue(occ);
        box[@"occlusionLabel"] = occVal;
        NSString *occLower = [occVal lowercaseString];
        double occConf = FRSAttrConfidence(occ, NAN);
        if (!isnan(occConf)) {
          box[@"face_occlusion"] = @(occConf);
        } else if ([occLower containsString:@"occlud"] || [occLower containsString:@"yes"] || [occLower isEqualToString:@"1"]) {
          box[@"face_occlusion"] = @1.0;
        }
      }
    }

    NSArray *points = face[@"facePoints"];
    NSMutableArray *landmarks = [NSMutableArray array];
    if ([points isKindOfClass:[NSArray class]]) {
      for (id pt in points) {
        if (![pt isKindOfClass:[NSDictionary class]]) continue;
        [landmarks addObject:@([pt[@"x"] doubleValue])];
        [landmarks addObject:@([pt[@"y"] doubleValue])];
      }
    }
    box[@"landmarks"] = landmarks;
    box[@"landmarkCount"] = @(landmarks.count / 2);
    [out addObject:box];
  }
  return out;
}

#ifdef FRS_HAS_SDK
static FaceRecognitionDetectFlags FRSFlagsFromParamJSON(NSString *paramJson) {
  FaceRecognitionDetectFlags flags = FaceRecognitionDetectPose | FaceRecognitionDetectLandmarks;
  if (paramJson.length == 0) {
    return flags;
  }
  NSData *pdata = [paramJson dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *p = [NSJSONSerialization JSONObjectWithData:pdata options:0 error:nil];
  if (![p isKindOfClass:[NSDictionary class]]) {
    return flags;
  }
  if ([p[@"allAttributes"] boolValue]) {
    flags = FaceRecognitionDetectAll;
    if ([p[@"check_liveness_level"] intValue] == 0) {
      flags = flags | FaceRecognitionDetectLivenessAccurate;
    }
    return flags;
  }

  flags = 0;
  BOOL checkPose = p[@"check_pose"] ? [p[@"check_pose"] boolValue] : YES;
  BOOL checkLandmarks = p[@"check_landmarks"] ? [p[@"check_landmarks"] boolValue] : YES;
  if (checkPose) {
    flags |= FaceRecognitionDetectPose;
  }
  if (checkLandmarks) {
    flags |= FaceRecognitionDetectLandmarks;
  }
  if ([p[@"estimate_age_gender"] boolValue]) {
    flags |= FaceRecognitionDetectAge | FaceRecognitionDetectGender;
  }
  if ([p[@"check_emotion"] boolValue]) {
    flags |= FaceRecognitionDetectEmotion;
  }
  if ([p[@"check_mask"] boolValue]) {
    flags |= FaceRecognitionDetectMask;
  }
  if ([p[@"check_quality"] boolValue]) {
    flags |= FaceRecognitionDetectQuality | FaceRecognitionDetectFaceQuality;
  }
  if ([p[@"check_eye_closeness"] boolValue] || [p[@"check_face_occlusion"] boolValue]) {
    flags |= FaceRecognitionDetectEyes;
  }
  if ([p[@"check_liveness"] boolValue]) {
    flags |= FaceRecognitionDetectLiveness;
    if ([p[@"check_liveness_level"] intValue] == 0) {
      flags |= FaceRecognitionDetectLivenessAccurate;
    }
  }
  if ([p[@"check_glasses"] boolValue]) {
    flags |= FaceRecognitionDetectGlasses;
  }
  if (flags == 0) {
    flags = FaceRecognitionDetectPose | FaceRecognitionDetectLandmarks;
  }
  return flags;
}
#endif

static NSString *FRSJsonString(id obj) {
  if (obj == nil) {
    return @"[]";
  }
  NSError *err = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&err];
  if (data == nil) {
    return @"[]";
  }
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
}

/** Match Android Utils.cropFace: 1.4× square window scaled to 200×200. */
static UIImage *FRSCropFace(UIImage *image, NSDictionary *box) {
  if (image == nil || box == nil) {
    return nil;
  }
  CGFloat x1 = [box[@"x1"] doubleValue];
  CGFloat y1 = [box[@"y1"] doubleValue];
  CGFloat x2 = [box[@"x2"] doubleValue];
  CGFloat y2 = [box[@"y2"] doubleValue];
  CGFloat iw = image.size.width * image.scale;
  CGFloat ih = image.size.height * image.scale;
  if (iw < 2 || ih < 2) {
    return nil;
  }
  CGFloat centerX = (x1 + x2) / 2.0;
  CGFloat centerY = (y1 + y2) / 2.0;
  NSInteger cropWidth = (NSInteger)((x2 - x1) * 1.4f);
  if (cropWidth < 2) {
    cropWidth = MAX(2, MAX((NSInteger)(x2 - x1), (NSInteger)(y2 - y1)));
  }
  NSInteger cropX1 = (NSInteger)MAX(0, centerX - cropWidth / 2.0);
  NSInteger cropY1 = (NSInteger)MAX(0, centerY - cropWidth / 2.0);
  NSInteger cropX2 = (NSInteger)MIN(iw - 1, centerX + cropWidth / 2.0);
  NSInteger cropY2 = (NSInteger)MIN(ih - 1, centerY + cropWidth / 2.0);
  NSInteger w = cropX2 - cropX1 + 1;
  NSInteger h = cropY2 - cropY1 + 1;
  if (w <= 1 || h <= 1) {
    return nil;
  }
  CGRect rect = CGRectMake(cropX1, cropY1, w, h);
  CGImageRef cg = CGImageCreateWithImageInRect(image.CGImage, rect);
  if (cg == NULL) {
    return nil;
  }
  UIImage *cropped = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
  CGImageRelease(cg);
  if (cropped == nil) {
    return nil;
  }
  CGSize target = CGSizeMake(200, 200);
  UIGraphicsBeginImageContextWithOptions(target, YES, 1.0);
  [cropped drawInRect:CGRectMake(0, 0, target.width, target.height)];
  UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return scaled ?: cropped;
}

static NSString *FRSJpegBase64(UIImage *image) {
  if (image == nil) {
    return nil;
  }
  NSData *data = UIImageJPEGRepresentation(image, 0.85);
  return [data base64EncodedStringWithOptions:0];
}

#pragma mark - MethodChannel

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSDictionary *args = FRSArgsDict(call.arguments);

  if ([@"getMachineCode" isEqualToString:call.method]) {
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        result([FaceRecognitionSDK getMachineCode] ?: @"");
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_MACHINE_CODE" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"getLicenseStatus" isEqualToString:call.method]) {
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        result([FaceRecognitionSDK getLicenseStatus] ?: @"{}");
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_LICENSE_STATUS" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"setActivation" isEqualToString:call.method]) {
    NSString *license = FRSStringArg(args, @"license");
    if (license.length == 0 && [call.arguments isKindOfClass:[NSString class]]) {
      license = (NSString *)call.arguments;
    }
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        result(@([FaceRecognitionSDK setActivation:license ?: @""]));
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_ACTIVATION" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"init" isEqualToString:call.method]) {
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        result(@([FaceRecognitionSDK initSDK]));
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_INIT" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"deinit" isEqualToString:call.method]) {
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        [FaceRecognitionSDK deinitSDK];
        result(nil);
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_DEINIT" message:e.reason details:nil]);
      }
#else
      result(nil);
#endif
    });
  } else if ([@"lastLicenseError" isEqualToString:call.method]) {
#ifdef FRS_HAS_SDK
    result([FaceRecognitionSDK lastLicenseError] ?: @"");
#else
    result(@"");
#endif
  } else if ([@"setLandmarkMode" isEqualToString:call.method]) {
    NSNumber *mode = FRSNumberArg(args, @"mode", nil);
    if (mode == nil && [call.arguments isKindOfClass:[NSNumber class]]) {
      mode = (NSNumber *)call.arguments;
    }
    if (mode == nil) {
      mode = @(68);
    }
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      result(@([FaceRecognitionSDK setLandmarkMode:mode.intValue]));
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"getLandmarkMode" isEqualToString:call.method]) {
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      result(@([FaceRecognitionSDK landmarkMode]));
#else
      result(@(68));
#endif
    });
  } else if ([@"detect" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    BOOL crop = FRSBoolArg(args, @"crop", NO);
    NSNumber *flags = FRSNumberArg(args, @"flags", @(-1));
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        UIImage *image = FRSFixOrientation(FRSImageFromUriOrBase64(imageUri));
        if (image == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not decode image" details:nil]);
          return;
        }
        NSUInteger flagBits = flags.unsignedIntegerValue;
        NSString *json = nil;
        if (flags.intValue < 0) {
          json = [FaceRecognitionSDK detectImage:image crop:crop flags:FaceRecognitionDetectAll];
        } else {
          json = [FaceRecognitionSDK detectImage:image crop:crop flags:flagBits];
        }
        result(json ?: @"{}");
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_DETECT" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"faceDetection" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    NSString *paramJson = FRSParamJsonFromArg(args[@"param"]);
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        UIImage *image = FRSFixOrientation(FRSImageFromUriOrBase64(imageUri));
        if (image == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not decode image" details:nil]);
          return;
        }
        FaceRecognitionDetectFlags flags = FRSFlagsFromParamJSON(paramJson ?: @"");
        NSString *json = [FaceRecognitionSDK detectImage:image crop:NO flags:flags];
        NSArray *boxes = FRSBoxesFromDetectJSON(json);
        result(FRSJsonString(boxes));
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_FACE_DETECTION" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"templateExtraction" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    NSString *faceBoxJson = FRSStringArg(args, @"faceBox");
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        UIImage *full = FRSFixOrientation(FRSImageFromUriOrBase64(imageUri));
        if (full == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not decode image" details:nil]);
          return;
        }
        NSString *json = [FaceRecognitionSDK extractFeatureFromImage:full];
        NSString *b64 = FRSFeatureB64FromExtractJSON(json);
        if (b64 == nil && faceBoxJson.length > 0) {
          NSData *data = [faceBoxJson dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary *box = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
          UIImage *cropped = FRSCropFace(full, box);
          if (cropped != nil) {
            json = [FaceRecognitionSDK extractFeatureFromImage:cropped];
            b64 = FRSFeatureB64FromExtractJSON(json);
          }
        }
        if (b64 == nil) {
          result([FlutterError errorWithCode:@"E_TEMPLATE"
                                     message:@"extractFeature returned no feature"
                                     details:nil]);
          return;
        }
        result(b64);
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_TEMPLATE" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"cropFace" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    NSString *faceBoxJson = FRSStringArg(args, @"faceBox");
    dispatch_async(FRSQueue(), ^{
      @try {
        UIImage *image = FRSFixOrientation(FRSImageFromUriOrBase64(imageUri));
        if (image == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not decode image" details:nil]);
          return;
        }
        NSData *data = [faceBoxJson dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *box = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        UIImage *cropped = FRSCropFace(image, box);
        NSString *b64 = FRSJpegBase64(cropped);
        if (b64 == nil) {
          result([FlutterError errorWithCode:@"E_CROP" message:@"cropFace failed" details:nil]);
          return;
        }
        result(b64);
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_CROP" message:e.reason details:nil]);
      }
    });
  } else if ([@"extractFeature" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        UIImage *image = FRSFixOrientation(FRSImageFromUriOrBase64(imageUri));
        if (image == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not decode image" details:nil]);
          return;
        }
        result([FaceRecognitionSDK extractFeatureFromImage:image] ?: @"{}");
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_FEATURE" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"similarity" isEqualToString:call.method]) {
    NSString *feature1B64 = FRSStringArg(args, @"feature1");
    NSString *feature2B64 = FRSStringArg(args, @"feature2");
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        NSData *f1 = [[NSData alloc] initWithBase64EncodedString:feature1B64 ?: @""
                                                         options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSData *f2 = [[NSData alloc] initWithBase64EncodedString:feature2B64 ?: @""
                                                         options:NSDataBase64DecodingIgnoreUnknownCharacters];
        result(@([FaceRecognitionSDK similarityWithFeature1:f1 feature2:f2]));
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_SIMILARITY" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"quality" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    BOOL crop = FRSBoolArg(args, @"crop", NO);
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        UIImage *image = FRSFixOrientation(FRSImageFromUriOrBase64(imageUri));
        if (image == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not decode image" details:nil]);
          return;
        }
        result([FaceRecognitionSDK qualityImage:image crop:crop] ?: @"{}");
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_QUALITY" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"startVideoWorker" isEqualToString:call.method]) {
    NSString *configJson = FRSStringArg(args, @"config");
    __weak FaceRecognitionSdkPlugin *weakSelf = self;
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        float threshold = 0.67f;
        if (configJson.length > 0) {
          NSData *data = [configJson dataUsingEncoding:NSUTF8StringEncoding];
          NSDictionary *cfg = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
          if ([cfg isKindOfClass:[NSDictionary class]] && cfg[@"matchThreshold"] != nil) {
            threshold = [cfg[@"matchThreshold"] floatValue];
          }
        }
        [FaceRecognitionSDK stopVideoWorker];
        [FaceRecognitionSDK setVideoWorkerEventHandler:^(NSString *json) {
          FaceRecognitionSdkPlugin *strongSelf = weakSelf;
          if (strongSelf == nil) {
            return;
          }
          [strongSelf emitVideoWorkerEvent:json];
        }];
        FaceRecognitionVideoWorkerConfig *config =
            [FaceRecognitionVideoWorkerConfig configWithMatchThreshold:threshold];
        // Tracking-only (demo Identify/Capture) — active liveness off.
        FaceRecognitionActiveLivenessConfig *al =
            [FaceRecognitionActiveLivenessConfig defaultConfig];
        al.enabled = NO;
        config.activeLiveness = al;
        int code = [FaceRecognitionSDK startVideoWorkerWithConfig:config];
        result(@(code));
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_VIDEO_WORKER" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"stopVideoWorker" isEqualToString:call.method]) {
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      [FaceRecognitionSDK stopVideoWorker];
      [FaceRecognitionSDK setVideoWorkerEventHandler:nil];
#endif
      self->videoFrameBusy = NO;
      result(nil);
    });
  } else if ([@"syncVideoWorkerDatabase" isEqualToString:call.method]) {
    id featuresArg = args[@"features"];
    NSNumber *matchThreshold = FRSNumberArg(args, @"matchThreshold", @(0.67));
    NSArray *featuresB64 = [featuresArg isKindOfClass:[NSArray class]] ? (NSArray *)featuresArg : @[];
    dispatch_async(FRSQueue(), ^{
#ifdef FRS_HAS_SDK
      @try {
        NSMutableArray<NSData *> *features = [NSMutableArray array];
        for (id item in featuresB64) {
          if (![item isKindOfClass:[NSString class]]) continue;
          NSData *d = [[NSData alloc] initWithBase64EncodedString:(NSString *)item
                                                          options:NSDataBase64DecodingIgnoreUnknownCharacters];
          if (d != nil) {
            [features addObject:d];
          }
        }
        int code = [FaceRecognitionSDK syncVideoWorkerDatabaseWithFeatures:features
                                                            matchThreshold:matchThreshold.floatValue];
        result(@(code));
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_SYNC_DB" message:e.reason details:nil]);
      }
#else
      result(FRSMissingSdkError());
#endif
    });
  } else if ([@"probeLiveImage" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @try {
        UIImage *raw = FRSImageFromUriOrBase64(imageUri);
        UIImage *baked = FRSBakeOrientation(raw);
        if (baked == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not decode image" details:nil]);
          return;
        }
        CGFloat w = baked.size.width * baked.scale;
        CGFloat h = baked.size.height * baked.scale;
        result(@{ @"width": @(w), @"height": @(h) });
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_IMAGE" message:e.reason details:nil]);
      }
    });
  } else if ([@"applyLiveFrame" isEqualToString:call.method]) {
    NSString *imageUri = FRSStringArg(args, @"image");
    NSNumber *rotateDegrees = FRSNumberArg(args, @"rotateDegrees", @(0));
    NSNumber *maxEdge = FRSNumberArg(args, @"maxEdge", @(640));
    BOOL feedWorker = FRSBoolArg(args, @"feedWorker", NO);
#ifdef FRS_HAS_SDK
    if (feedWorker && self->videoFrameBusy) {
      result(FRSLiveFrameResult(self->lastLiveImage, NO, nil));
      return;
    }
    if (feedWorker) {
      self->videoFrameBusy = YES;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @try {
        UIImage *raw = FRSImageFromUriOrBase64(imageUri);
        UIImage *image = FRSApplyLiveTransform(
            raw, rotateDegrees.doubleValue, maxEdge.doubleValue);
        if (image == nil) {
          if (feedWorker) {
            self->videoFrameBusy = NO;
          }
          result([FlutterError errorWithCode:@"E_IMAGE"
                                     message:@"Could not prepare live camera frame"
                                     details:nil]);
          return;
        }
        self->lastLiveImage = image;
        self->lastLiveWidth = (NSInteger)(image.size.width * image.scale);
        self->lastLiveHeight = (NSInteger)(image.size.height * image.scale);
        if (feedWorker) {
          result(FRSLiveFrameResult(image, YES, nil));
          dispatch_async(FRSQueue(), ^{
            @try {
              (void)[FaceRecognitionSDK addVideoWorkerFrame:image];
            } @catch (__unused NSException *e) {
            }
            self->videoFrameBusy = NO;
          });
        } else {
          NSString *path = FRSWriteTempJpeg(image, 0.9);
          if (path == nil) {
            result([FlutterError errorWithCode:@"E_IMAGE"
                                       message:@"Could not prepare live camera frame"
                                       details:nil]);
            return;
          }
          result(FRSLiveFrameResult(image, YES, path));
        }
      } @catch (NSException *e) {
        if (feedWorker) {
          self->videoFrameBusy = NO;
        }
        result([FlutterError errorWithCode:@"E_FRAME" message:e.reason details:nil]);
      }
    });
#else
    result(FRSLiveFrameResult(nil, NO, imageUri));
#endif
  } else if ([@"exportLastLiveFrame" isEqualToString:call.method]) {
#ifdef FRS_HAS_SDK
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @try {
        UIImage *image = self->lastLiveImage;
        if (image == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"No live frame" details:nil]);
          return;
        }
        NSString *path = FRSWriteTempJpeg(image, 0.92);
        if (path == nil) {
          result([FlutterError errorWithCode:@"E_IMAGE" message:@"Could not export live frame" details:nil]);
          return;
        }
        result(FRSLiveFrameResult(image, YES, path));
      } @catch (NSException *e) {
        result([FlutterError errorWithCode:@"E_FRAME" message:e.reason details:nil]);
      }
    });
#else
    result(FRSMissingSdkError());
#endif
  } else if ([@"writeStatus" isEqualToString:call.method]) {
    NSString *json = FRSStringArg(args, @"payload");
    if (json.length == 0 && [call.arguments isKindOfClass:[NSString class]]) {
      json = (NSString *)call.arguments;
    }
    @try {
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      NSString *path = [paths[0] stringByAppendingPathComponent:@"facerecognition_status.json"];
      NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
      [data writeToFile:path atomically:YES];
      result(nil);
    } @catch (NSException *e) {
      result([FlutterError errorWithCode:@"E_STATUS" message:e.reason details:nil]);
    }
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
