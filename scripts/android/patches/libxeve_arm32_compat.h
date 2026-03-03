#ifndef ARM32_COMPAT_H
#define ARM32_COMPAT_H
#include <arm_neon.h>

#if !defined(__aarch64__)
// Pairwise add
static inline int32x4_t vpaddq_s32(int32x4_t a, int32x4_t b) {
    return vcombine_s32(vpadd_s32(vget_low_s32(a), vget_high_s32(a)), vpadd_s32(vget_low_s32(b), vget_high_s32(b)));
}
static inline uint32x4_t vpaddq_u32(uint32x4_t a, uint32x4_t b) {
    return vcombine_u32(vpadd_u32(vget_low_u32(a), vget_high_u32(a)), vpadd_u32(vget_low_u32(b), vget_high_u32(b)));
}

// Zip
static inline int16x8_t vzip1q_s16(int16x8_t a, int16x8_t b) { return vzipq_s16(a, b).val[0]; }
static inline int16x8_t vzip2q_s16(int16x8_t a, int16x8_t b) { return vzipq_s16(a, b).val[1]; }
static inline uint16x8_t vzip1q_u16(uint16x8_t a, uint16x8_t b) { return vzipq_u16(a, b).val[0]; }
static inline uint16x8_t vzip2q_u16(uint16x8_t a, uint16x8_t b) { return vzipq_u16(a, b).val[1]; }

static inline int32x4_t vzip1q_s32(int32x4_t a, int32x4_t b) { return vzipq_s32(a, b).val[0]; }
static inline int32x4_t vzip2q_s32(int32x4_t a, int32x4_t b) { return vzipq_s32(a, b).val[1]; }
static inline uint32x4_t vzip1q_u32(uint32x4_t a, uint32x4_t b) { return vzipq_u32(a, b).val[0]; }
static inline uint32x4_t vzip2q_u32(uint32x4_t a, uint32x4_t b) { return vzipq_u32(a, b).val[1]; }

static inline int64x2_t vzip1q_s64(int64x2_t a, int64x2_t b) { return vcombine_s64(vget_low_s64(a), vget_low_s64(b)); }
static inline int64x2_t vzip2q_s64(int64x2_t a, int64x2_t b) { return vcombine_s64(vget_high_s64(a), vget_high_s64(b)); }
static inline uint64x2_t vzip1q_u64(uint64x2_t a, uint64x2_t b) { return vcombine_u64(vget_low_u64(a), vget_low_u64(b)); }
static inline uint64x2_t vzip2q_u64(uint64x2_t a, uint64x2_t b) { return vcombine_u64(vget_high_u64(a), vget_high_u64(b)); }

// Unzip
static inline int32x4_t vuzp1q_s32(int32x4_t a, int32x4_t b) { return vuzpq_s32(a, b).val[0]; }
static inline int32x4_t vuzp2q_s32(int32x4_t a, int32x4_t b) { return vuzpq_s32(a, b).val[1]; }
#endif

#endif