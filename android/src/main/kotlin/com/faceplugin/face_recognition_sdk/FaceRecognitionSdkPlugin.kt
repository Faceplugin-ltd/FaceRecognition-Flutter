package com.faceplugin.face_recognition_sdk

import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.util.Base64
import com.faceplugin.facerecognitionsdk.FaceBox
import com.faceplugin.facerecognitionsdk.FaceDetectionParam
import com.faceplugin.facerecognitionsdk.FaceRecognitionSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** Flutter port of RN FaceRecognitionSdkModule. */
class FaceRecognitionSdkPlugin :
  FlutterPlugin,
  MethodCallHandler,
  EventChannel.StreamHandler {

  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var appContext: android.content.Context? = null
  private var eventSink: EventChannel.EventSink? = null
  private val executor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())
  @Volatile private var lastLiveBitmap: Bitmap? = null

  private fun success(result: Result, value: Any?) {
    mainHandler.post { result.success(value) }
  }

  private fun error(result: Result, code: String, message: String?) {
    mainHandler.post { result.error(code, message, null) }
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "FaceRecognitionSdk")
    channel.setMethodCallHandler(this)
    eventChannel = EventChannel(binding.binaryMessenger, "FaceRecognitionSdk/videoWorker")
    eventChannel.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    FaceRecognitionSDK.setVideoWorkerEventHandler(null)
    eventSink = null
    appContext = null
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    val context = appContext
    if (context == null) {
      result.error("E_CONTEXT", "Plugin not attached", null)
      return
    }

    when (call.method) {
      "getMachineCode" -> executor.execute {
        try {
          success(result, FaceRecognitionSDK.getMachineCode(context) ?: "")
        } catch (t: Throwable) {
          error(result, "E_MACHINE_CODE", t.message)
        }
      }

      "getLicenseStatus" -> executor.execute {
        try {
          success(result, FaceRecognitionSDK.getLicenseStatus())
        } catch (t: Throwable) {
          error(result, "E_LICENSE_STATUS", t.message)
        }
      }

      "setActivation" -> {
        val license = when (val a = call.arguments) {
          is String -> a
          is Map<*, *> -> stringArg(a, "license") ?: ""
          else -> ""
        }
        executor.execute {
          try {
            success(result, FaceRecognitionSDK.setActivation(context, license))
          } catch (t: Throwable) {
            error(result, "E_ACTIVATION", t.message)
          }
        }
      }

      "init" -> executor.execute {
        try {
          success(result, FaceRecognitionSDK.init(context))
        } catch (t: Throwable) {
          error(result, "E_INIT", t.message)
        }
      }

      "deinit" -> executor.execute {
        try {
          FaceRecognitionSDK.deinit()
          success(result, null)
        } catch (t: Throwable) {
          error(result, "E_DEINIT", t.message)
        }
      }

      "lastLicenseError" -> {
        try {
          result.success(FaceRecognitionSDK.lastLicenseError() ?: "")
        } catch (t: Throwable) {
          error(result, "E_LICENSE_ERROR", t.message)
        }
      }

      "setLandmarkMode" -> {
        val mode = when (val a = call.arguments) {
          is Map<*, *> -> intArg(a["mode"])
          else -> intArg(a)
        } ?: 0
        executor.execute {
          try {
            success(result, FaceRecognitionSDK.setLandmarkMode(mode))
          } catch (t: Throwable) {
            error(result, "E_LANDMARK", t.message)
          }
        }
      }

      "getLandmarkMode" -> executor.execute {
        try {
          success(result, FaceRecognitionSDK.getLandmarkMode())
        } catch (t: Throwable) {
          error(result, "E_LANDMARK", t.message)
        }
      }

      "detect" -> {
        val args = call.arguments as? Map<*, *>
        val imageUri = stringArg(args, "imageUri", "image") ?: ""
        val crop = boolArg(args, "crop") ?: false
        val flags = intArg(args?.get("flags")) ?: FaceRecognitionSDK.DETECT_ALL
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            val json = if (flags == FaceRecognitionSDK.DETECT_ALL || flags < 0) {
              FaceRecognitionSDK.detect(bitmap, crop, FaceRecognitionSDK.DETECT_ALL)
            } else {
              FaceRecognitionSDK.detect(bitmap, crop, flags)
            }
            success(result, json ?: "{}")
          } catch (t: Throwable) {
            error(result, "E_DETECT", t.message)
          }
        }
      }

      "faceDetection" -> {
        val args = call.arguments as? Map<*, *>
        val imageUri = stringArg(args, "imageUri", "image") ?: ""
        // Accept JSON string or Map (Dart historically sent a Map; iOS already did).
        val paramJson = paramJsonArg(args, "paramJson", "param")
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            val boxes = FaceRecognitionSDK.faceDetection(bitmap, parseParam(paramJson))
            success(result, boxesToJson(boxes))
          } catch (t: Throwable) {
            error(result, "E_FACE_DETECTION", t.message)
          }
        }
      }

      "templateExtraction" -> {
        val args = call.arguments as? Map<*, *>
        val imageUri = stringArg(args, "imageUri", "image") ?: ""
        val faceBoxJson = stringArg(args, "faceBoxJson", "faceBox") ?: ""
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            val face = jsonToFaceBox(faceBoxJson)
              ?: run {
                error(result, "E_FACE", "Invalid face box JSON")
                return@execute
              }
            val bytes = FaceRecognitionSDK.templateExtraction(bitmap, face)
            if (bytes == null) {
              error(result, "E_TEMPLATE", "templateExtraction returned null")
              return@execute
            }
            success(result, Base64.encodeToString(bytes, Base64.NO_WRAP))
          } catch (t: Throwable) {
            error(result, "E_TEMPLATE", t.message)
          }
        }
      }

      "cropFace" -> {
        val args = call.arguments as? Map<*, *>
        val imageUri = stringArg(args, "imageUri", "image") ?: ""
        val faceBoxJson = stringArg(args, "faceBoxJson", "faceBox") ?: ""
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            val face = jsonToFaceBox(faceBoxJson)
              ?: run {
                error(result, "E_FACE", "Invalid face box JSON")
                return@execute
              }
            val cropped = FaceRecognitionSDK.cropFace(bitmap, face)
              ?: run {
                error(result, "E_CROP", "cropFace returned null")
                return@execute
              }
            success(result, bitmapToBase64Jpeg(cropped))
          } catch (t: Throwable) {
            error(result, "E_CROP", t.message)
          }
        }
      }

      "extractFeature" -> {
        val imageUri = when (val a = call.arguments) {
          is String -> a
          is Map<*, *> -> stringArg(a, "imageUri", "image") ?: ""
          else -> ""
        }
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            success(result, FaceRecognitionSDK.extractFeature(bitmap) ?: "{}")
          } catch (t: Throwable) {
            error(result, "E_FEATURE", t.message)
          }
        }
      }

      "similarity" -> {
        val args = call.arguments as? Map<*, *>
        val f1B64 = stringArg(args, "feature1", "feature1B64") ?: ""
        val f2B64 = stringArg(args, "feature2", "feature2B64") ?: ""
        executor.execute {
          try {
            val f1 = Base64.decode(f1B64, Base64.DEFAULT)
            val f2 = Base64.decode(f2B64, Base64.DEFAULT)
            success(result, FaceRecognitionSDK.similarity(f1, f2).toDouble())
          } catch (t: Throwable) {
            error(result, "E_SIMILARITY", t.message)
          }
        }
      }

      "quality" -> {
        val args = call.arguments as? Map<*, *>
        val imageUri = stringArg(args, "imageUri", "image") ?: ""
        val crop = boolArg(args, "crop") ?: false
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            success(result, FaceRecognitionSDK.quality(bitmap, crop) ?: "{}")
          } catch (t: Throwable) {
            error(result, "E_QUALITY", t.message)
          }
        }
      }

      "startVideoWorker" -> {
        val configJson = when (val a = call.arguments) {
          is String -> a
          is Map<*, *> -> stringArg(a, "configJson", "config")
          else -> null
        }
        executor.execute {
          try {
            FaceRecognitionSDK.setVideoWorkerEventHandler { json ->
              emitVideoWorkerEvent(json)
            }
            val threshold = parseMatchThreshold(configJson)
            success(result, FaceRecognitionSDK.startVideoWorker(threshold))
          } catch (t: Throwable) {
            error(result, "E_VIDEO_WORKER", t.message)
          }
        }
      }

      "stopVideoWorker" -> executor.execute {
        try {
          FaceRecognitionSDK.stopVideoWorker()
          FaceRecognitionSDK.setVideoWorkerEventHandler(null)
          success(result, null)
        } catch (t: Throwable) {
          error(result, "E_VIDEO_WORKER", t.message)
        }
      }

      "syncVideoWorkerDatabase" -> {
        val args = call.arguments as? Map<*, *>
        @Suppress("UNCHECKED_CAST")
        val features = (args?.get("features") as? List<*>)?.mapNotNull { it as? String }
          ?: emptyList()
        val matchThreshold = doubleArg(args?.get("matchThreshold")) ?: 0.67
        executor.execute {
          try {
            val list = ArrayList<ByteArray>(features.size)
            for (s in features) {
              list.add(Base64.decode(s, Base64.DEFAULT))
            }
            success(
              result,
              FaceRecognitionSDK.syncVideoWorkerDatabase(list, matchThreshold.toFloat())
            )
          } catch (t: Throwable) {
            error(result, "E_SYNC_DB", t.message)
          }
        }
      }

      "probeLiveImage" -> {
        val imageUri = when (val a = call.arguments) {
          is String -> a
          is Map<*, *> -> stringArg(a, "imageUri", "image") ?: ""
          else -> ""
        }
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            success(
              result,
              mapOf(
                "width" to bitmap.width.toDouble(),
                "height" to bitmap.height.toDouble()
              )
            )
          } catch (t: Throwable) {
            error(result, "E_IMAGE", t.message)
          }
        }
      }

      "applyLiveFrame" -> {
        val args = call.arguments as? Map<*, *>
        val imageUri = stringArg(args, "imageUri", "image") ?: ""
        val rotateDegrees = doubleArg(args?.get("rotateDegrees")) ?: 0.0
        val maxEdge = (intArg(args?.get("maxEdge")) ?: 1).coerceAtLeast(1)
        val feedWorker = boolArg(args, "feedWorker") ?: false
        executor.execute {
          try {
            val bitmap = loadBitmap(context, imageUri)
              ?: run {
                error(result, "E_IMAGE", "Could not decode image: $imageUri")
                return@execute
              }
            val prepared = applyLiveTransform(bitmap, rotateDegrees.toFloat(), maxEdge)
            lastLiveBitmap = prepared
            if (feedWorker) {
              FaceRecognitionSDK.addVideoWorkerFrame(prepared)
              success(result, liveFrameMap(prepared, ingested = true, uri = null))
            } else {
              success(
                result,
                liveFrameMap(prepared, ingested = true, uri = writeLiveJpeg(context, prepared))
              )
            }
          } catch (t: Throwable) {
            error(result, "E_FRAME", t.message)
          }
        }
      }

      "exportLastLiveFrame" -> executor.execute {
        try {
          val prepared = lastLiveBitmap
            ?: run {
              error(result, "E_IMAGE", "No live frame")
              return@execute
            }
          success(
            result,
            liveFrameMap(prepared, ingested = true, uri = writeLiveJpeg(context, prepared))
          )
        } catch (t: Throwable) {
          error(result, "E_FRAME", t.message)
        }
      }

      "writeStatus" -> {
        val json = when (val a = call.arguments) {
          is String -> a
          is Map<*, *> -> stringArg(a, "payload", "json") ?: "{}"
          else -> "{}"
        }
        try {
          val file = java.io.File(context.filesDir, "facerecognition_status.json")
          file.writeText(json)
          success(result, null)
        } catch (t: Throwable) {
          error(result, "E_STATUS", t.message)
        }
      }

      else -> result.notImplemented()
    }
  }

  private fun emitVideoWorkerEvent(json: String) {
    mainHandler.post {
      eventSink?.success(mapOf("json" to json))
    }
  }

  private fun loadBitmap(context: android.content.Context, uriOrBase64: String): Bitmap? {
    return if (uriOrBase64.startsWith("data:") || looksLikeBase64(uriOrBase64)) {
      ImageUtils.bitmapFromBase64(uriOrBase64)
    } else {
      ImageUtils.bitmapFromUri(context, uriOrBase64)
    }
  }

  private fun looksLikeBase64(s: String): Boolean {
    if (s.startsWith("content:") || s.startsWith("file:") || s.startsWith("/")) return false
    return s.length > 256 && !s.contains("://")
  }

  private fun parseParam(paramJson: String?): FaceDetectionParam {
    if (paramJson.isNullOrBlank()) return FaceDetectionParam()
    return try {
      val o = JSONObject(paramJson)
      if (o.optBoolean("allAttributes", false)) {
        return FaceDetectionParam.allAttributes().also {
          if (o.has("check_liveness_level")) {
            it.check_liveness_level = o.optInt("check_liveness_level", 0)
          }
        }
      }
      FaceDetectionParam().apply {
        check_liveness = o.optBoolean("check_liveness", check_liveness)
        check_liveness_level = o.optInt("check_liveness_level", check_liveness_level)
        check_eye_closeness = o.optBoolean("check_eye_closeness", check_eye_closeness)
        check_face_occlusion = o.optBoolean("check_face_occlusion", check_face_occlusion)
        estimate_age_gender = o.optBoolean("estimate_age_gender", estimate_age_gender)
        check_pose = o.optBoolean("check_pose", check_pose)
        check_landmarks = o.optBoolean("check_landmarks", check_landmarks)
        check_quality = o.optBoolean("check_quality", check_quality)
        check_emotion = o.optBoolean("check_emotion", check_emotion)
        check_mask = o.optBoolean("check_mask", check_mask)
        check_glasses = o.optBoolean("check_glasses", check_glasses)
      }
    } catch (_: Exception) {
      FaceDetectionParam()
    }
  }

  private fun boxesToJson(boxes: List<FaceBox>): String {
    val arr = JSONArray()
    for (b in boxes) {
      arr.put(faceBoxToJson(b))
    }
    return arr.toString()
  }

  private fun faceBoxToJson(b: FaceBox): JSONObject {
    val o = JSONObject()
    o.put("x1", b.x1)
    o.put("y1", b.y1)
    o.put("x2", b.x2)
    o.put("y2", b.y2)
    o.put("yaw", b.yaw.toDouble())
    o.put("roll", b.roll.toDouble())
    o.put("pitch", b.pitch.toDouble())
    o.put("liveness", b.liveness.toDouble())
    o.put("face_quality", b.face_quality.toDouble())
    o.put("face_luminance", b.face_luminance.toDouble())
    o.put("left_eye_closed", b.left_eye_closed.toDouble())
    o.put("right_eye_closed", b.right_eye_closed.toDouble())
    o.put("face_occlusion", b.face_occlusion.toDouble())
    o.put("mouth_opened", b.mouth_opened.toDouble())
    o.put("age", b.age)
    o.put("gender", b.gender)
    o.put("livenessLabel", formatAttrDisplay(b.livenessLabel ?: ""))
    o.put("genderLabel", formatAttrDisplay(b.genderLabel ?: ""))
    o.put("emotionLabel", formatAttrDisplay(b.emotionLabel ?: ""))
    o.put("maskLabel", formatAttrDisplay(b.maskLabel ?: ""))
    o.put("qualityLabel", formatAttrDisplay(b.qualityLabel ?: ""))
    o.put("eyesLeftLabel", formatAttrDisplay(b.eyesLeftLabel ?: ""))
    o.put("eyesRightLabel", formatAttrDisplay(b.eyesRightLabel ?: ""))
    val attrs = JSONObject()
    for ((key, value) in b.extraAttributes) {
      if (key.isNotBlank() && !value.isNullOrBlank()) {
        attrs.put(key, formatAttrDisplay(value))
      }
    }
    o.put("attributes", attrs)
    o.put(
      "glassesLabel",
      formatAttrDisplay(
        b.extraAttributes["Glasses"]
          ?: b.extraAttributes["glasses"]
          ?: ""
      )
    )
    o.put(
      "sunglassesLabel",
      formatAttrDisplay(
        b.extraAttributes["Sunglasses"]
          ?: b.extraAttributes["sunglasses"]
          ?: ""
      )
    )
    o.put(
      "occlusionLabel",
      formatAttrDisplay(
        b.extraAttributes["Occlusion"]
          ?: b.extraAttributes["FaceOcclusion"]
          ?: b.extraAttributes["occlusion"]
          ?: ""
      )
    )
    o.put("landmarkCount", b.landmarkCount)
    val lm = JSONArray()
    val n = (b.landmarkCount * 2).coerceAtMost(b.landmarks_68.size)
    for (i in 0 until n) {
      lm.put(b.landmarks_68[i].toDouble())
    }
    o.put("landmarks", lm)
    return o
  }

  private fun jsonToFaceBox(json: String): FaceBox? {
    return try {
      val o = JSONObject(json)
      FaceBox().apply {
        x1 = o.optInt("x1")
        y1 = o.optInt("y1")
        x2 = o.optInt("x2")
        y2 = o.optInt("y2")
        yaw = o.optDouble("yaw").toFloat()
        roll = o.optDouble("roll").toFloat()
        pitch = o.optDouble("pitch").toFloat()
        liveness = o.optDouble("liveness").toFloat()
        face_quality = o.optDouble("face_quality").toFloat()
        left_eye_closed = o.optDouble("left_eye_closed").toFloat()
        right_eye_closed = o.optDouble("right_eye_closed").toFloat()
        face_occlusion = o.optDouble("face_occlusion").toFloat()
        age = o.optInt("age")
        gender = o.optInt("gender")
        landmarkCount = o.optInt("landmarkCount")
        val lm = o.optJSONArray("landmarks")
        if (lm != null) {
          val n = lm.length().coerceAtMost(landmarks_68.size)
          for (i in 0 until n) {
            landmarks_68[i] = lm.optDouble(i).toFloat()
          }
        }
      }
    } catch (_: Exception) {
      null
    }
  }

  private fun parseMatchThreshold(configJson: String?): Float {
    if (configJson.isNullOrBlank()) return 0.67f
    return try {
      JSONObject(configJson).optDouble("matchThreshold", 0.67).toFloat()
    } catch (_: Exception) {
      0.67f
    }
  }

  private fun bitmapToBase64Jpeg(bitmap: Bitmap): String {
    val out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
    return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
  }

  private fun liveFrameMap(
    prepared: Bitmap,
    ingested: Boolean,
    uri: String?
  ): Map<String, Any?> {
    return mapOf(
      "ingested" to ingested,
      "width" to prepared.width.toDouble(),
      "height" to prepared.height.toDouble(),
      "uri" to uri
    )
  }

  private fun writeLiveJpeg(context: android.content.Context, prepared: Bitmap): String {
    val file = java.io.File(context.cacheDir, "frs_live_${System.currentTimeMillis()}.jpg")
    file.outputStream().use { out ->
      prepared.compress(Bitmap.CompressFormat.JPEG, 85, out)
    }
    return "file://${file.absolutePath}"
  }

  /** Rotate by degrees then scale long edge ≤ maxEdge. */
  private fun applyLiveTransform(src: Bitmap, rotateDegrees: Float, maxEdge: Int): Bitmap {
    var frame = src
    val deg = rotateDegrees % 360f
    if (kotlin.math.abs(deg) > 0.01f) {
      val matrix = Matrix().apply { postRotate(deg) }
      val rotated = Bitmap.createBitmap(frame, 0, 0, frame.width, frame.height, matrix, true)
      if (rotated !== frame && frame !== src) frame.recycle()
      frame = rotated
    }
    return scaleMax(frame, maxEdge)
  }

  private fun scaleMax(src: Bitmap, maxEdge: Int): Bitmap {
    val w = src.width
    val h = src.height
    val edge = maxOf(w, h)
    if (edge <= maxEdge) return src
    val scale = maxEdge.toFloat() / edge
    return Bitmap.createScaledBitmap(src, (w * scale).toInt(), (h * scale).toInt(), true)
  }

  /** Convert Android "Happy (0.95)" → iOS-style "Happy · 95%". */
  private fun formatAttrDisplay(raw: String): String {
    val value = raw.trim()
    if (value.isEmpty() || value.contains(" · ")) return value
    val m = Regex("""^(.+?)\s*\(([0-9]*\.?[0-9]+)\)\s*$""").matchEntire(value) ?: return value
    val conf = m.groupValues[2].toDoubleOrNull() ?: return value
    if (conf < 0.0 || conf > 1.0) return value
    return "${m.groupValues[1].trim()} · ${(conf * 100).toInt()}%"
  }

  private fun stringArg(args: Map<*, *>?, vararg keys: String): String? {
    if (args == null) return null
    for (key in keys) {
      val v = args[key] as? String
      if (v != null) return v
    }
    return null
  }

  /** FaceDetection param as JSON string or Flutter Map → JSONObject string. */
  private fun paramJsonArg(args: Map<*, *>?, vararg keys: String): String? {
    if (args == null) return null
    for (key in keys) {
      when (val v = args[key]) {
        is String -> if (v.isNotBlank()) return v
        is Map<*, *> -> {
          try {
            return JSONObject(v as Map<*, *>).toString()
          } catch (_: Exception) {
            // try next key
          }
        }
      }
    }
    return null
  }

  private fun boolArg(args: Map<*, *>?, key: String): Boolean? {
    return when (val v = args?.get(key)) {
      is Boolean -> v
      is Number -> v.toInt() != 0
      else -> null
    }
  }

  private fun intArg(value: Any?): Int? {
    return when (value) {
      is Int -> value
      is Long -> value.toInt()
      is Double -> value.toInt()
      is Float -> value.toInt()
      is Number -> value.toInt()
      is String -> value.toIntOrNull()
      else -> null
    }
  }

  private fun doubleArg(value: Any?): Double? {
    return when (value) {
      is Double -> value
      is Float -> value.toDouble()
      is Int -> value.toDouble()
      is Long -> value.toDouble()
      is Number -> value.toDouble()
      is String -> value.toDoubleOrNull()
      else -> null
    }
  }
}
