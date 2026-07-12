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

struct LAAAtomicFloatArray {
    _Atomic(uint32_t) *values;
};

LAAAtomicFloatArray *laa_atomic_f32_array_create(size_t count) {
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
