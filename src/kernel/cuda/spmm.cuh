/*
 *
 */

#ifndef DGL_KERNEL_CUDA_SPMM_CUH_
#define DGL_KERNEL_CUDA_SPMM_CUH_

#include <minigun/minigun.h>
#include "../graph/unit_graph.h"
#include "../util.h"

namespace dgl {
namespace kernel {
namespace cuda {

/*
 * This func do the followings:
 *   1. Convert flattened index to multi-dimension index
 *      according to output shape (assume row-major).
 *   2. Convert multi-dimension index to flattened index for lhs.
 *   3. Convert multi-dimension index to flattened index for rhs.
 */
__device__ __forceinline__ void UnravelRavel(
    const int64_t idx, const int ndim, const int64_t* out_shape, const int64_t* out_stride,
    const int64_t* lhs_shape, const int64_t* lhs_stride,
    const int64_t* rhs_shape, const int64_t* rhs_stride, int64_t *lhs_out, int64_t *rhs_out) {
  if (out_stride[0] == lhs_stride[0]) {
#pragma unroll
    for (int d = 0; d < ndim; ++d) {
      int64_t o_sh = out_shape[d];
      int64_t o_st = out_stride[d];
      int64_t rhs_sh = rhs_shape[d];
      int64_t rhs_st = rhs_stride[d];
      int64_t i = (idx / o_st) % o_sh;
      /*
       * Simplfied for rhs_out += min(i, rhs_sh - 1) * rhs_st;
       * rhs_sh be o_sh or 1
       */
      if (rhs_sh > i) {
        *rhs_out += i * rhs_st;
      }
    }
    *lhs_out = idx;
  } else {
#pragma unroll
    for (int d = 0; d < ndim; ++d) {
      int64_t o_sh = out_shape[d];
      int64_t o_st = out_stride[d];
      int64_t lhs_sh = lhs_shape[d];
      int64_t lhs_st = lhs_stride[d];

      int64_t i = (idx / o_st) % o_sh;
      /*
       * Simplfied for lhs_out += min(i, lhs_sh - 1) * lhs_st;
       * lhs_sh be o_sh or 1
       */
      if (lhs_sh > i) {
        *lhs_out += i * lhs_st;
      }
    }
    *rhs_out = idx;
  }
}

template <typename Idx, typename DType,
          typename BinaryOp, typename ReduceOp>
__global__ void SpMMCooKernel(
  DType *nfeat, DType *efeat, DType *out,
  Idx *row, Idx *col, Idx* edge_map,
  int64_t N, int64_t M, int64_t E,
  int64_t *nfeat_shp, int64_t efeat_shp, int64_t out_shp,
  int64_t nfeat_dim, int64_t efeat_dim, int64_t out_dim,
  int64_t nfeat_stride, int64_t efeat_stride, int64_t out_stride) {
  // SPMM with COO.
  const Idx ty = blockIdx.y * blockDim.y + threadIdx.y;
  const Idx stride_y = blockDim.y * gridDim.y;
  while (ty < E) {
    const Idx src = _ldg(row + ty);
    const Idx dst = _ldg(col + ty);
    const Idx eid = _ldg(edge_map + ty);
    const len = 4; // TODO(zihao): change it
    {
      int64_t tx = blockIdx.x * blockDim.x + threadIdx.x;
      const int64_t stride_x = blockDim.x * gridDim.x;
      const int64_t len = gdata->data_len;
      Idx lid = src;
      Idx rid = eid;
      Idx oid = dst;
      DType* lhsoff = nfeat + lid * nfeat_stride * len; //data with len size
      DType* rhsoff = efeat + rid * efeat_stride * len;
      DType* outoff = out + oid * out_stride * len;
      while (tx < out_stride) {
        int64_t lhs_add = 0;
        int64_t rhs_add = 0;
        /*
        UnravelRavel(tx, gdata->ndim, gdata->out_shape, gdata->out_stride,
            gdata->lhs_shape, gdata->lhs_stride,
            gdata->rhs_shape, gdata->rhs_stride, &lhs_add, &rhs_add);
        */
        DType out = BinaryOp::Call(lhsoff + lhs_add * len, rhsoff + rhs_add * len, len);
        outoff[tx] = out; // TODO(zihao): atomic
        tx += stride_x;
      }
    }
    ty += stride_y;
  }
}

template <typename Idx, typename DType,
          typename BinaryOp, typename ReduceOp>
__global__ void SpMMCsrKernel(
    DType *nfeat, DType *efeat, DType *out,
    Idx *indptr, Idx *indices, Idx *eid,
    int64_t *nfeat_shp, int64_t efeat_shp, int64_t out_shp,
    int64_t nfeat_dim, int64_t efeat_dim, int64_t out_dim) {
) {

}

template <int XPU, int NDim, typename Idx, typename DType,
          typename BinaryOp, typename ReduceOp>
void SpMMCoo(
    dgl::aten::COOMatrix coo,
    NDArray nfeat,
    NDArray efeat,
    NDArray out) {

}

template <int XPU, int NDim, typename Idx, typename DType,
          typename BinaryOp, typename ReduceOp>
void SpMMCsr(
    dgl::aten::CSRMatrix csr,
    NDArray nfeat,
    NDArray efeat,
    NDArray out) {

}

template <int XPU, int NDim, typename Idx, typename DType,
          typename ReduceOp>
void CallSPMM(
  const UnitGraph* graph,
  BcastGData<NDim, Idx, DType>* gdata,
  NDArray nfeat,
  NDArray efeat,
  NDArray out,
  const SparseFormat preferred_format = SparseFormat::kCsc,
  ) {
  
)


}
}
}

#endif