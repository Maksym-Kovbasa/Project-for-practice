package com.example.project;

import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "error_log";
    private static final String LOG_DIR = "Project-for-practice";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("appendToDownloads".equals(call.method)) {
                        String filename = call.argument("filename");
                        String text = call.argument("text");
                        if (filename == null || text == null) {
                            result.error("invalid_args", "filename and text are required", null);
                            return;
                        }
                        try {
                            appendToDownloads(filename, text);
                            result.success(true);
                        } catch (IOException e) {
                            result.error("write_failed", e.getMessage(), null);
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private void appendToDownloads(String filename, String text) throws IOException {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentResolver resolver = getContentResolver();
            Uri collection = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI;
            String relativePath = Environment.DIRECTORY_DOWNLOADS + "/" + LOG_DIR + "/";
            Uri fileUri = findExistingDownload(resolver, collection, filename, relativePath);
            if (fileUri == null) {
                ContentValues values = new ContentValues();
                values.put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, filename);
                values.put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "text/plain");
                values.put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, relativePath);
                fileUri = resolver.insert(collection, values);
            }
            if (fileUri == null) {
                throw new IOException("Failed to create log file.");
            }
            try (OutputStream os = resolver.openOutputStream(fileUri, "wa")) {
                if (os == null) {
                    throw new IOException("Failed to open log file.");
                }
                os.write(text.getBytes(StandardCharsets.UTF_8));
            }
        } else {
            File downloads = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
            );
            File dir = new File(downloads, LOG_DIR);
            if (!dir.exists() && !dir.mkdirs()) {
                throw new IOException("Failed to create log directory.");
            }
            File file = new File(dir, filename);
            try (FileOutputStream fos = new FileOutputStream(file, true)) {
                fos.write(text.getBytes(StandardCharsets.UTF_8));
            }
        }
    }

    private Uri findExistingDownload(
            ContentResolver resolver,
            Uri collection,
            String filename,
            String relativePath
    ) {
        String[] projection = new String[]{android.provider.MediaStore.MediaColumns._ID};
        String selection = android.provider.MediaStore.MediaColumns.DISPLAY_NAME + "=? AND "
                + android.provider.MediaStore.MediaColumns.RELATIVE_PATH + "=?";
        String[] selectionArgs = new String[]{filename, relativePath};
        try (Cursor cursor = resolver.query(collection, projection, selection, selectionArgs, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                long id = cursor.getLong(0);
                return ContentUris.withAppendedId(collection, id);
            }
        }
        return null;
    }
}
