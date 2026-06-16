#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/*
 * X11-ish selection helper for macOS.
 *
 * - Left-drag release sends Cmd+C after a short delay.
 * - Middle mouse click sends Cmd+V and swallows the middle-click event.
 *
 * This is not a real PRIMARY selection. macOS does not have X11's selection
 * buffer, so this deliberately uses the normal clipboard.
 */

static const int copy_keycode = 8;   // C
static const int paste_keycode = 9;  // V
static const double drag_threshold_points = 6.0;
static const useconds_t copy_delay_us = 85000;

static int left_down = 0;
static int left_dragged = 0;
static CGPoint left_down_point = {0, 0};
static CFMachPortRef global_event_tap = NULL;

static void post_key_combo(int keycode) {
    CGEventRef cmd_down = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)55, true);
    CGEventRef key_down = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keycode, true);
    CGEventRef key_up = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keycode, false);
    CGEventRef cmd_up = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)55, false);

    if (!cmd_down || !key_down || !key_up || !cmd_up) {
        if (cmd_down) CFRelease(cmd_down);
        if (key_down) CFRelease(key_down);
        if (key_up) CFRelease(key_up);
        if (cmd_up) CFRelease(cmd_up);
        return;
    }

    CGEventSetFlags(key_down, kCGEventFlagMaskCommand);
    CGEventSetFlags(key_up, kCGEventFlagMaskCommand);

    CGEventPost(kCGHIDEventTap, cmd_down);
    CGEventPost(kCGHIDEventTap, key_down);
    CGEventPost(kCGHIDEventTap, key_up);
    CGEventPost(kCGHIDEventTap, cmd_up);

    CFRelease(cmd_down);
    CFRelease(key_down);
    CFRelease(key_up);
    CFRelease(cmd_up);
}

static void copy_after_selection_settles(void) {
    usleep(copy_delay_us);
    post_key_combo(copy_keycode);
}

static CGEventRef event_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    (void)proxy;
    (void)refcon;

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (global_event_tap) {
            CGEventTapEnable(global_event_tap, true);
        }
        return event;
    }

    if (type == kCGEventLeftMouseDown) {
        left_down = 1;
        left_dragged = 0;
        left_down_point = CGEventGetLocation(event);
        return event;
    }

    if (type == kCGEventLeftMouseDragged && left_down) {
        CGPoint point = CGEventGetLocation(event);
        double dx = point.x - left_down_point.x;
        double dy = point.y - left_down_point.y;
        if (sqrt(dx * dx + dy * dy) >= drag_threshold_points) {
            left_dragged = 1;
        }
        return event;
    }

    if (type == kCGEventLeftMouseUp) {
        int should_copy = left_down && left_dragged;
        left_down = 0;
        left_dragged = 0;
        if (should_copy) {
            copy_after_selection_settles();
        }
        return event;
    }

    if (type == kCGEventOtherMouseDown || type == kCGEventOtherMouseUp) {
        int64_t button = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
        if (button == 2) {
            if (type == kCGEventOtherMouseDown) {
                post_key_combo(paste_keycode);
            }
            return NULL;
        }
    }

    return event;
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
    fprintf(stderr, "Open System Settings > Privacy & Security > Accessibility, then allow selection-paste or Terminal.\n");
    fflush(stderr);

    while (!check_accessibility_permission(false)) {
        sleep(5);
    }
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);

    wait_for_accessibility_permission();

    CGEventMask mask =
        CGEventMaskBit(kCGEventLeftMouseDown) |
        CGEventMaskBit(kCGEventLeftMouseDragged) |
        CGEventMaskBit(kCGEventLeftMouseUp) |
        CGEventMaskBit(kCGEventOtherMouseDown) |
        CGEventMaskBit(kCGEventOtherMouseUp);

    CFMachPortRef event_tap = CGEventTapCreate(
        kCGHIDEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        mask,
        event_callback,
        NULL
    );

    if (!event_tap) {
        fprintf(stderr, "Could not create event tap. Check Accessibility permission.\n");
        return 1;
    }
    global_event_tap = event_tap;

    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, event_tap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CGEventTapEnable(event_tap, true);

    printf("selection-paste is running: drag selects copy, middle-click pastes.\n");
    fflush(stdout);

    CFRunLoopRun();

    CFRelease(source);
    CFRelease(event_tap);
    return 0;
}
