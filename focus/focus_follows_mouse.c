#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>

/*
 * Conservative focus-follows-mouse helper.
 *
 * This prototype uses public CoreGraphics window metadata to find the window
 * under the pointer and Accessibility APIs to request focus. It does not
 * synthesize clicks or call a window raise action.
 */

static const useconds_t poll_delay_us = 150000;
static const CFTimeInterval focus_delay_seconds = 0.30;
static volatile sig_atomic_t should_stop = 0;

static void handle_signal(int signal_number) {
    (void)signal_number;
    should_stop = 1;
}

static Boolean check_accessibility_permission(Boolean prompt) {
    const void *keys[] = { kAXTrustedCheckOptionPrompt };
    const void *values[] = { prompt ? kCFBooleanTrue : kCFBooleanFalse };
    CFDictionaryRef options = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        1,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );

    Boolean trusted = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);
    return trusted;
}

static void wait_for_accessibility_permission(void) {
    if (check_accessibility_permission(true)) {
        return;
    }

    fprintf(stderr, "Accessibility permission is required.\n");
    fprintf(stderr, "Open System Settings > Privacy & Security > Accessibility, then allow focus-follows-mouse or Terminal.\n");
    fflush(stderr);

    while (!should_stop && !check_accessibility_permission(false)) {
        sleep(5);
    }
}

static bool mouse_button_is_down(void) {
    return CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft) ||
           CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonRight) ||
           CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonCenter);
}

static bool point_in_rect(CGPoint point, CGRect rect) {
    return point.x >= rect.origin.x &&
           point.y >= rect.origin.y &&
           point.x < rect.origin.x + rect.size.width &&
           point.y < rect.origin.y + rect.size.height;
}

static bool dictionary_get_int(CFDictionaryRef dictionary, const void *key, int *value) {
    CFNumberRef number = CFDictionaryGetValue(dictionary, key);
    if (number == NULL) {
        return false;
    }
    return CFNumberGetValue(number, kCFNumberIntType, value);
}

static bool dictionary_get_pid(CFDictionaryRef dictionary, const void *key, pid_t *value) {
    int raw_value = 0;
    if (!dictionary_get_int(dictionary, key, &raw_value)) {
        return false;
    }
    *value = (pid_t)raw_value;
    return true;
}

static bool dictionary_get_rect(CFDictionaryRef dictionary, const void *key, CGRect *rect) {
    CFDictionaryRef bounds = CFDictionaryGetValue(dictionary, key);
    if (bounds == NULL) {
        return false;
    }
    return CGRectMakeWithDictionaryRepresentation(bounds, rect);
}

static pid_t window_owner_under_pointer(CGPoint point) {
    CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    if (windows == NULL) {
        return 0;
    }

    pid_t result = 0;
    CFIndex count = CFArrayGetCount(windows);
    for (CFIndex index = 0; index < count; index++) {
        CFDictionaryRef window = CFArrayGetValueAtIndex(windows, index);
        int layer = 0;
        pid_t pid = 0;
        CGRect bounds = CGRectNull;

        if (!dictionary_get_int(window, kCGWindowLayer, &layer) || layer != 0) {
            continue;
        }
        if (!dictionary_get_pid(window, kCGWindowOwnerPID, &pid) || pid == getpid()) {
            continue;
        }
        if (!dictionary_get_rect(window, kCGWindowBounds, &bounds) || CGRectIsEmpty(bounds)) {
            continue;
        }
        if (point_in_rect(point, bounds)) {
            result = pid;
            break;
        }
    }

    CFRelease(windows);
    return result;
}

static bool ax_rect_contains_point(AXUIElementRef window, CGPoint point) {
    CFTypeRef position_value = NULL;
    CFTypeRef size_value = NULL;
    CGPoint position = CGPointZero;
    CGSize size = CGSizeZero;

    if (AXUIElementCopyAttributeValue(window, kAXPositionAttribute, &position_value) != kAXErrorSuccess ||
        position_value == NULL) {
        return false;
    }
    if (AXUIElementCopyAttributeValue(window, kAXSizeAttribute, &size_value) != kAXErrorSuccess ||
        size_value == NULL) {
        CFRelease(position_value);
        return false;
    }

    bool ok = AXValueGetValue(position_value, kAXValueCGPointType, &position) &&
              AXValueGetValue(size_value, kAXValueCGSizeType, &size);

    CFRelease(position_value);
    CFRelease(size_value);

    if (!ok) {
        return false;
    }

    CGRect rect = CGRectMake(position.x, position.y, size.width, size.height);
    return point_in_rect(point, rect);
}

static bool focus_accessibility_window(pid_t pid, CGPoint point) {
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    if (app == NULL) {
        return false;
    }

    bool focused = false;
    CFTypeRef windows_value = NULL;
    if (AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, &windows_value) == kAXErrorSuccess &&
        windows_value != NULL &&
        CFGetTypeID(windows_value) == CFArrayGetTypeID()) {
        CFArrayRef windows = (CFArrayRef)windows_value;
        CFIndex count = CFArrayGetCount(windows);
        for (CFIndex index = 0; index < count; index++) {
            AXUIElementRef window = (AXUIElementRef)CFArrayGetValueAtIndex(windows, index);
            if (!ax_rect_contains_point(window, point)) {
                continue;
            }

            AXError window_result = AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute, window);
            AXError app_result = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute, kCFBooleanTrue);
            if (window_result == kAXErrorSuccess || app_result == kAXErrorSuccess) {
                focused = true;
            }
            break;
        }
    }

    if (windows_value != NULL) {
        CFRelease(windows_value);
    }

    if (!focused) {
        AXError app_result = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute, kCFBooleanTrue);
        focused = app_result == kAXErrorSuccess;
    }

    CFRelease(app);
    return focused;
}

int main(void) {
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    signal(SIGPIPE, SIG_IGN);

    wait_for_accessibility_permission();
    if (should_stop) {
        return 0;
    }

    pid_t focused_pid = 0;
    pid_t pending_pid = 0;
    CFTimeInterval pending_since = 0.0;

    printf("focus-follows-mouse is running: hover a window to focus it.\n");
    fflush(stdout);

    while (!should_stop) {
        CGEventRef event = CGEventCreate(NULL);
        if (event == NULL) {
            usleep(poll_delay_us);
            continue;
        }

        CGPoint point = CGEventGetLocation(event);
        CFRelease(event);

        if (mouse_button_is_down()) {
            pending_pid = 0;
            usleep(poll_delay_us);
            continue;
        }

        pid_t target_pid = window_owner_under_pointer(point);
        CFTimeInterval now = CFAbsoluteTimeGetCurrent();

        if (target_pid == 0 || target_pid == focused_pid) {
            pending_pid = 0;
            usleep(poll_delay_us);
            continue;
        }

        if (target_pid != pending_pid) {
            pending_pid = target_pid;
            pending_since = now;
            usleep(poll_delay_us);
            continue;
        }

        if (now - pending_since >= focus_delay_seconds) {
            if (focus_accessibility_window(target_pid, point)) {
                focused_pid = target_pid;
            }
            pending_pid = 0;
        }

        usleep(poll_delay_us);
    }

    printf("focus-follows-mouse stopped.\n");
    return 0;
}
