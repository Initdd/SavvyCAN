package org.savvycan;

import android.content.Intent;
import android.util.Log;
import org.qtproject.qt.android.bindings.QtActivity;
import org.savvycan.utils.DbcFileManager;

public class SavvyCANActivity extends QtActivity {
    private static final String TAG = "SavvyCANActivity";
    private DbcFileManager dbcFileManager;
    
    @Override
    public void onCreate(android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        dbcFileManager = new DbcFileManager(this);
        Log.d(TAG, "SavvyCANActivity created");
    }
    
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        Log.d(TAG, "onActivityResult: requestCode=" + requestCode + ", resultCode=" + resultCode);
        
        if (requestCode == DbcFileManager.REQUEST_CODE_OPEN_DBC_FILE) {
            if (resultCode == RESULT_OK && data != null && data.getData() != null) {
                String selectedUri = data.getData().toString();
                Log.d(TAG, "File selected: " + selectedUri);
                
                // IMPORTANT: Save the URI with persistent permission
                boolean saved = dbcFileManager.addDbcFileUri(selectedUri);
                Log.d(TAG, "URI saved with persistent permission: " + saved);
                
                // Notify C++ side via native method
                notifyFileSelected(selectedUri);
            } else {
                Log.d(TAG, "File picker cancelled");
                notifyFileSelected(null);
            }
        }
    }
    
    // Native method implemented in C++
    private native void notifyFileSelected(String uriString);
}
