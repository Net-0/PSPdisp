APPS   := app-a app-b
CC     := gcc
CFLAGS := -Wall -Wextra -std=c17 -g
BUILD  := build

BINS :=

define APP_RULES
$1_SRCS := $$(wildcard $1/src/*.c)
$1_OBJS := $$($1_SRCS:%.c=$(BUILD)/%.o)
$1_BIN  := $(BUILD)/$1/$1

BINS += $$($1_BIN)

$(BUILD)/$1/%.o: $1/%.c
	@mkdir -p $$(dir $$@)
	$(CC) $(CFLAGS) $$($1_CFLAGS) $$(addprefix -I,$$($1_INCLUDES)) -MMD -MP -c $$< -o $$@

$$($1_BIN): $$($1_OBJS)
	@mkdir -p $$(dir $$@)
	$(CC) $$^ -o $$@ $$($1_LDLIBS)

.PHONY: $1
$1: $$($1_BIN)
endef

include $(foreach a,$(APPS),$a/app.mk)
$(foreach a,$(APPS),$(eval $(call APP_RULES,$a)))

.PHONY: all clean
all: $(BINS)
clean:
	rm -rf $(BUILD)

-include $(shell find $(BUILD) -name '*.d' 2>/dev/null)