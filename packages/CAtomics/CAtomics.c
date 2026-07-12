#include "CAtomics.h"
#include <stdatomic.h>
#include <stdlib.h>

struct LAAAtomicUInt64 { _Atomic(uint64_t) value; };

LAAAtomicUInt64 *laa_atomic_u64_create(uint64_t initial_value) {
    LAAAtomicUInt64 *result = malloc(sizeof(LAAAtomicUInt64));
    if (result != NULL) atomic_init(&result->value, initial_value);
    return result;
}

void laa_atomic_u64_destroy(LAAAtomicUInt64 *value) { free(value); }
uint64_t laa_atomic_u64_load_relaxed(const LAAAtomicUInt64 *value) { return atomic_load_explicit(&value->value, memory_order_relaxed); }
uint64_t laa_atomic_u64_load_acquire(const LAAAtomicUInt64 *value) { return atomic_load_explicit(&value->value, memory_order_acquire); }
void laa_atomic_u64_store_relaxed(LAAAtomicUInt64 *value, uint64_t new_value) { atomic_store_explicit(&value->value, new_value, memory_order_relaxed); }
void laa_atomic_u64_store_release(LAAAtomicUInt64 *value, uint64_t new_value) { atomic_store_explicit(&value->value, new_value, memory_order_release); }
