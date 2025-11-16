package org.savvycan.utils;

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
 */
public class DbcFileManager {
    private static final String TAG = "DbcFileManager";
    private static final String PREFS_NAME = "savvycan_dbc_prefs";
    private static final String KEY_DBC_URIS = "dbc_file_uris";
    
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
                try {
                    context.getContentResolver().takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    );
                    Log.d(TAG, "Took persistent URI permission for: " + uriString);
                } catch (SecurityException e) {
                    Log.w(TAG, "Could not take persistent permission for: " + uriString, e);
                    // Continue anyway - some URIs might not support persistent permissions
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
}
