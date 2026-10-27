package com.example.mymusic

import okhttp3.Headers
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import java.io.IOException
import java.util.concurrent.TimeUnit

class DownloaderImpl private constructor(private val client: OkHttpClient) : Downloader() {

    companion object {
        const val USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

        @Volatile
        private var instance: DownloaderImpl? = null

        fun init(builder: OkHttpClient.Builder? = null): DownloaderImpl {
            val b = builder ?: OkHttpClient.Builder()
            b.connectTimeout(25, TimeUnit.SECONDS)
            b.readTimeout(25, TimeUnit.SECONDS)
            b.writeTimeout(25, TimeUnit.SECONDS)
            b.followRedirects(true)
            b.followSslRedirects(true)
            val impl = DownloaderImpl(b.build())
            instance = impl
            return impl
        }

        fun getInstance(): DownloaderImpl {
            return instance ?: synchronized(this) {
                instance ?: init()
            }
        }
    }

    @Throws(IOException::class, ReCaptchaException::class)
    override fun execute(request: Request): Response {
        val httpMethod = request.httpMethod()
        val url = request.url()
        val headers = request.headers()
        val dataToSend = request.dataToSend()

        val reqBuilder = okhttp3.Request.Builder().url(url)

        val headerBuilder = Headers.Builder()
        val hasUserAgent = headers?.keys?.any { it.equals("User-Agent", ignoreCase = true) } == true
        if (!hasUserAgent) {
            headerBuilder.add("User-Agent", USER_AGENT)
        }

        if (headers != null) {
            for ((key, values) in headers) {
                for (value in values) {
                    headerBuilder.add(key, value)
                }
            }
        }
        reqBuilder.headers(headerBuilder.build())

        if (httpMethod.equals("POST", ignoreCase = true)) {
            val body = (dataToSend ?: ByteArray(0)).toRequestBody("application/json".toMediaTypeOrNull())
            reqBuilder.post(body)
        } else if (httpMethod.equals("HEAD", ignoreCase = true)) {
            reqBuilder.head()
        } else {
            reqBuilder.get()
        }

        val okResponse = client.newCall(reqBuilder.build()).execute()
        val responseCode = okResponse.code
        val responseMessage = okResponse.message
        val responseBody = okResponse.body?.string()
        val latestUrl = okResponse.request.url.toString()

        val respHeaders = HashMap<String, List<String>>()
        for (name in okResponse.headers.names()) {
            respHeaders[name] = okResponse.headers(name)
        }

        return Response(responseCode, responseMessage, respHeaders, responseBody, latestUrl)
    }
}
