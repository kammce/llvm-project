// RUN: mlir-opt %s \
// RUN: -one-shot-bufferize="bufferize-function-boundaries" \
// RUN: -buffer-deallocation-pipeline -convert-bufferization-to-memref \
// RUN: -convert-scf-to-cf -expand-strided-metadata -lower-affine -convert-cf-to-llvm -convert-arith-to-llvm \
// RUN: -finalize-memref-to-llvm -convert-func-to-llvm -reconcile-unrealized-casts | \
// RUN: mlir-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_runner_utils,%mlir_c_runner_utils \
// RUN: | FileCheck %s


func.func @main() {
  %const = arith.constant dense<[[[-3.9058,0.9072],[-2.9470,-2.2055],[18.3946,8.2997],[3.4700,5.9006],[-17.2267,4.9777],[1.0450,-0.8201]],[[17.6996,-11.1763],[26.7775,-3.8823],[-4.2492,-5.8966],[2.1259,13.1794],[-10.7136,0.8428],[16.4233,9.4589]]]> : tensor<2x6x2xf32>
  %dynamic = tensor.cast %const: tensor<2x6x2xf32> to tensor<2x?x?xf32>
  %expanded = call @expand_dynamic_shape(%dynamic) : (tensor<2x?x?xf32>) -> (tensor<2x2x?x1x?xf32>)
  %unranked = tensor.cast %expanded: tensor<2x2x?x1x?xf32> to tensor<*xf32>
  call @printMemrefF32(%unranked) : (tensor<*xf32>) -> ()

  //      CHECK: Unranked Memref base@ = {{0x[-9a-f]*}}
  // CHECK-SAME: rank = 5 offset = 0 sizes = [2, 2, 3, 1, 2] strides = [12, 6, 2, 2, 1] data =
  // CHECK-NEXT{LITERAL}: [[[[[-3.9058,      0.9072]],
  // CHECK-NEXT{LITERAL}:   [[-2.947,      -2.2055]],
  // CHECK-NEXT{LITERAL}:   [[18.3946,      8.2997]]],
  // CHECK-NEXT{LITERAL}:  [[[3.47,      5.9006]],
  // CHECK-NEXT{LITERAL}:   [[-17.2267,      4.9777]],
  // CHECK-NEXT{LITERAL}:   [[1.045,      -0.8201]]]],
  // CHECK-NEXT{LITERAL}: [[[[17.6996,      -11.1763]],
  // CHECK-NEXT{LITERAL}:   [[26.7775,      -3.8823]],
  // CHECK-NEXT{LITERAL}:   [[-4.2492,      -5.8966]]],
  // CHECK-NEXT{LITERAL}:  [[[2.1259,      13.1794]],
  // CHECK-NEXT{LITERAL}:   [[-10.7136,      0.8428]],
  // CHECK-NEXT{LITERAL}:   [[16.4233,      9.4589]]]]]
  return
}

func.func private @printMemrefF32(%ptr : tensor<*xf32>)

func.func @expand_dynamic_shape(%arg0 : tensor<2x?x?xf32>) -> tensor<2x2x?x1x?xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c2 = arith.constant 2 : index
  %d1 = tensor.dim %arg0, %c1 : tensor<2x?x?xf32>
  %d2 = tensor.dim %arg0, %c2 : tensor<2x?x?xf32>
  %sz1 = arith.divui %d1, %c2 : index
  %0 = tensor.expand_shape %arg0 [[0], [1, 2, 3], [4]] output_shape [2, 2, %sz1, 1, %d2] : tensor<2x?x?xf32> into tensor<2x2x?x1x?xf32>
  return %0 : tensor<2x2x?x1x?xf32>
}
