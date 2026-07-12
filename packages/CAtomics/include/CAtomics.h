#ifndef LAA_C_ATOMICS_H
#define LAA_C_ATOMICS_H

#include <stddef.h>
#include <stdint.h>

typedef struct LAAAtomicUInt64 LAAAtomicUInt64;

LAAAtomicUInt64 *laa_atomic_u64_create(uint64_t initial_value);
void laa_atomic_u64_destroy(LAAAtomicUInt64 *value);
uint64_t laa_atomic_u64_load_relaxed(const LAAAtomicUInt64 *value);
uint64_t laa_atomic_u64_load_acquire(const LAAAtomicUInt64 *value);
void laa_atomic_u64_store_relaxed(LAAAtomicUInt64 *value, uint64_t new_value);
void laa_atomic_u64_store_release(LAAAtomicUInt64 *value, uint64_t new_value);

typedef struct LAAAtomicFloatArray LAAAtomicFloatArray;

LAAAtomicFloatArray *laa_atomic_f32_array_create(size_t count);
void laa_atomic_f32_array_destroy(LAAAtomicFloatArray *array);
float laa_atomic_f32_array_load_relaxed(const LAAAtomicFloatArray *array, size_t index);
void laa_atomic_f32_array_store_relaxed(LAAAtomicFloatArray *array, size_t index, float value);

#endif
