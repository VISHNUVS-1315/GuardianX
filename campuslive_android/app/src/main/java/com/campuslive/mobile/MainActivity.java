package com.campuslive.mobile;

import android.app.AlertDialog;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends android.app.Activity {
    private static final String PREFS = "campuslive_settings";
    private static final String KEY_URL = "server_url";
    private WebView webView;
    private TextView connection;
    private LinearLayout errorPanel;
    private String serverUrl;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        serverUrl = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_URL, BuildConfig.DEFAULT_URL);
        buildUi();
        configureWebView();
        loadCampusLive();
    }

    private int dp(int n) { return (int) (n * getResources().getDisplayMetrics().density + 0.5f); }

    private TextView text(String value, int size, int color) {
        TextView v = new TextView(this);
        v.setText(value); v.setTextSize(size); v.setTextColor(color); v.setGravity(Gravity.CENTER_VERTICAL);
        return v;
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.rgb(244,247,243));

        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(dp(16), dp(10), dp(10), dp(10));
        top.setBackgroundColor(Color.rgb(20,61,44));

        LinearLayout titleBox = new LinearLayout(this);
        titleBox.setOrientation(LinearLayout.VERTICAL);
        TextView title = text(BuildConfig.APP_MODE.equals("admin") ? "CampusLive Admin" : "CampusLive", 20, Color.WHITE);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        connection = text("Connecting…", 11, Color.rgb(190,225,205));
        titleBox.addView(title); titleBox.addView(connection);
        top.addView(titleBox, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        Button settings = new Button(this);
        settings.setText("⚙"); settings.setTextSize(18); settings.setContentDescription("Server settings");
        settings.setOnClickListener(v -> showServerDialog());
        top.addView(settings, new LinearLayout.LayoutParams(dp(54), dp(48)));
        root.addView(top, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        FrameLayout body = new FrameLayout(this);
        webView = new WebView(this);
        body.addView(webView, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        errorPanel = new LinearLayout(this);
        errorPanel.setOrientation(LinearLayout.VERTICAL); errorPanel.setGravity(Gravity.CENTER); errorPanel.setPadding(dp(28),dp(28),dp(28),dp(28));
        errorPanel.setBackgroundColor(Color.rgb(244,247,243)); errorPanel.setVisibility(View.GONE);
        TextView eTitle = text("CampusLive server is not reachable", 20, Color.rgb(25,50,38)); eTitle.setGravity(Gravity.CENTER); eTitle.setTypeface(null, android.graphics.Typeface.BOLD);
        TextView eInfo = text("Your app is safe. Check internet or update the server URL, then retry.", 14, Color.rgb(90,110,100)); eInfo.setGravity(Gravity.CENTER); eInfo.setPadding(0,dp(10),0,dp(18));
        Button retry = new Button(this); retry.setText("Retry"); retry.setOnClickListener(v -> loadCampusLive());
        Button server = new Button(this); server.setText("Server settings"); server.setOnClickListener(v -> showServerDialog());
        errorPanel.addView(eTitle); errorPanel.addView(eInfo); errorPanel.addView(retry, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52))); errorPanel.addView(server, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52)));
        body.addView(errorPanel, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        root.addView(body, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(root);
    }

    private void configureWebView() {
        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true); s.setDomStorageEnabled(true); s.setDatabaseEnabled(true);
        s.setLoadWithOverviewMode(true); s.setUseWideViewPort(true); s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        CookieManager.getInstance().setAcceptCookie(true); CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true);
        webView.setWebChromeClient(new WebChromeClient());
        webView.setWebViewClient(new WebViewClient() {
            @Override public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
                connection.setText("Connecting…"); errorPanel.setVisibility(View.GONE);
            }
            @Override public void onPageFinished(WebView view, String url) {
                connection.setText("Connected · " + (BuildConfig.APP_MODE.equals("admin") ? "Admin" : "Student"));
            }
            @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) { connection.setText("Offline"); errorPanel.setVisibility(View.VISIBLE); }
            }
        });
    }

    private String normalize(String u) {
        u = u == null ? "" : u.trim();
        while (u.endsWith("/")) u = u.substring(0, u.length()-1);
        return u;
    }

    private void loadCampusLive() {
        serverUrl = normalize(serverUrl);
        if (!(serverUrl.startsWith("https://") || serverUrl.startsWith("http://"))) { showServerDialog(); return; }
        errorPanel.setVisibility(View.GONE);
        webView.loadUrl(serverUrl + "/?mode=" + BuildConfig.APP_MODE);
    }

    private void showServerDialog() {
        final EditText input = new EditText(this);
        input.setSingleLine(true); input.setText(serverUrl); input.setSelectAllOnFocus(true); input.setPadding(dp(12),dp(8),dp(12),dp(8));
        LinearLayout wrap = new LinearLayout(this); wrap.setPadding(dp(20),dp(4),dp(20),0); wrap.addView(input, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        new AlertDialog.Builder(this)
            .setTitle("CampusLive server")
            .setMessage("Use the deployed HTTPS URL. For local testing, enter your computer LAN IP such as http://192.168.1.10:8000")
            .setView(wrap)
            .setPositiveButton("Save & reload", (d,w) -> {
                String value = normalize(input.getText().toString());
                if (!(value.startsWith("https://") || value.startsWith("http://"))) { Toast.makeText(this,"Enter a valid http/https URL",Toast.LENGTH_LONG).show(); return; }
                serverUrl=value; getSharedPreferences(PREFS,MODE_PRIVATE).edit().putString(KEY_URL,value).apply(); loadCampusLive();
            })
            .setNeutralButton("Default", (d,w) -> { serverUrl=BuildConfig.DEFAULT_URL; getSharedPreferences(PREFS,MODE_PRIVATE).edit().remove(KEY_URL).apply(); loadCampusLive(); })
            .setNegativeButton("Cancel", null).show();
    }

    @Override public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack(); else super.onBackPressed();
    }

    @Override protected void onDestroy() {
        if (webView != null) { webView.stopLoading(); webView.destroy(); }
        super.onDestroy();
    }
}
