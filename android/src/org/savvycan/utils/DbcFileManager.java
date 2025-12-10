package org.savvycan.utils;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Log;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Manages persistent DBC file URIs for the SavvyCAN Android app.
 * This class handles:
 * - Saving DBC file URIs to SharedPreferences
 * - Taking persistent URI permissions from Android's Storage Access Framework
 * - Validating URIs on app startup and removing invalid ones
 * - Restoring saved DBC file URIs when the app resumes
 * - Opening native Android file picker with proper permission requests
 */
public class DbcFileManager {
    private static final String TAG = "DbcFileManager";
    private static final String PREFS_NAME = "savvycan_dbc_prefs";
    private static final String KEY_DBC_URIS = "dbc_file_uris";
    public static final int REQUEST_CODE_OPEN_DBC_FILE = 1001;
    
    private Context context;
    private SharedPreferences prefs;
    
    public DbcFileManager(Context context) {
        this.context = context;
        this.prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }
    
    /**
     * Save a DBC file URI and take persistent permission if possible.
     * @param uriString The URI string to save
     * @return true if successfully saved, false otherwise
     */
    public boolean addDbcFileUri(String uriString) {
        try {
            Uri uri = Uri.parse(uriString);
            
            // Try to take persistent permission for content:// URIs
            if ("content".equals(uri.getScheme())) {
                boolean permissionGranted = false;
                try {
                    context.getContentResolver().takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    );
                    Log.d(TAG, "Took persistent URI permission for: " + uriString);
                    permissionGranted = true;
                } catch (SecurityException e) {
                    Log.e(TAG, "FAILED to take persistent permission for: " + uriString, e);
                }
                
                // Only save if we successfully obtained persistent permission
                if (!permissionGranted) {
                    Log.e(TAG, "Cannot save URI without persistent permission: " + uriString);
                    return false;
                }
            }
            
            // Get current set of URIs
            Set<String> uris = getSavedUris();
            
            // Add new URI
            uris.add(uriString);
            
            // Save back to preferences
            SharedPreferences.Editor editor = prefs.edit();
            editor.putStringSet(KEY_DBC_URIS, uris);
            boolean success = editor.commit();
            
            if (success) {
                Log.d(TAG, "Saved DBC URI: " + uriString);
            } else {
                Log.e(TAG, "Failed to save DBC URI: " + uriString);
            }
            
            return success;
        } catch (Exception e) {
            Log.e(TAG, "Error adding DBC file URI: " + uriString, e);
            return false;
        }
    }
    
    /**
     * Remove a DBC file URI and release its persistent permission.
     * @param uriString The URI string to remove
     * @return true if successfully removed, false otherwise
     */
    public boolean removeDbcFileUri(String uriString) {
        try {
            Uri uri = Uri.parse(uriString);
            
            // Release persistent permission for content:// URIs
            if ("content".equals(uri.getScheme())) {
                try {
                    context.getContentResolver().releasePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    );
                    Log.d(TAG, "Released persistent URI permission for: " + uriString);
                } catch (SecurityException e) {
                    Log.w(TAG, "Could not release persistent permission for: " + uriString, e);
                }
            }
            
            // Get current set of URIs
            Set<String> uris = getSavedUris();
            
            // Remove URI
            boolean removed = uris.remove(uriString);
            
            if (removed) {
                // Save back to preferences
                SharedPreferences.Editor editor = prefs.edit();
                editor.putStringSet(KEY_DBC_URIS, uris);
                boolean success = editor.commit();
                
                if (success) {
                    Log.d(TAG, "Removed DBC URI: " + uriString);
                } else {
                    Log.e(TAG, "Failed to save after removing DBC URI: " + uriString);
                }
                
                return success;
            } else {
                Log.w(TAG, "DBC URI not found in saved list: " + uriString);
                return false;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error removing DBC file URI: " + uriString, e);
            return false;
        }
    }
    
    /**
     * Get all saved DBC file URIs.
     * @return Set of URI strings
     */
    private Set<String> getSavedUris() {
        Set<String> uris = prefs.getStringSet(KEY_DBC_URIS, null);
        if (uris == null) {
            return new HashSet<>();
        }
        // Return a mutable copy
        return new HashSet<>(uris);
    }
    
    /**
     * Get all saved DBC file URIs as a list.
     * @return List of URI strings
     */
    public List<String> getSavedDbcUris() {
        List<String> result = new ArrayList<>(getSavedUris());
        Log.d(TAG, "getSavedDbcUris called, returning " + result.size() + " URIs");
        for (String uri : result) {
            Log.d(TAG, "  Saved URI: " + uri);
        }
        return result;
    }
    
    /**
     * Validate that a URI is still accessible.
     * @param uriString The URI string to validate
     * @return true if the URI is accessible, false otherwise
     */
    public boolean isUriValid(String uriString) {
        try {
            Uri uri = Uri.parse(uriString);
            
            // For file:// URIs, check if file exists
            if ("file".equals(uri.getScheme())) {
                String path = uri.getPath();
                if (path != null) {
                    java.io.File file = new java.io.File(path);
                    return file.exists() && file.canRead();
                }
                return false;
            }
            
            // For content:// URIs, check if we have persistent permission
            if ("content".equals(uri.getScheme())) {
                List<android.content.UriPermission> permissions = 
                    context.getContentResolver().getPersistedUriPermissions();
                
                for (android.content.UriPermission permission : permissions) {
                    if (permission.getUri().equals(uri) && permission.isReadPermission()) {
                        // Try to actually open it to be sure
                        java.io.InputStream stream = null;
                        try {
                            stream = context.getContentResolver().openInputStream(uri);
                            return stream != null;
                        } catch (Exception e) {
                            Log.w(TAG, "URI permission exists but cannot open: " + uriString, e);
                            return false;
                        } finally {
                            if (stream != null) {
                                try {
                                    stream.close();
                                } catch (Exception e) {
                                    // Ignore close errors
                                }
                            }
                        }
                    }
                }
                
                // No persistent permission found
                Log.w(TAG, "No persistent permission for URI: " + uriString);
                return false;
            }
            
            // Unknown scheme
            Log.w(TAG, "Unknown URI scheme: " + uri.getScheme());
            return false;
        } catch (Exception e) {
            Log.e(TAG, "Error validating URI: " + uriString, e);
            return false;
        }
    }
    
    /**
     * Remove all invalid URIs from saved preferences.
     * @return List of removed URI strings
     */
    public List<String> cleanupInvalidUris() {
        List<String> removedUris = new ArrayList<>();
        Set<String> savedUris = getSavedUris();
        Set<String> validUris = new HashSet<>();
        
        for (String uriString : savedUris) {
            if (isUriValid(uriString)) {
                validUris.add(uriString);
                Log.d(TAG, "URI is valid: " + uriString);
            } else {
                removedUris.add(uriString);
                Log.w(TAG, "Removing invalid URI: " + uriString);
                
                // Try to release permission
                try {
                    Uri uri = Uri.parse(uriString);
                    if ("content".equals(uri.getScheme())) {
                        context.getContentResolver().releasePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        );
                    }
                } catch (Exception e) {
                    // Ignore errors when releasing invalid URIs
                }
            }
        }
        
        // Save cleaned list back to preferences
        if (!removedUris.isEmpty()) {
            SharedPreferences.Editor editor = prefs.edit();
            editor.putStringSet(KEY_DBC_URIS, validUris);
            editor.commit();
            Log.d(TAG, "Cleaned up " + removedUris.size() + " invalid URIs");
        }
        
        return removedUris;
    }
    
    /**
     * Extract filename from a URI for display purposes.
     * @param uriString The URI string
     * @return The filename, or the full URI if extraction fails
     */
    public String getFilenameFromUri(String uriString) {
        try {
            Uri uri = Uri.parse(uriString);
            
            // Try to get the display name from the document provider
            if ("content".equals(uri.getScheme())) {
                try {
                    android.database.Cursor cursor = context.getContentResolver().query(
                        uri, 
                        new String[]{android.provider.OpenableColumns.DISPLAY_NAME}, 
                        null, null, null
                    );
                    if (cursor != null) {
                        try {
                            if (cursor.moveToFirst()) {
                                int nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME);
                                if (nameIndex >= 0) {
                                    String displayName = cursor.getString(nameIndex);
                                    if (displayName != null && !displayName.isEmpty()) {
                                        return displayName;
                                    }
                                }
                            }
                        } finally {
                            cursor.close();
                        }
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Could not get display name for URI: " + uriString, e);
                }
            }
            
            // Fallback: try to extract from the last path segment
            String lastSegment = uri.getLastPathSegment();
            if (lastSegment != null && lastSegment.contains("/")) {
                lastSegment = lastSegment.substring(lastSegment.lastIndexOf("/") + 1);
            }
            if (lastSegment != null && !lastSegment.isEmpty()) {
                return lastSegment;
            }
            
            // If all else fails, return the full URI
            return uriString;
        } catch (Exception e) {
            Log.e(TAG, "Error extracting filename from URI: " + uriString, e);
            return uriString;
        }
    }
    
    /**
     * Clear all saved DBC file URIs and release all permissions.
     */
    public void clearAllUris() {
        Set<String> uris = getSavedUris();
        
        // Release all permissions
        for (String uriString : uris) {
            try {
                Uri uri = Uri.parse(uriString);
                if ("content".equals(uri.getScheme())) {
                    context.getContentResolver().releasePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    );
                }
            } catch (Exception e) {
                // Ignore errors
            }
        }
        
        // Clear preferences
        SharedPreferences.Editor editor = prefs.edit();
        editor.remove(KEY_DBC_URIS);
        editor.commit();
        
        Log.d(TAG, "Cleared all DBC URIs");
    }
    
    /**
     * Open Android's native file picker with proper permission flags.
     * This requests persistable URI permissions so files can be accessed after app restart.
     * 
     * @param activity The activity to start the file picker from
     * @return true if picker was launched successfully, false otherwise
     */
    public boolean openFilePicker(Activity activity) {
        try {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*");
            
            // Request these specific MIME types for DBC files
            String[] mimeTypes = {"application/octet-stream", "text/plain", "*/*"};
            intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes);
            
            // CRITICAL: Request persistable permission so we can access file after restart
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | 
                          Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
            
            activity.startActivityForResult(intent, REQUEST_CODE_OPEN_DBC_FILE);
            Log.d(TAG, "Launched native file picker with persistable permission request");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error opening file picker", e);
            return false;
        }
    }
}
