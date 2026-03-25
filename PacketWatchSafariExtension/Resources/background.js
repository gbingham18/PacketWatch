// background.js
//
// Safari Extension background script.
// Listens for page navigations and reports domains to the native app.

browser.webNavigation.onCompleted.addListener((details) => {
    // Only track main frame navigations, not iframes
    if (details.frameId !== 0) {
        return;
    }
    
    // Skip browser internal pages
    if (details.url.startsWith('about:') || details.url.startsWith('safari:')) {
        return;
    }
    
    try {
        const url = new URL(details.url);
        
        // Send domain to native Swift handler
        browser.runtime.sendNativeMessage("application.id", {
            type: "navigation",
            domain: url.hostname,
            timestamp: Date.now()
        }, (response) => {
            // Optional: handle response from Swift
            if (browser.runtime.lastError) {
                console.error("Error sending message:", browser.runtime.lastError);
            }
        });
    } catch (e) {
        console.error("Error parsing URL:", e);
    }
});

// Optional: Track when tabs become active
browser.tabs.onActivated.addListener((activeInfo) => {
    browser.tabs.get(activeInfo.tabId, (tab) => {
        if (tab.url && !tab.url.startsWith('about:')) {
            try {
                const url = new URL(tab.url);
                browser.runtime.sendNativeMessage("application.id", {
                    type: "tabActivated",
                    domain: url.hostname,
                    timestamp: Date.now()
                });
            } catch (e) {
                // Ignore invalid URLs
            }
        }
    });
});
