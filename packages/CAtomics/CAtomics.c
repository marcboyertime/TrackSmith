#include "CAtomics.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

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
uint64_t laa_atomic_u64_fetch_add_release(LAAAtomicUInt64 *value, uint64_t increment) {
    return atomic_fetch_add_explicit(&value->value, increment, memory_order_release);
}
int32_t laa_atomic_u64_is_lock_free(const LAAAtomicUInt64 *value) { return atomic_is_lock_free(&value->value) ? 1 : 0; }

struct LAAAtomicPointer { _Atomic(uintptr_t) value; };

LAAAtomicPointer *laa_atomic_pointer_create(void *initial_value) {
    LAAAtomicPointer *result = malloc(sizeof(LAAAtomicPointer));
    if (result != NULL) atomic_init(&result->value, (uintptr_t)initial_value);
    return result;
}

void laa_atomic_pointer_destroy(LAAAtomicPointer *value) { free(value); }

void *laa_atomic_pointer_load_acquire(const LAAAtomicPointer *value) {
    return (void *)atomic_load_explicit(&value->value, memory_order_acquire);
}

void laa_atomic_pointer_store_release(LAAAtomicPointer *value, void *new_value) {
    atomic_store_explicit(&value->value, (uintptr_t)new_value, memory_order_release);
}
int32_t laa_atomic_pointer_is_lock_free(const LAAAtomicPointer *value) { return atomic_is_lock_free(&value->value) ? 1 : 0; }

struct LAAAtomicFloatArray {
    _Atomic(uint32_t) *values;
};

LAAAtomicFloatArray *laa_atomic_f32_array_create(size_t count) {
    if (count == 0 || count > SIZE_MAX / sizeof(_Atomic(uint32_t))) return NULL;
    LAAAtomicFloatArray *array = malloc(sizeof(LAAAtomicFloatArray));
    if (array == NULL) return NULL;
    array->values = malloc(sizeof(_Atomic(uint32_t)) * count);
    if (array->values == NULL) {
        free(array);
        return NULL;
    }
    for (size_t index = 0; index < count; ++index) atomic_init(&array->values[index], 0);
    return array;
}

void laa_atomic_f32_array_destroy(LAAAtomicFloatArray *array) {
    if (array == NULL) return;
    free(array->values);
    free(array);
}

float laa_atomic_f32_array_load_relaxed(const LAAAtomicFloatArray *array, size_t index) {
    uint32_t bits = atomic_load_explicit(&array->values[index], memory_order_relaxed);
    float value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

void laa_atomic_f32_array_store_relaxed(LAAAtomicFloatArray *array, size_t index, float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    atomic_store_explicit(&array->values[index], bits, memory_order_relaxed);
}

int32_t laa_atomic_f32_array_is_lock_free(const LAAAtomicFloatArray *array) {
    if (array == NULL || array->values == NULL) return 0;
    return atomic_is_lock_free(&array->values[0]) ? 1 : 0;
}
