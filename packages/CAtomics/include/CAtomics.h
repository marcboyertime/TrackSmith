#ifndef LAA_C_ATOMICS_H
#define LAA_C_ATOMICS_H

#include <stdint.h>

typedef struct LAAAtomicUInt64 LAAAtomicUInt64;

LAAAtomicUInt64 *laa_atomic_u64_create(uint64_t initial_value);
void laa_atomic_u64_destroy(LAAAtomicUInt64 *value);
uint64_t laa_atomic_u64_load_relaxed(const LAAAtomicUInt64 *value);
uint64_t laa_atomic_u64_load_acquire(const LAAAtomicUInt64 *value);
void laa_atomic_u64_store_relaxed(LAAAtomicUInt64 *value, uint64_t new_value);
void laa_atomic_u64_store_release(LAAAtomicUInt64 *value, uint64_t new_value);

#endif
