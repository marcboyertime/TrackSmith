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
uint64_t laa_atomic_u64_fetch_add_release(LAAAtomicUInt64 *value, uint64_t increment);
int32_t laa_atomic_u64_is_lock_free(const LAAAtomicUInt64 *value);

typedef struct LAAAtomicPointer LAAAtomicPointer;

LAAAtomicPointer *laa_atomic_pointer_create(void *initial_value);
void laa_atomic_pointer_destroy(LAAAtomicPointer *value);
void *laa_atomic_pointer_load_acquire(const LAAAtomicPointer *value);
void laa_atomic_pointer_store_release(LAAAtomicPointer *value, void *new_value);
int32_t laa_atomic_pointer_is_lock_free(const LAAAtomicPointer *value);

typedef struct LAAAtomicFloatArray LAAAtomicFloatArray;

LAAAtomicFloatArray *laa_atomic_f32_array_create(size_t count);
void laa_atomic_f32_array_destroy(LAAAtomicFloatArray *array);
float laa_atomic_f32_array_load_relaxed(const LAAAtomicFloatArray *array, size_t index);
void laa_atomic_f32_array_store_relaxed(LAAAtomicFloatArray *array, size_t index, float value);
int32_t laa_atomic_f32_array_is_lock_free(const LAAAtomicFloatArray *array);

#endif
