// MainActivity.kt
package com.example.recoveryapp

import android.os.Bundle
import android.os.Environment
import android.webkit.MimeTypeMap
import androidx.appcompat.app.AppCompatActivity
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity() {

    // المجلدات التي يمكن فحصها بدون Root
    private val scanDirs = listOf(
        Environment.getExternalStorageDirectory(),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
        File(Environment.getExternalStorageDirectory(), "Android/data"), // كاش التطبيقات
        File(Environment.getExternalStorageDirectory(), ".thumbnails"),
        File(Environment.getExternalStorageDirectory(), "DCIM/.thumbnails") // مصدر شائع لاستعادة الصور المحذوفة!
    )

    private val results = mutableListOf<RecoveredFile>()

    data class RecoveredFile(
        val path: String, val name: String, val sizeKb: Long,
        val lastModified: Date, val ext: String, val recoverable: Boolean
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // أذونات التخزين (مطلوبة لإصدارات أندرويد < 11 أو عبر SAF)
        requestPermissions(arrayOf(
            android.Manifest.permission.READ_EXTERNAL_STORAGE,
            android.Manifest.permission.WRITE_EXTERNAL_STORAGE), 1)

        Thread {
            scanAndReport()
        }.start()
    }

    private fun scanAndReport() {
        val imageExts = setOf("jpg","jpeg","png","gif","webp","mp4","pdf","doc","docx","txt","html","apk")

        for (dir in scanDirs) {
            if (dir.exists()) walk(dir, imageExts)
        }

        writeHtmlReport()
        runOnUiThread { android.widget.Toast.makeText(this,
            "تم إنشاء التقرير: /Download/recovery_report.html",
            android.widget.Toast.LENGTH_LONG).show() }
    }

    private fun walk(dir: File, exts: Set<String>) {
        dir.listFiles()?.forEach { f ->
            if (f.isDirectory) walk(f, exts)
            else {
                val ext = f.extension.lowercase()
                // الملفات التي تبدأ بـ "." أو الموجودة في .thumbnails تعتبر مرشحة للاستعادة
                val isCached = f.name.startsWith(".") || f.path.contains(".thumbnails")
                        || f.path.contains("cache")
                if (ext in exts || isCached) {
                    results.add(RecoveredFile(
                        f.absolutePath, f.name, f.length()/1024,
                        Date(f.lastModified()), ext.ifEmpty { "غير معروف" }, isCached
                    ))
                }
            }
        }
    }

    private fun writeHtmlReport() {
        val df = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale("ar"))
        val sb = StringBuilder()
        sb.append("<!DOCTYPE html><html dir='rtl' lang='ar'><head><meta charset='UTF-8'>")
        sb.append("<title>تقرير استعادة الملفات</title><style>")
        sb.append("body{font-family:Tahoma;direction:rtl;margin:20px;background:#f5f5f5}")
        sb.append("table{border-collapse:collapse;width:100%;background:#fff}")
        sb.append("th,td{border:1px solid #ccc;padding:8px;text-align:right}")
        sb.append("th{background:#2196F3;color:#fff}")
        sb.append(".ok{color:green;font-weight:bold}.lost{color:red}")
        sb.append("</style></head><body>")
        sb.append("<h1>تقرير استعادة الملفات — ${df.format(Date())}</h1>")
        sb.append("<p>إجمالي الملفات المرشحة: <b>${results.size}</b></p>")
        sb.append("<table><tr><th>الاسم</th><th>المسار</th><th>الحجم (KB)</th>")
        sb.append("<th>آخر تعديل</th><th>النوع</th><th>الحالة</th></tr>")

        results.sortedByDescending { it.lastModified }.forEach { r ->
            sb.append("<tr><td>${r.name}</td><td>${r.path}</td><td>${r.sizeKb}</td>")
            sb.append("<td>${df.format(r.lastModified)}</td><td>${r.ext}</td>")
            sb.append("<td class='${if (r.recoverable) "ok" else "lost"}'>")
            sb.append(if (r.recoverable) "قابل للاستعادة (كاش)" else "موجود</td></tr>")
            sb.append("</tr>")
        }
        sb.append("</table></body></html>")

        val out = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "recovery_report.html")
        FileWriter(out).use { it.write(sb.toString()) }
    }
}