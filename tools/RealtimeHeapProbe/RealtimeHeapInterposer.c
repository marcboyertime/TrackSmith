#include <execinfo.h>
#include <malloc/malloc.h>
#include <stdint.h>
#include <stdlib.h>

// This probe is injected only into the development host process. The armed state is
// thread-local so unrelated Swift/runtime activity on utility threads cannot create
// a false render-thread failure.
static _Thread_local uint64_t laa_heap_operation_count;
static _Thread_local uint64_t laa_allocation_count;
static _Thread_local uint64_t laa_deallocation_count;
static _Thread_local uintptr_t laa_first_caller;
static _Thread_local uint32_t laa_first_kind;
static _Thread_local void *laa_first_backtrace[16];
static _Thread_local uint32_t laa_first_backtrace_count;
static _Thread_local int laa_heap_probe_armed;

void laa_rt_heap_probe_begin(void) {
    laa_heap_operation_count = 0;
    laa_allocation_count = 0;
    laa_deallocation_count = 0;
    laa_first_caller = 0;
    laa_first_kind = 0;
    laa_first_backtrace_count = 0;
    laa_heap_probe_armed = 1;
}

uint64_t laa_rt_heap_probe_end(void) {
    laa_heap_probe_armed = 0;
    return laa_heap_operation_count;
}

uint64_t laa_rt_heap_probe_allocation_count(void) {
    return laa_allocation_count;
}

uint64_t laa_rt_heap_probe_deallocation_count(void) {
    return laa_deallocation_count;
}

uintptr_t laa_rt_heap_probe_first_caller(void) {
    return laa_first_caller;
}

uint32_t laa_rt_heap_probe_first_kind(void) {
    return laa_first_kind;
}

uint32_t laa_rt_heap_probe_backtrace_count(void) {
    return laa_first_backtrace_count;
}

uintptr_t laa_rt_heap_probe_backtrace_frame(uint32_t index) {
    if (index >= laa_first_backtrace_count) {
        return 0;
    }
    return (uintptr_t)laa_first_backtrace[index];
}

static inline void laa_record_heap_operation(uint32_t kind) {
    if (laa_heap_probe_armed) {
        if (laa_heap_operation_count == 0) {
            laa_first_kind = kind;
            // Stack capture is diagnostic-only after a failure is already known.
            // Disarm around it so the unwinder cannot recursively affect the count.
            laa_heap_probe_armed = 0;
            const int captured = backtrace(laa_first_backtrace, 16);
            laa_first_backtrace_count = captured > 0 ? (uint32_t)captured : 0;
            laa_first_caller = laa_first_backtrace_count > 0
                ? (uintptr_t)laa_first_backtrace[0]
                : 0;
            laa_heap_probe_armed = 1;
        }
        ++laa_heap_operation_count;
        if (kind == 4) {
            ++laa_deallocation_count;
        } else {
            ++laa_allocation_count;
        }
    }
}

static void *laa_probe_malloc(size_t size) {
    laa_record_heap_operation(1);
    return malloc(size);
}

static void *laa_probe_calloc(size_t count, size_t size) {
    laa_record_heap_operation(2);
    return calloc(count, size);
}

static void *laa_probe_realloc(void *pointer, size_t size) {
    laa_record_heap_operation(3);
    return realloc(pointer, size);
}

static void laa_probe_free(void *pointer) {
    laa_record_heap_operation(4);
    free(pointer);
}

static void *laa_probe_valloc(size_t size) {
    laa_record_heap_operation(5);
    return valloc(size);
}

static int laa_probe_posix_memalign(void **pointer, size_t alignment, size_t size) {
    laa_record_heap_operation(6);
    return posix_memalign(pointer, alignment, size);
}

static void *laa_probe_aligned_alloc(size_t alignment, size_t size) {
    laa_record_heap_operation(7);
    return aligned_alloc(alignment, size);
}

static void *laa_probe_reallocf(void *pointer, size_t size) {
    laa_record_heap_operation(8);
    return reallocf(pointer, size);
}

static void *laa_probe_zone_malloc(malloc_zone_t *zone, size_t size) {
    laa_record_heap_operation(9);
    return malloc_zone_malloc(zone, size);
}

static void *laa_probe_zone_calloc(malloc_zone_t *zone, size_t count, size_t size) {
    laa_record_heap_operation(10);
    return malloc_zone_calloc(zone, count, size);
}

static void *laa_probe_zone_valloc(malloc_zone_t *zone, size_t size) {
    laa_record_heap_operation(11);
    return malloc_zone_valloc(zone, size);
}

static void *laa_probe_zone_realloc(malloc_zone_t *zone, void *pointer, size_t size) {
    laa_record_heap_operation(12);
    return malloc_zone_realloc(zone, pointer, size);
}

static void laa_probe_zone_free(malloc_zone_t *zone, void *pointer) {
    laa_record_heap_operation(4);
    malloc_zone_free(zone, pointer);
}

static void *laa_probe_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size) {
    laa_record_heap_operation(13);
    return malloc_zone_memalign(zone, alignment, size);
}

#define LAA_DYLD_INTERPOSE(replacement, replacee)                                      \
    __attribute__((used)) static struct {                                              \
        const void *replacement;                                                       \
        const void *replacee;                                                          \
    } laa_interpose_##replacee __attribute__((section("__DATA,__interpose"))) = {      \
        (const void *)(uintptr_t)&replacement,                                         \
        (const void *)(uintptr_t)&replacee                                             \
    }

LAA_DYLD_INTERPOSE(laa_probe_malloc, malloc);
LAA_DYLD_INTERPOSE(laa_probe_calloc, calloc);
LAA_DYLD_INTERPOSE(laa_probe_realloc, realloc);
LAA_DYLD_INTERPOSE(laa_probe_free, free);
LAA_DYLD_INTERPOSE(laa_probe_valloc, valloc);
LAA_DYLD_INTERPOSE(laa_probe_posix_memalign, posix_memalign);
LAA_DYLD_INTERPOSE(laa_probe_aligned_alloc, aligned_alloc);
LAA_DYLD_INTERPOSE(laa_probe_reallocf, reallocf);
LAA_DYLD_INTERPOSE(laa_probe_zone_malloc, malloc_zone_malloc);
LAA_DYLD_INTERPOSE(laa_probe_zone_calloc, malloc_zone_calloc);
LAA_DYLD_INTERPOSE(laa_probe_zone_valloc, malloc_zone_valloc);
LAA_DYLD_INTERPOSE(laa_probe_zone_realloc, malloc_zone_realloc);
LAA_DYLD_INTERPOSE(laa_probe_zone_free, malloc_zone_free);
LAA_DYLD_INTERPOSE(laa_probe_zone_memalign, malloc_zone_memalign);
