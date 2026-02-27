package com.flutteriptv.flutter_iptv

import android.util.Log
import java.net.HttpURLConnection
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import javax.net.ssl.HostnameVerifier

/**
 * 统一的302重定向解析工具类
 * 用于所有Android TV播放器组件
 */
object RedirectResolver {
    private const val TAG = "RedirectResolver"
    private const val MAX_REDIRECT_DEPTH = 3
    private const val CONNECT_TIMEOUT = 2000
    private const val READ_TIMEOUT = 2000
    private const val USER_AGENT = "Wget/1.21.3"
    
    // 信任所有证书的 TrustManager（用于 IPTV 场景）
    private val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
        override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
        override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
        override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
    })
    
    // 接受所有主机名的 HostnameVerifier
    private val trustAllHostnames = HostnameVerifier { _, _ -> true }
    
    // SSL Context（延迟初始化）
    private val sslContext: SSLContext by lazy {
        SSLContext.getInstance("TLS").apply {
            init(null, trustAllCerts, java.security.SecureRandom())
        }
    }
    
    // 缓存配置
    private const val CACHE_EXPIRY_MS = 24 * 60 * 60 * 1000L // 24小时
    private val redirectCache = mutableMapOf<String, Pair<String, Long>>()
    
    /**
     * 解析真实播放地址（处理302重定向，带缓存）
     * @param url 原始URL
     * @param useCache 是否使用缓存（默认true）
     * @return 真实播放地址
     */
    fun resolveRealPlayUrl(url: String, useCache: Boolean = true): String {
        val startTime = System.currentTimeMillis()
        
        // 清理URL：去掉 $ 及其后面的内容（通常是源标签/备注）
        val cleanUrl = url.split('$').firstOrNull()?.trim() ?: url
        
        // 检查协议：只有 HTTP/HTTPS 才进行302检测
        if (!isHttpProtocol(cleanUrl)) {
            NativeLogger.d(TAG, "✓ 非HTTP协议，跳过302检查: $cleanUrl")
            return cleanUrl
        }
        
        // 检查是否是 udpxy URL（udpxy 不支持 HEAD 方法）
        if (isUdpxyUrl(cleanUrl)) {
            NativeLogger.d(TAG, "✓ 检测到udpxy URL，跳过302检查: $cleanUrl")
            return cleanUrl
        }
        
        // 检查是否是直接的流媒体URL，如果是则跳过302检查
        if (isDirectStreamUrl(cleanUrl)) {
            NativeLogger.d(TAG, "✓ 检测到直接流媒体URL，跳过302检查: $cleanUrl")
            return cleanUrl
        }
        
        // 检查缓存（使用清理后的URL作为key）
        if (useCache) {
            val cached = redirectCache[cleanUrl]
            if (cached != null) {
                val (cachedUrl, timestamp) = cached
                if (System.currentTimeMillis() - timestamp < CACHE_EXPIRY_MS) {
                    val elapsed = System.currentTimeMillis() - startTime
                    NativeLogger.d(TAG, "✓ 使用缓存的重定向 (${elapsed}ms): $cleanUrl -> $cachedUrl")
                    return cachedUrl
                } else {
                    // 缓存过期，移除
                    redirectCache.remove(cleanUrl)
                }
            }
        }
        
        // 递归解析重定向（最多3层）
        val realUrl = resolveRedirectRecursive(cleanUrl, 0, startTime)
        
        // 缓存最终结果
        if (useCache && realUrl != cleanUrl) {
            redirectCache[cleanUrl] = Pair(realUrl, System.currentTimeMillis())
        }
        
        return realUrl
    }
    
    /**
     * 检查URL是否是HTTP或HTTPS协议
     * 只有HTTP/HTTPS协议才需要进行302重定向检测
     */
    private fun isHttpProtocol(url: String): Boolean {
        return try {
            val urlObj = java.net.URL(url)
            val protocol = urlObj.protocol.lowercase()
            protocol == "http" || protocol == "https"
        } catch (e: Exception) {
            // 如果URL解析失败，保守起见返回false（不检测302）
            false
        }
    }
    
    /**
     * 检查URL是否是 udpxy 代理地址
     * udpxy 是将 UDP 组播流转换为 HTTP 流的代理服务器
     * 特征：
     * - path 格式: /rtp/IPv4:Port 或 /udp/IPv4:Port
     * - 不支持 HEAD 方法
     * - 不支持 Range 请求
     * - 不返回 Content-Length
     * 
     * 示例：
     * - http://192.168.1.1:4022/rtp/225.1.2.142:10870
     * - http://lysj.aylzline.top:8899/rtp/225.1.2.142:10870
     */
    private fun isUdpxyUrl(url: String): Boolean {
        return try {
            val urlObj = java.net.URL(url)
            val path = urlObj.path
            
            // udpxy 的 path 格式：/rtp/IPv4:Port 或 /udp/IPv4:Port
            // IPv4 格式：xxx.xxx.xxx.xxx (每段 0-255)
            // Port 格式：1-65535
            val udpxyRegex = Regex("^/(rtp|udp)/\\d{1,3}(\\.\\d{1,3}){3}:\\d+$", RegexOption.IGNORE_CASE)
            
            udpxyRegex.matches(path)
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 递归解析重定向
     */
    private fun resolveRedirectRecursive(url: String, depth: Int, startTime: Long): String {
        if (depth >= MAX_REDIRECT_DEPTH) {
            NativeLogger.w(TAG, "⚠ 达到最大重定向深度($MAX_REDIRECT_DEPTH)，停止解析: $url")
            return url
        }
        
        // 如果当前URL已经是直接流媒体地址，不再继续重定向
        if (depth > 0 && isDirectStreamUrl(url)) {
            NativeLogger.d(TAG, "✓ 第${depth}层重定向后检测到直接流媒体URL: $url")
            return url
        }
        
        return try {
            val connectStartTime = System.currentTimeMillis()
            val connection = java.net.URL(url).openConnection() as HttpURLConnection
            
            // 如果是 HTTPS 连接，跳过 SSL 证书验证（IPTV 场景常见 IP + HTTPS）
            if (connection is HttpsURLConnection) {
                connection.sslSocketFactory = sslContext.socketFactory
                connection.hostnameVerifier = trustAllHostnames
            }
            
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("User-Agent", USER_AGENT)
            connection.connectTimeout = CONNECT_TIMEOUT
            connection.readTimeout = READ_TIMEOUT
            
            connection.connect()
            val connectTime = System.currentTimeMillis() - connectStartTime
            
            val responseCode = connection.responseCode
            NativeLogger.d(TAG, "第${depth + 1}层 HTTP响应码: $responseCode")
            
            if (responseCode == 403) {
                NativeLogger.w(TAG, "收到403 Forbidden，可能User-Agent被拒绝")
            }
            
            if (responseCode in 300..399) {
                val location = connection.getHeaderField("Location")
                connection.disconnect()
                
                if (location != null) {
                    val elapsed = System.currentTimeMillis() - startTime
                    NativeLogger.d(TAG, "✓ 第${depth + 1}层重定向 (${connectTime}ms, 累计:${elapsed}ms)")
                    NativeLogger.d(TAG, "  ${depth + 1}层URL: $url")
                    NativeLogger.d(TAG, "  -> 重定向到: $location")
                    
                    // 递归解析下一层重定向
                    return resolveRedirectRecursive(location, depth + 1, startTime)
                }
            }
            
            connection.disconnect()
            val totalTime = System.currentTimeMillis() - startTime
            if (depth == 0) {
                NativeLogger.d(TAG, "✓ 无重定向 (${totalTime}ms)，响应码: $responseCode，使用原始URL: $url")
            } else {
                NativeLogger.d(TAG, "✓ 第${depth + 1}层无重定向 (累计:${totalTime}ms)，最终URL: $url")
            }
            url
        } catch (e: Exception) {
            val totalTime = System.currentTimeMillis() - startTime
            NativeLogger.e(TAG, "✗ 第${depth + 1}层解析失败 (${totalTime}ms): ${e.message}", e)
            url
        }
    }
    
    /**
     * 检查URL是否是直接的流媒体地址
     * 这些格式通常不需要302重定向，可以直接播放
     */
    private fun isDirectStreamUrl(url: String): Boolean {
        return try {
            val urlObj = java.net.URL(url)
            val path = urlObj.path.lowercase()
            
            // 常见的流媒体文件扩展名
            val streamExtensions = listOf(
                ".m3u8",   // HLS
                ".m3u",    // M3U playlist
                ".ts",     // MPEG-TS
                ".flv",    // Flash Video
                ".mp4",    // MP4
                ".mkv",    // Matroska
                ".avi",    // AVI
                ".mov",    // QuickTime
                ".wmv",    // Windows Media
                ".mpd",    // MPEG-DASH
                ".f4m",    // Flash Manifest
                ".ism",    // Smooth Streaming
                ".webm"    // WebM
            )
            
            // 检查路径是否以这些扩展名结尾
            streamExtensions.any { path.endsWith(it) }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 清除指定URL的缓存
     */
    fun clearCache(url: String) {
        redirectCache.remove(url)
        NativeLogger.d(TAG, "清除缓存: $url")
    }
    
    /**
     * 清除所有缓存
     */
    fun clearAllCache() {
        redirectCache.clear()
        NativeLogger.d(TAG, "清除所有重定向缓存")
    }
    
    /**
     * 清除过期缓存
     */
    fun clearExpiredCache() {
        val now = System.currentTimeMillis()
        val iterator = redirectCache.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            val (_, timestamp) = entry.value
            if (now - timestamp >= CACHE_EXPIRY_MS) {
                Log.d(TAG, "清除过期缓存: ${entry.key}")
                iterator.remove()
            }
        }
    }
    
    /**
     * 获取缓存统计信息
     */
    fun getCacheStats(): Map<String, Any> {
        return mapOf(
            "total" to redirectCache.size,
            "entries" to redirectCache.map { (url, pair) ->
                val (realUrl, timestamp) = pair
                val age = (System.currentTimeMillis() - timestamp) / 1000 / 60 // 分钟
                mapOf(
                    "url" to url,
                    "realUrl" to realUrl,
                    "age" to "${age}分钟"
                )
            }
        )
    }
}
