#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/*
 * Minimal Apple Silicon charge limiter.
 *
 * This implementation is original and uses the public SMC/IOKit interface
 * shape that community tools also target. On Apple Silicon, CHWA = 1 means
 * 80% limit and CHWA = 0 means normal 100% charging. Writing SMC keys
 * requires root.
 */

typedef struct {
    unsigned char data[80];
} SMCKeyData_t;

typedef struct {
    char key[5];
    unsigned int dataSize;
    char dataType[5];
    unsigned char bytes[32];
} SMCVal_t;

static io_connect_t conn = 0;

static unsigned int str_to_key(const char *str) {
    return ((unsigned int)str[0] << 24) |
           ((unsigned int)str[1] << 16) |
           ((unsigned int)str[2] << 8) |
           ((unsigned int)str[3]);
}

static void put_u32(SMCKeyData_t *data, size_t offset, unsigned int value) {
    memcpy(data->data + offset, &value, sizeof(value));
}

static unsigned char get_u8(const SMCKeyData_t *data, size_t offset) {
    return data->data[offset];
}

static void put_u8(SMCKeyData_t *data, size_t offset, unsigned char value) {
    data->data[offset] = value;
}

static int smc_open(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == 0) {
        fprintf(stderr, "AppleSMC driver was not found.\n");
        return 1;
    }

    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &conn);
    IOObjectRelease(service);
    if (result != kIOReturnSuccess) {
        fprintf(stderr, "Failed to open AppleSMC: %d\n", result);
        return 1;
    }
    return 0;
}

static void smc_close(void) {
    if (conn != 0) {
        IOServiceClose(conn);
        conn = 0;
    }
}

static kern_return_t smc_call(int selector, SMCKeyData_t *input, SMCKeyData_t *output) {
    size_t input_size = sizeof(SMCKeyData_t);
    size_t output_size = sizeof(SMCKeyData_t);
    memset(output, 0, sizeof(SMCKeyData_t));
    return IOConnectCallStructMethod(conn, selector, input, input_size, output, &output_size);
}

static int smc_read_size(const char *key_name, unsigned int size, SMCVal_t *val, int quiet) {
    SMCKeyData_t input;
    SMCKeyData_t output;
    memset(&input, 0, sizeof(input));
    memset(val, 0, sizeof(*val));

    strncpy(val->key, key_name, 4);
    val->key[4] = '\0';
    put_u32(&input, 0, str_to_key(key_name));
    put_u32(&input, 28, size);
    put_u8(&input, 42, 5);

    kern_return_t result = smc_call(2, &input, &output);
    unsigned char smc_result = get_u8(&output, 40);
    if (result == kIOReturnSuccess && smc_result == 0) {
        val->dataSize = size;
        memcpy(val->bytes, output.data + 48, sizeof(val->bytes));
        return 0;
    }

    if (quiet) {
        return 1;
    }
    if (smc_result == 132) {
        fprintf(stderr, "SMC key %s was not found.\n", key_name);
    } else {
        fprintf(stderr, "SMC read failed: kIOReturn=%d SMCResult=%u\n", result, smc_result);
    }
    return 1;
}

static int smc_write_size(const char *key_name, unsigned int size, unsigned char byte0, unsigned char byte1) {
    SMCKeyData_t input;
    SMCKeyData_t output;
    memset(&input, 0, sizeof(input));

    put_u32(&input, 0, str_to_key(key_name));
    put_u32(&input, 28, size);
    put_u8(&input, 42, 6);
    put_u8(&input, 48, byte0);
    put_u8(&input, 49, byte1);

    kern_return_t result = smc_call(2, &input, &output);
    unsigned char smc_result = get_u8(&output, 40);
    if (result == kIOReturnSuccess && smc_result == 0) {
        return 0;
    }
    if (result == kIOReturnNotPrivileged) {
        fprintf(stderr, "Root privileges are required. Re-run with sudo.\n");
    } else {
        fprintf(stderr, "SMC write %s failed: kIOReturn=%d SMCResult=%u\n", key_name, result, smc_result);
    }
    return 1;
}

static int has_chls(void) {
    SMCVal_t val;
    return smc_read_size("CHLS", 2, &val, 1) == 0;
}

static int has_chwa(void) {
    SMCVal_t val;
    return smc_read_size("CHWA", 1, &val, 1) == 0;
}

static int current_limit(void) {
    SMCVal_t val;
    if (smc_read_size("CHWA", 1, &val, 1) == 0) {
        return val.bytes[0] == 1 ? 80 : 100;
    }
    if (smc_read_size("CHLS", 2, &val, 1) == 0) {
        int raw = val.bytes[0];
        return raw >= 10 ? raw - 5 : 100;
    }
    fprintf(stderr, "Neither CHWA nor CHLS charge-limit SMC keys were readable.\n");
    return -1;
}

static int set_limit(int limit) {
    if (geteuid() != 0) {
        fprintf(stderr, "Root privileges are required. Re-run with sudo.\n");
        return 1;
    }
    if (has_chls()) {
        if (limit != 100 && (limit < 50 || limit > 95)) {
            fprintf(stderr, "CHLS limits must be 50-95, or 100 to disable.\n");
            return 1;
        }
        unsigned char raw = (limit == 100) ? 0 : (unsigned char)(limit + 5);
        return smc_write_size("CHLS", 2, raw, 0);
    }
    if (has_chwa()) {
        if (limit != 80 && limit != 100) {
            fprintf(stderr, "CHWA supports only 80 or 100 on this Mac.\n");
            return 1;
        }
        return smc_write_size("CHWA", 1, (limit == 80) ? 1 : 0, 0);
    }
    fprintf(stderr, "Neither CHWA nor CHLS charge-limit SMC keys were writable on this Mac.\n");
    return 1;
}

static int battery_percent(void) {
    FILE *pipe = popen("/usr/bin/pmset -g batt", "r");
    if (!pipe) {
        return -1;
    }
    char buffer[512];
    int percent = -1;
    while (fgets(buffer, sizeof(buffer), pipe)) {
        char *marker = strchr(buffer, '%');
        if (marker) {
            char *start = marker;
            while (start > buffer && start[-1] >= '0' && start[-1] <= '9') {
                start--;
            }
            percent = atoi(start);
            break;
        }
    }
    pclose(pipe);
    return percent;
}

static void print_battery_status(void) {
    FILE *pipe = popen("/usr/bin/pmset -g batt", "r");
    if (!pipe) {
        fprintf(stderr, "Could not run pmset: %s\n", strerror(errno));
        return;
    }
    char buffer[512];
    printf("Battery:\n");
    while (fgets(buffer, sizeof(buffer), pipe)) {
        printf("%s", buffer);
    }
    pclose(pipe);
}

static int apply_mode(const char *mode) {
    if (strcmp(mode, "desk") == 0) {
        return set_limit(80);
    }
    if (strcmp(mode, "travel") == 0) {
        return set_limit(100);
    }
    if (strcmp(mode, "home") == 0) {
        if (!has_chls()) {
            fprintf(stderr, "home mode needs CHLS. This Mac only exposes fixed CHWA limits.\n");
            return 1;
        }
        int percent = battery_percent();
        if (percent < 0) {
            fprintf(stderr, "Could not read battery percentage.\n");
            return 1;
        }
        int target = percent <= 60 ? 75 : 65;
        return set_limit(target);
    }
    fprintf(stderr, "Unknown mode: %s\n", mode);
    return 1;
}

static int watch_home(void) {
    if (!has_chls()) {
        fprintf(stderr, "home mode needs CHLS. This Mac only exposes fixed CHWA limits.\n");
        return 1;
    }

    int target = -1;
    while (1) {
        int percent = battery_percent();
        if (percent < 0) {
            fprintf(stderr, "Could not read battery percentage.\n");
            return 1;
        }

        int next_target = target;
        if (target < 0) {
            next_target = percent <= 60 ? 75 : 65;
        } else if (percent <= 60) {
            next_target = 75;
        } else if (percent >= 75) {
            next_target = 65;
        }

        if (next_target != target || current_limit() != next_target) {
            if (set_limit(next_target) != 0) {
                return 1;
            }
            target = next_target;
            printf("home: battery=%d%% limit=%d%% state=%s\n",
                   percent,
                   target,
                   target == 75 ? "charging-to-75" : "resting-until-60");
            fflush(stdout);
        }

        sleep(60);
    }
}

static void usage(void) {
    puts("mac-charge-limiter");
    puts("");
    puts("Usage:");
    puts("  mac-charge-limiter status");
    puts("  mac-charge-limiter read-key CHWA");
    puts("  sudo mac-charge-limiter mode desk     # 80% fixed");
    puts("  sudo mac-charge-limiter mode home     # 60-75% cycle");
    puts("  sudo mac-charge-limiter mode travel   # 100% temporary unlock");
    puts("  sudo mac-charge-limiter set 80");
    puts("  sudo mac-charge-limiter set 100");
    puts("  sudo mac-charge-limiter watch 80");
    puts("  sudo mac-charge-limiter watch-home");
    puts("");
    puts("Notes:");
    puts("  CHWA Macs support 80/100 only. CHLS Macs can use finer stop thresholds.");
    puts("  Charging can pass the limit while the Mac is shut down or in deep sleep.");
}

int main(int argc, char **argv) {
    if (argc < 2 || strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        usage();
        return 0;
    }

    if (smc_open() != 0) {
        return 1;
    }

    int exit_code = 0;

    if (strcmp(argv[1], "status") == 0) {
        print_battery_status();
        int limit = current_limit();
        if (limit < 0) {
            exit_code = 1;
        } else {
            printf("Charge limit: %d%%\n", limit);
            int percent = battery_percent();
            if (percent >= 0) {
                printf("Battery percent: %d%%\n", percent);
            }
        }
    } else if (strcmp(argv[1], "read-key") == 0) {
        if (argc != 3 || strlen(argv[2]) != 4) {
            fprintf(stderr, "Usage: mac-charge-limiter read-key CHWA\n");
            exit_code = 1;
        } else {
            SMCVal_t val;
            unsigned int size = strcmp(argv[2], "CHLS") == 0 ? 2 : 1;
            exit_code = smc_read_size(argv[2], size, &val, 0);
            if (exit_code == 0) {
                printf("%s: byte0=%u byte1=%u\n", argv[2], val.bytes[0], val.bytes[1]);
            }
        }
    } else if (strcmp(argv[1], "set") == 0) {
        if (argc != 3) {
            fprintf(stderr, "Usage: sudo mac-charge-limiter set 80\n");
            exit_code = 1;
        } else {
            int limit = atoi(argv[2]);
            exit_code = set_limit(limit);
            if (exit_code == 0) {
                printf("Charge limit set to %d%%.\n", limit);
            }
        }
    } else if (strcmp(argv[1], "mode") == 0) {
        if (argc != 3) {
            fprintf(stderr, "Usage: sudo mac-charge-limiter mode desk|home|travel\n");
            exit_code = 1;
        } else {
            exit_code = apply_mode(argv[2]);
            if (exit_code == 0) {
                printf("Mode set to %s.\n", argv[2]);
            }
        }
    } else if (strcmp(argv[1], "watch") == 0) {
        int limit = argc >= 3 ? atoi(argv[2]) : 80;
        exit_code = set_limit(limit);
        if (exit_code == 0) {
            printf("Watching charge limit at %d%%. Press Control-C to stop.\n", limit);
            fflush(stdout);
            while (1) {
                int active = current_limit();
                if (active != limit) {
                    if (set_limit(limit) == 0) {
                        printf("Reapplied %d%%.\n", limit);
                        fflush(stdout);
                    }
                }
                sleep(60);
            }
        }
    } else if (strcmp(argv[1], "watch-home") == 0) {
        exit_code = watch_home();
    } else {
        fprintf(stderr, "Unknown command: %s\n", argv[1]);
        usage();
        exit_code = 1;
    }

    smc_close();
    return exit_code;
}
