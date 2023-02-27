#include <thrust/device_vector.h>

#include "../include/evaluate_laplacian.cuh"
#include "../include/basis_to_gpu.cuh"
#include "../include/cuda_basis_utils.cuh"
#include "../include/cuda_utils.cuh"
#include "../include/evaluate_density.cuh"
#include "../include/evaluate_gradient.cuh"


/// Note that these sum of second derivatives were genereated by the python file ./generate/generate_sec_derivs_cont.py
__device__ void gbasis::evaluate_sum_of_second_derivative_contractions_from_constant_memory(
    double* d_contractions_array,
    const double& grid_x,
    const double& grid_y,
    const double& grid_z,
    const int& knumb_points,
    unsigned int& global_index
) {
  // Setup the initial variables.
  int iconst = 0;                                                          // Index to go over constant memory.
  unsigned int icontractions = 0;                                         // Index to go over rows of d_contractions_array
  unsigned int numb_contracted_shells = (int) g_constant_basis[iconst++];

#pragma unroll
  for(int icontr_shell = 0; icontr_shell < numb_contracted_shells; icontr_shell++) {
    double r_A_x = (grid_x - g_constant_basis[iconst++]);
    double r_A_y = (grid_y - g_constant_basis[iconst++]);
    double r_A_z = (grid_z - g_constant_basis[iconst++]);
    //double radius_sq = pow(r_A_x, 2.0) + pow(r_A_y, 2.0) + pow(r_A_z, 2.0);
    int numb_segment_shells = (int) g_constant_basis[iconst++];
    int numb_primitives = (int) g_constant_basis[iconst++];
    // iconst from here=H+0 to H+(numb_primitives - 1) is the exponents, need this to constantly reiterate them.
    for(int i_segm_shell=0; i_segm_shell < numb_segment_shells; i_segm_shell++) {
      // Add the number of exponents, then add extra coefficients to enumerate.
      int angmom = (int) g_constant_basis[iconst + numb_primitives + (numb_primitives + 1) * i_segm_shell];
      for(int i_prim=0; i_prim < numb_primitives; i_prim++) {
        double coeff_prim = g_constant_basis[iconst + numb_primitives * (i_segm_shell + 1) + i_prim + 1 + i_segm_shell];
        double alpha = g_constant_basis[iconst + i_prim];
        double exponential = exp(- alpha * ( pow(r_A_x, 2.0) + pow(r_A_y, 2.0) + pow(r_A_z, 2.0)));
        // If S, P, D or F orbital/
        if(angmom == 0) {
          d_contractions_array[global_index + icontractions * knumb_points] +=
              gbasis::normalization_primitive_s(g_constant_basis[iconst + i_prim]) *
                  coeff_prim *
                  2*alpha*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 3) *
                  exponential;
        }
        else if (angmom == 1) {
          d_contractions_array[global_index + icontractions * knumb_points] +=
              gbasis::normalization_primitive_p(g_constant_basis[iconst + i_prim]) *
                  coeff_prim *
                  2*alpha*r_A_x*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 5) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 1) * knumb_points] +=
              gbasis::normalization_primitive_p(g_constant_basis[iconst + i_prim]) *
                  coeff_prim *
                  2*alpha*r_A_y*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 5) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 2) * knumb_points] +=
              gbasis::normalization_primitive_p(g_constant_basis[iconst + i_prim]) *
                  coeff_prim *
                  2*alpha*r_A_z*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 5) *
                  exponential;
        }
        else if (angmom == 2) {
          // The ordering is ['xx', 'yy', 'zz', 'xy', 'xz', 'yz']   Old ordering: xx, xy, xz, yy, yz, zz
          d_contractions_array[global_index + icontractions * knumb_points] +=
              gbasis::normalization_primitive_d(g_constant_basis[iconst + i_prim], 2, 0, 0) *
                  coeff_prim *
                  (4*alpha*alpha*pow(r_A_x, 4) + 4*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 4*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 14*alpha*r_A_x*r_A_x + 2) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 1) * knumb_points] +=
              gbasis::normalization_primitive_d(g_constant_basis[iconst + i_prim], 0, 2, 0) *
                  coeff_prim *
                  (4*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 4*alpha*alpha*pow(r_A_y, 4) + 4*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 14*alpha*r_A_y*r_A_y + 2) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 2) * knumb_points] +=
              gbasis::normalization_primitive_d(g_constant_basis[iconst + i_prim], 0, 0, 2) *
                  coeff_prim *
                  (4*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 4*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 4*alpha*alpha*pow(r_A_z, 4) - 14*alpha*r_A_z*r_A_z + 2) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 3) * knumb_points] +=
              gbasis::normalization_primitive_d(g_constant_basis[iconst + i_prim], 1, 1, 0) *
                  coeff_prim *
                  2*alpha*r_A_x*r_A_y*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 7) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 4) * knumb_points] +=
              gbasis::normalization_primitive_d(g_constant_basis[iconst + i_prim], 1, 0, 1) *
                  coeff_prim *
                  2*alpha*r_A_x*r_A_z*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 7) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 5) * knumb_points] +=
              gbasis::normalization_primitive_d(g_constant_basis[iconst + i_prim], 0, 1, 1) *
                  coeff_prim *
                  2*alpha*r_A_y*r_A_z*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 7) *
                  exponential;
        }
        else if (angmom == -2) {
          // Negatives are s denoting sine and c denoting cosine.
          // Fchk ordering is  ['c0', 'c1', 's1', 'c2', 's2']
          double norm_const = gbasis::normalization_primitive_pure_d(g_constant_basis[iconst + i_prim]);
          d_contractions_array[global_index + icontractions * knumb_points] +=
              norm_const *
                  coeff_prim *
                  alpha*(-2*alpha*pow(r_A_x, 4) - 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) + 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 4*alpha*pow(r_A_z, 4) + 7*r_A_x*r_A_x + 7*r_A_y*r_A_y - 14*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 1) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(3.) *
                  2*alpha*r_A_x*r_A_z*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 7) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 2) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(3.) *
                  2*alpha*r_A_y*r_A_z*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 7) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 3) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(3.) *
                  alpha*(2*alpha*pow(r_A_x, 4) + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) - 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 7*r_A_x*r_A_x + 7*r_A_y*r_A_y) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 4) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(3.) *
                  2*alpha*r_A_x*r_A_y*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 7) *
                  exponential;
        }
        else if (angmom == 3) {
          // The ordering is ['xxx', 'yyy', 'zzz', 'xyy', 'xxy', 'xxz', 'xzz', 'yzz', 'yyz', 'xyz']
          d_contractions_array[global_index + icontractions * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 3, 0, 0) *
                  coeff_prim *
                  2*r_A_x*(2*alpha*alpha*pow(r_A_x, 4) + 2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 9*alpha*r_A_x*r_A_x + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 1) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 0, 3, 0) *
                  coeff_prim *
                  2*r_A_y*(2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*pow(r_A_y, 4) + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 9*alpha*r_A_y*r_A_y + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 2) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 0, 0, 3) *
                  coeff_prim *
                  2*r_A_z*(2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 2*alpha*alpha*pow(r_A_z, 4) - 9*alpha*r_A_z*r_A_z + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 3) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 1, 2, 0) *
                  coeff_prim *
                  2*r_A_x*(2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*pow(r_A_y, 4) + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 9*alpha*r_A_y*r_A_y + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 4) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 2, 1, 0) *
                  coeff_prim *
                  2*r_A_y*(2*alpha*alpha*pow(r_A_x, 4) + 2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 9*alpha*r_A_x*r_A_x + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 5) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 2, 0, 1) *
                  coeff_prim *
                  2*r_A_z*(2*alpha*alpha*pow(r_A_x, 4) + 2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 9*alpha*r_A_x*r_A_x + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 6) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 1, 0, 2) *
                  coeff_prim *
                  2*r_A_x*(2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 2*alpha*alpha*pow(r_A_z, 4) - 9*alpha*r_A_z*r_A_z + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 7) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 0, 1, 2) *
                  coeff_prim *
                  2*r_A_y*(2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 2*alpha*alpha*pow(r_A_z, 4) - 9*alpha*r_A_z*r_A_z + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 8) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 0, 2, 1) *
                  coeff_prim *
                  2*r_A_z*(2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*pow(r_A_y, 4) + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 9*alpha*r_A_y*r_A_y + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 9) * knumb_points] +=
              gbasis::normalization_primitive_f(g_constant_basis[iconst + i_prim], 1, 1, 1) *
                  coeff_prim *
                  2*alpha*r_A_x*r_A_y*r_A_z*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 9) *
                  exponential;
        }
        else if (angmom == -3) {
          // ['c0', 'c1', 's1', 'c2', 's2', 'c3', 's3']
          double norm_const = gbasis::normalization_primitive_pure_f(g_constant_basis[iconst + i_prim]);
          d_contractions_array[global_index + icontractions * knumb_points] +=
              norm_const *
                  coeff_prim *
                  alpha*r_A_z*(-6*alpha*pow(r_A_x, 4) - 12*alpha*r_A_x*r_A_x*r_A_y*r_A_y - 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 6*alpha*pow(r_A_y, 4) - 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 4*alpha*pow(r_A_z, 4) + 27*r_A_x*r_A_x + 27*r_A_y*r_A_y - 18*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 1) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(1.5) *
                  alpha*r_A_x*(-2*alpha*pow(r_A_x, 4) - 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 6*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) + 6*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 8*alpha*pow(r_A_z, 4) + 9*r_A_x*r_A_x + 9*r_A_y*r_A_y - 36*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 2) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(1.5) *
                  alpha*r_A_y*(-2*alpha*pow(r_A_x, 4) - 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 6*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) + 6*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 8*alpha*pow(r_A_z, 4) + 9*r_A_x*r_A_x + 9*r_A_y*r_A_y - 36*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 3) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(15.0) *
                  alpha*r_A_z*(2*alpha*pow(r_A_x, 4) + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) - 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 9*r_A_x*r_A_x + 9*r_A_y*r_A_y) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 4) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(15.0) *
                  2*alpha*r_A_x*r_A_y*r_A_z*(2*alpha*r_A_x*r_A_x + 2*alpha*r_A_y*r_A_y + 2*alpha*r_A_z*r_A_z - 9) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 5) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(2.5) *
                  alpha*r_A_x*(2*alpha*pow(r_A_x, 4) - 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 6*alpha*pow(r_A_y, 4) - 6*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 9*r_A_x*r_A_x + 27*r_A_y*r_A_y) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 6) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(2.5) *
                  alpha*r_A_y*(6*alpha*pow(r_A_x, 4) + 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 6*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) - 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 27*r_A_x*r_A_x + 9*r_A_y*r_A_y) *
                  exponential;
        }
        else if (angmom == 4) {
          // The ordering is ['zzzz', 'yzzz', 'yyzz', 'yyyz', 'yyyy', 'xzzz', 'xyzz', 'xyyz', 'xyyy', 'xxzz',
          //                                                                'xxyz', 'xxyy', 'xxxz', 'xxxy', 'xxxx']
          d_contractions_array[global_index + icontractions * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 0, 0, 4) *
                  coeff_prim *
                  r_A_z*r_A_z*(4*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 4*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 4*alpha*alpha*pow(r_A_z, 4) - 22*alpha*r_A_z*r_A_z + 12) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 1) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 0, 1, 3) *
                  coeff_prim *
                  2*r_A_y*r_A_z*(2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 2*alpha*alpha*pow(r_A_z, 4) - 11*alpha*r_A_z*r_A_z + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 2) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 0, 2, 2) *
                  coeff_prim *
                  (4*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y*r_A_z*r_A_z + 4*alpha*alpha*pow(r_A_y, 4)*r_A_z*r_A_z + 4*alpha*alpha*r_A_y*r_A_y*pow(r_A_z, 4) - 22*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 2*r_A_y*r_A_y + 2*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 3) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 0, 3, 1) *
                  coeff_prim *
                  2*r_A_y*r_A_z*(2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*pow(r_A_y, 4) + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 11*alpha*r_A_y*r_A_y + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 4) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 0, 4, 0) *
                  coeff_prim *
                  r_A_y*r_A_y*(4*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 4*alpha*alpha*pow(r_A_y, 4) + 4*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 22*alpha*r_A_y*r_A_y + 12) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 5) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 1, 0, 3) *
                  coeff_prim *
                  2*r_A_x*r_A_z*(2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 2*alpha*alpha*pow(r_A_z, 4) - 11*alpha*r_A_z*r_A_z + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 6) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 1, 1, 2) *
                  coeff_prim *
                  2*r_A_x*r_A_y*(2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 2*alpha*alpha*pow(r_A_z, 4) - 11*alpha*r_A_z*r_A_z + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 7) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 1, 2, 1) *
                  coeff_prim *
                  2*r_A_x*r_A_z*(2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*pow(r_A_y, 4) + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 11*alpha*r_A_y*r_A_y + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 8) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 1, 3, 0) *
                  coeff_prim *
                  2*r_A_x*r_A_y*(2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*pow(r_A_y, 4) + 2*alpha*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 11*alpha*r_A_y*r_A_y + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 9) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 2, 0, 2) *
                  coeff_prim *
                  (4*alpha*alpha*pow(r_A_x, 4)*r_A_z*r_A_z + 4*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y*r_A_z*r_A_z + 4*alpha*alpha*r_A_x*r_A_x*pow(r_A_z, 4) - 22*alpha*r_A_x*r_A_x*r_A_z*r_A_z + 2*r_A_x*r_A_x + 2*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 10) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 2, 1, 1) *
                  coeff_prim *
                  2*r_A_y*r_A_z*(2*alpha*alpha*pow(r_A_x, 4) + 2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 11*alpha*r_A_x*r_A_x + 1) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 11) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 2, 2, 0) *
                  coeff_prim *
                  (4*alpha*alpha*pow(r_A_x, 4)*r_A_y*r_A_y + 4*alpha*alpha*r_A_x*r_A_x*pow(r_A_y, 4) + 4*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y*r_A_z*r_A_z - 22*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*r_A_x*r_A_x + 2*r_A_y*r_A_y) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 12) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 3, 0, 1) *
                  coeff_prim *
                  2*r_A_x*r_A_z*(2*alpha*alpha*pow(r_A_x, 4) + 2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 11*alpha*r_A_x*r_A_x + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 13) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 3, 1, 0) *
                  coeff_prim *
                  2*r_A_x*r_A_y*(2*alpha*alpha*pow(r_A_x, 4) + 2*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 11*alpha*r_A_x*r_A_x + 3) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 14) * knumb_points] +=
              gbasis::normalization_primitive_g(g_constant_basis[iconst + i_prim], 4, 0, 0) *
                  coeff_prim *
                  r_A_x*r_A_x*(4*alpha*alpha*pow(r_A_x, 4) + 4*alpha*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 4*alpha*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 22*alpha*r_A_x*r_A_x + 12) *
                  exponential;
        }
        else if (angmom == -4) {
          // ['c0', 'c1', 's1', 'c2', 's2', 'c3', 's3', 'c4', 's4']
          double norm_const = gbasis::normalization_primitive_pure_g(g_constant_basis[iconst + i_prim]);
          d_contractions_array[global_index + icontractions * knumb_points] +=
              norm_const *
                  coeff_prim *
                  alpha*(6*alpha*pow(r_A_x, 6) + 18*alpha*pow(r_A_x, 4)*r_A_y*r_A_y - 42*alpha*pow(r_A_x, 4)*r_A_z*r_A_z + 18*alpha*r_A_x*r_A_x*pow(r_A_y, 4) - 84*alpha*r_A_x*r_A_x*r_A_y*r_A_y*r_A_z*r_A_z - 32*alpha*r_A_x*r_A_x*pow(r_A_z, 4) + 6*alpha*pow(r_A_y, 6) - 42*alpha*pow(r_A_y, 4)*r_A_z*r_A_z - 32*alpha*r_A_y*r_A_y*pow(r_A_z, 4) + 16*alpha*pow(r_A_z, 6) - 33*pow(r_A_x, 4) - 66*r_A_x*r_A_x*r_A_y*r_A_y + 264*r_A_x*r_A_x*r_A_z*r_A_z - 33*pow(r_A_y, 4) + 264*r_A_y*r_A_y*r_A_z*r_A_z - 88*pow(r_A_z, 4))/4 *
                  exponential;
          d_contractions_array[global_index + (icontractions + 1) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(2.5) *
                  alpha*r_A_x*r_A_z*(-6*alpha*pow(r_A_x, 4) - 12*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 6*alpha*pow(r_A_y, 4) + 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 8*alpha*pow(r_A_z, 4) + 33*r_A_x*r_A_x + 33*r_A_y*r_A_y - 44*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 2) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(2.5) *
                  alpha*r_A_y*r_A_z*(-6*alpha*pow(r_A_x, 4) - 12*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 6*alpha*pow(r_A_y, 4) + 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 8*alpha*pow(r_A_z, 4) + 33*r_A_x*r_A_x + 33*r_A_y*r_A_y - 44*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 3) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(5.0) *
                  alpha*(-2*alpha*pow(r_A_x, 6) - 2*alpha*pow(r_A_x, 4)*r_A_y*r_A_y + 10*alpha*pow(r_A_x, 4)*r_A_z*r_A_z + 2*alpha*r_A_x*r_A_x*pow(r_A_y, 4) + 12*alpha*r_A_x*r_A_x*pow(r_A_z, 4) + 2*alpha*pow(r_A_y, 6) - 10*alpha*pow(r_A_y, 4)*r_A_z*r_A_z - 12*alpha*r_A_y*r_A_y*pow(r_A_z, 4) + 11*pow(r_A_x, 4) - 66*r_A_x*r_A_x*r_A_z*r_A_z - 11*pow(r_A_y, 4) + 66*r_A_y*r_A_y*r_A_z*r_A_z)/2 *
                  exponential;
          d_contractions_array[global_index + (icontractions + 4) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(5.0) *
                  alpha*r_A_x*r_A_y*(-2*alpha*pow(r_A_x, 4) - 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 10*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) + 10*alpha*r_A_y*r_A_y*r_A_z*r_A_z + 12*alpha*pow(r_A_z, 4) + 11*r_A_x*r_A_x + 11*r_A_y*r_A_y - 66*r_A_z*r_A_z) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 5) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(35.0 / 2.0) *
                  alpha*r_A_x*r_A_z*(2*alpha*pow(r_A_x, 4) - 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 6*alpha*pow(r_A_y, 4) - 6*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 11*r_A_x*r_A_x + 33*r_A_y*r_A_y) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 6) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(35.0 / 2.0) *
                  alpha*r_A_y*r_A_z*(6*alpha*pow(r_A_x, 4) + 4*alpha*r_A_x*r_A_x*r_A_y*r_A_y + 6*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) - 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 33*r_A_x*r_A_x + 11*r_A_y*r_A_y) *
                  exponential;
          d_contractions_array[global_index + (icontractions + 7) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(35.0) *
                  alpha*(2*alpha*pow(r_A_x, 6) - 10*alpha*pow(r_A_x, 4)*r_A_y*r_A_y - 10*alpha*r_A_x*r_A_x*pow(r_A_y, 4) + 2*alpha*pow(r_A_y, 6) - 10*pow(r_A_x, 4) + 60*r_A_x*r_A_x*r_A_y*r_A_y - 10*pow(r_A_y, 4) + (2*alpha*r_A_z*r_A_z - 1)*(pow(r_A_x, 4) - 6*r_A_x*r_A_x*r_A_y*r_A_y + pow(r_A_y, 4)))/4 *
                  exponential;
          d_contractions_array[global_index + (icontractions + 8) * knumb_points] +=
              norm_const *
                  coeff_prim *
                  sqrt(35.0) *
                  alpha*r_A_x*r_A_y*(2*alpha*pow(r_A_x, 4) + 2*alpha*r_A_x*r_A_x*r_A_z*r_A_z - 2*alpha*pow(r_A_y, 4) - 2*alpha*r_A_y*r_A_y*r_A_z*r_A_z - 11*r_A_x*r_A_x + 11*r_A_y*r_A_y) *
                  exponential;
        }// End angmoms.
      } // End going over contractions of a single segmented shell.
      // Update index that goes over each contraction.
      if(angmom == 0){
        icontractions += 1;
      }
      else if (angmom == 1) {
        icontractions += 3;
      }
      else if (angmom == 2) {
        icontractions += 6;
      }
      else if (angmom == -2) {
        icontractions += 5;
      }
      else if (angmom == 3) {
        icontractions += 10;
      }
      else if (angmom == -3) {
        icontractions += 7;
      }
      else if (angmom == 4) {
        icontractions += 15;
      }
      else if (angmom == -4) {
        icontractions += 9;
      }
    } // End updating segmented shell.
    // Update index of constant memory, add the number of exponents then number of angular momentum terms then
    //        add the number of coefficients.
    iconst += numb_primitives + numb_segment_shells + numb_segment_shells * numb_primitives;
  } // End Contractions
}


__global__ void gbasis::evaluate_sum_of_second_contractions_from_constant_memory_on_any_grid(
    double* d_contractions_array, const double* const d_points, const int knumb_points
) {
  unsigned int global_index = blockIdx.x * blockDim.x + threadIdx.x;
  if (global_index < knumb_points) {
    // Get the grid points where `d_points` is in column-major order with shape (N, 3)
    double grid_x = d_points[global_index];
    double grid_y = d_points[global_index + knumb_points];
    double grid_z = d_points[global_index + knumb_points * 2];

    // Evaluate the contractions and store it in d_contractions_array
    gbasis::evaluate_sum_of_second_derivative_contractions_from_constant_memory(
        d_contractions_array, grid_x, grid_y, grid_z, knumb_points, global_index
    );
  }
}

__host__ std::vector<double> gbasis::evaluate_sum_of_second_derivative_contractions(
    gbasis::IOData& iodata, const double* h_points, const int knumb_points
){
  cudaFuncSetCacheConfig(gbasis::evaluate_contractions_from_constant_memory_on_any_grid, cudaFuncCachePreferL1);

  // Get the molecular basis from iodata and put it in constant memory of the gpu.
  gbasis::MolecularBasis molecular_basis = iodata.GetOrbitalBasis();
  gbasis::add_mol_basis_to_constant_memory_array(molecular_basis, false);
  int knbasisfuncs = molecular_basis.numb_basis_functions();
  printf("Number of basis-functions %d \n", knbasisfuncs);

  // The output of the contractions in column-major order with shape (3, M, N).
  std::vector<double> h_contractions(knbasisfuncs * knumb_points);

  // Transfer grid points to GPU, this is in column order with shape (N, 3)
  double* d_points;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_points, sizeof(double) * 3 * knumb_points));
  gbasis::cuda_check_errors(cudaMemcpy(d_points, h_points,sizeof(double) * 3 * knumb_points, cudaMemcpyHostToDevice));

  // Evaluate derivatives of each contraction this is in row-order (3, M, N), where M =number of basis-functions.
  double* d_sum_second_derivs;
  printf("Evaluate derivative \n");
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_sum_second_derivs, sizeof(double) * knumb_points * knbasisfuncs));
  dim3 threadsPerBlock(128);
  dim3 grid((knumb_points + threadsPerBlock.x - 1) / (threadsPerBlock.x));
  gbasis::evaluate_sum_of_second_contractions_from_constant_memory_on_any_grid<<<grid, threadsPerBlock>>>(
      d_sum_second_derivs, d_points, knumb_points
  );
  printf("Transfer \n");
  // Transfer from device memory to host memory
  gbasis::cuda_check_errors(cudaMemcpy(&h_contractions[0],
                                       d_sum_second_derivs,
                                       sizeof(double) * knumb_points * knbasisfuncs, cudaMemcpyDeviceToHost));

  cudaFree(d_points);
  cudaFree(d_sum_second_derivs);

  return h_contractions;
}


__host__ void gbasis::compute_first_term(
    const cublasHandle_t& handle, const gbasis::IOData& iodata, std::vector<double>& h_laplacian,
    const double* const h_points, const int knumb_points, const int knbasisfuncs
    ) {

  cudaFuncSetCacheConfig(
      gbasis::evaluate_sum_of_second_contractions_from_constant_memory_on_any_grid, cudaFuncCachePreferL1
  );
  cudaFuncSetCacheConfig(
      gbasis::evaluate_contractions_from_constant_memory_on_any_grid, cudaFuncCachePreferL1
  );

  double* d_points;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_points, sizeof(double) * 3 * knumb_points));
  gbasis::cuda_check_errors(cudaMemcpy(d_points, h_points, sizeof(double) * 3 * knumb_points, cudaMemcpyHostToDevice));

  // Allocate device memory for sum of second derivatives of contractions array,
  //    This array has shape (M, N) and is stored in row-major order.
  double *d_sum_second_contractions;
  size_t second_derivs_number_bytes = sizeof(double) * knumb_points * knbasisfuncs;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_sum_second_contractions, second_derivs_number_bytes));
  gbasis::cuda_check_errors(cudaMemset(d_sum_second_contractions, 0, second_derivs_number_bytes));
  // Evaluate sum of second derivatives contractions. The number of threads is maximal and the number
  // of thread blocks is calculated. Produces a matrix of size (N, M) where N is the number of points
  int ilen = 128;  // 128 320 1024
  dim3 threadsPerBlock(ilen);
  dim3 grid((knumb_points + threadsPerBlock.x - 1) / (threadsPerBlock.x));
  gbasis::evaluate_sum_of_second_contractions_from_constant_memory_on_any_grid<<<grid, threadsPerBlock>>>(
      d_sum_second_contractions, d_points, knumb_points
  );
  cudaDeviceSynchronize();

  // Allocate device memory for contractions array, and set all elements to zero via cudaMemset.
  //    The contraction array rows are the atomic orbitals and columns are grid points and is stored in row-major order.
  double *d_contractions;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_contractions, second_derivs_number_bytes));
  gbasis::cuda_check_errors(cudaMemset(d_contractions, 0, second_derivs_number_bytes));
  // Evaluate contractions. The number of threads is maximal and the number of thread blocks is calculated.
  // Produces a matrix of size (N, M) where N is the number of points
  gbasis::evaluate_contractions_from_constant_memory_on_any_grid<<<grid, threadsPerBlock>>>(
      d_contractions, d_points, knumb_points
  );
  cudaDeviceSynchronize();

  cudaFree(d_points);

  // Transfer one-rdm from host/cpu memory to device/gpu memory.
  double *d_one_rdm;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_one_rdm, knbasisfuncs * knbasisfuncs * sizeof(double)));
  gbasis::cublas_check_errors(cublasSetMatrix(iodata.GetOneRdmShape(), iodata.GetOneRdmShape(),
                                              sizeof(double), iodata.GetMOOneRDM(),
                                              iodata.GetOneRdmShape(), d_one_rdm,iodata.GetOneRdmShape()));

  // Matrix-Multiplication of the One-RDM with the sum of second derivatives
  double *d_first_term_helper;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_first_term_helper, second_derivs_number_bytes));
  double alpha = 1.;
  double beta = 0.;
  gbasis::cublas_check_errors(cublasDgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N,
                                          knumb_points, iodata.GetOneRdmShape(), iodata.GetOneRdmShape(),
                                          &alpha, d_sum_second_contractions, knumb_points,
                                          d_one_rdm, iodata.GetOneRdmShape(), &beta,
                                          d_first_term_helper, knumb_points));
  cudaFree(d_sum_second_contractions);
  cudaFree(d_one_rdm);

  // Hadamard Product with the Contractions Array
  dim3 threadsPerBlock2(320);
  dim3 grid2((knumb_points * knbasisfuncs + threadsPerBlock.x - 1) / (threadsPerBlock.x));
  gbasis::hadamard_product<<<grid2, threadsPerBlock2>>>(d_first_term_helper, d_contractions, knbasisfuncs, knumb_points);

  cudaFree(d_contractions);

  // Allocate device memory for electron density.
  double *d_first_term;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_first_term, sizeof(double) * knumb_points));

  // Sum up the columns of d_first_term_helper to get the first term. This is done by doing a matrix multiplication of
  //    all ones of the transpose of d_final. Here I'm using the fact that d_final is in row major order.
  thrust::device_vector<double> all_ones(sizeof(double) * knbasisfuncs, 1.0);
  double *deviceVecPtr = thrust::raw_pointer_cast(all_ones.data());
  gbasis::cublas_check_errors(cublasDgemv(handle, CUBLAS_OP_N, knumb_points, knbasisfuncs,
                                          &alpha, d_first_term_helper, knumb_points, deviceVecPtr, 1, &beta,
                                          d_first_term, 1));
  cudaFree(d_first_term_helper);


  dim3 threadsPerBlock3(320);
  dim3 grid3((knumb_points + threadsPerBlock.x - 1) / (threadsPerBlock.x));
  gbasis::multiply_scalar<<< grid3, threadsPerBlock3>>>(d_first_term, 2.0, knumb_points);


  // Transfer first term from device memory to host memory.
  gbasis::cuda_check_errors(cudaMemcpy(&h_laplacian[0], d_first_term,
                                       sizeof(double) * knumb_points, cudaMemcpyDeviceToHost));
  cudaFree(d_first_term);

  all_ones.clear();
  all_ones.shrink_to_fit();
}

__host__ std::vector<double> gbasis::evaluate_laplacian_on_any_grid_handle(
    cublasHandle_t& handle, gbasis::IOData& iodata, const double* h_points, const int knumb_points
) {
  // Set cache perference to L1
  cudaFuncSetCacheConfig(
      gbasis::evaluate_derivatives_contractions_from_constant_memory, cudaFuncCachePreferL1
  );

  // Get the molecular basis from iodata and put it in constant memory of the gpu.
  gbasis::MolecularBasis molecular_basis = iodata.GetOrbitalBasis();
  //gbasis::add_mol_basis_to_constant_memory_array(molecular_basis, false, false);
  int knbasisfuncs = molecular_basis.numb_basis_functions();

  // Electron density in global memory and create the handles for using cublas.
  std::vector<double> h_laplacian(knumb_points);

  /**
   * Compute the first term of the Laplacian: sum of second derivatives with the contractions:
   *            2 \sum_i \sum_j c_{i, j}  [\sum_k \partial \phi_i^2 \ \partial x_k^2] \phi_j .
   */
  // Transfer grid points to GPU, this is in column order with shape (N, 3)
  gbasis::compute_first_term(
      handle, iodata, h_laplacian, h_points, knumb_points, knbasisfuncs
  );
  cudaDeviceSynchronize();
  cudaError_t error = cudaGetLastError();
  if (error != cudaSuccess) {
    printf("CUDA error: %s \n", cudaGetErrorString(error));
    exit(-1);
  }

  /**
   * Compute second term:
   *        2 \sum_{k in {x,y,z}} \sum_{i, j}  c_{i, j}  [d \phi_i \ dx_k] [d\phi_j \ dx_k]
   */
  double* d_points2;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_points2, sizeof(double) * 3 * knumb_points));
  gbasis::cuda_check_errors(cudaMemcpy(d_points2, h_points, sizeof(double) * 3 * knumb_points, cudaMemcpyHostToDevice));

  // Evaluate derivatives of each contraction this is in row-order (3, M, N), where M =number of basis-functions.
  double* d_deriv_contractions;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_deriv_contractions, sizeof(double) * 3 * knumb_points * knbasisfuncs));
  gbasis::cuda_check_errors(cudaMemset(d_deriv_contractions, 0, sizeof(double) * 3 * knumb_points * knbasisfuncs));
  dim3 threadsPerBlock4(128);
  dim3 grid4((knumb_points + threadsPerBlock4.x - 1) / (threadsPerBlock4.x));
  gbasis::evaluate_derivatives_contractions_from_constant_memory<<<grid4, threadsPerBlock4>>>(
      d_deriv_contractions, d_points2, knumb_points, knbasisfuncs
  );

  cudaFree(d_points2);

  // Transfer one-rdm from host/cpu memory to device/gpu memory.
  double* d_one_rdm;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_one_rdm, knbasisfuncs * knbasisfuncs * sizeof(double)));
  gbasis::cublas_check_errors(cublasSetMatrix(iodata.GetOneRdmShape(), iodata.GetOneRdmShape(),
                                              sizeof(double), iodata.GetMOOneRDM(),
                                              iodata.GetOneRdmShape(), d_one_rdm, iodata.GetOneRdmShape()));

  // Allocate memory to hold the matrix-multiplcation between d_one_rdm and each `i`th derivative (i_deriv, M, N)
  ///  This is in row-major order
  double *d_temp_rdm_derivs;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_temp_rdm_derivs, sizeof(double) * knumb_points * knbasisfuncs));
  // Allocate device memory for gradient of electron density in column-major order.
  double *d_second_term;
  gbasis::cuda_check_errors(cudaMalloc((double **) &d_second_term, sizeof(double) * knumb_points));
  // Allocate host memory to add to the h_laplacian
  std::vector<double> h_second_term(knumb_points);
  double alpha = 1.0;
  double beta = 0.0;
  for(int i_deriv = 0; i_deriv < 3; i_deriv++) {
    // Get the ith derivative of the contractions with shape (M, N) in row-major order, N=numb pts, M=numb basis funcs
    double* d_ith_deriv = &d_deriv_contractions[i_deriv * knumb_points * knbasisfuncs];

    // Matrix multiple one-rdm with the ith derivative of contractions
    gbasis::cublas_check_errors(cublasDgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N,
                                            knumb_points, knbasisfuncs, knbasisfuncs,
                                            &alpha, d_ith_deriv, knumb_points,
                                            d_one_rdm, knbasisfuncs, &beta,
                                            d_temp_rdm_derivs, knumb_points));

    // Do a hadamard product with the ith derivative
    dim3 threadsPerBlock5(320);
    dim3 grid5((knumb_points * knbasisfuncs + threadsPerBlock5.x - 1) / (threadsPerBlock5.x));
    gbasis::hadamard_product<<<grid5, threadsPerBlock5>>>(
        d_temp_rdm_derivs, d_ith_deriv, knbasisfuncs, knumb_points
    );


    // Take the sum.
    thrust::device_vector<double> all_ones(sizeof(double) * knbasisfuncs, 1.0);
    double *deviceVecPtr = thrust::raw_pointer_cast(all_ones.data());
    gbasis::cublas_check_errors(cublasDgemv(handle, CUBLAS_OP_N,
                                            knumb_points, knbasisfuncs,
                                            &alpha, d_temp_rdm_derivs, knumb_points, deviceVecPtr, 1, &beta,
                                            d_second_term, 1));

    // Multiply by two
    dim3 threadsPerBlock3(320);
    dim3 grid3((knumb_points + threadsPerBlock5.x - 1) / (threadsPerBlock5.x));
    gbasis::multiply_scalar<<< grid3, threadsPerBlock3>>>(d_second_term, 2.0, knumb_points);


    gbasis::cuda_check_errors(cudaMemcpy(h_second_term.data(), d_second_term,
                                         sizeof(double) * knumb_points, cudaMemcpyDeviceToHost));

    // Add to h_laplacian
    for(int i = 0; i < knumb_points; i++) {
      h_laplacian[i] += h_second_term[i];
    }

    // Free up memory in this iteration for the next calculation of the derivative.
    all_ones.clear();
    all_ones.shrink_to_fit();
  } // end i_deriv

  // Free Everything
  cudaFree(d_second_term);
  cudaFree(d_temp_rdm_derivs);
  cudaFree(d_one_rdm);
  cudaFree(d_deriv_contractions);

  return h_laplacian;
}


__host__ std::vector<double> gbasis::evaluate_laplacian(
    gbasis::IOData& iodata, const double* h_points, const int knumb_points)
{
  cublasHandle_t handle;
  cublasCreate(&handle);
  std::vector<double> laplacian = gbasis::evaluate_laplacian_on_any_grid_handle(
      handle, iodata, h_points, knumb_points
  );
  cublasDestroy(handle); // cublas handle is no longer needed infact most of
  return laplacian;
}
