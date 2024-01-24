#include "catch.hpp"

#include <random>
#include <iostream>
#include <algorithm>

#include <pybind11/embed.h>
#include <pybind11/numpy.h>

#include "../include/basis_to_gpu.cuh"
#include "../include/evaluate_densbased.cuh"
#include "../include/iodata.h"
#include "../include/utils.h"

namespace py = pybind11;
using namespace py::literals;


TEST_CASE( "Test computing the norm of a vector", "[compute_norm_of_3d_vector]" ) {
  {  // Need this so that the python object doesn't outline the interpretor.
    // Generate random grid.
    int numb_pts = 10000;
    std::vector<double> points(3 * numb_pts);
    std::random_device rnd_device;
    std::mt19937  merseene_engine {rnd_device()};
    std::uniform_real_distribution<double> dist {-5, 5};
    auto gen = [&dist, &merseene_engine](){return dist(merseene_engine);};
    std::generate(points.begin(), points.end(), gen);

    // Calculate Gradient
    std::vector<double> norm_result = gbasis::compute_norm_of_3d_vector(points.data(), numb_pts);

    // COnvert them (with copy) to python objects so that they can be transfered.
    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
        py_result = gbasis::as_pyarray_from_vector(norm_result);
    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
        py_points = gbasis::as_pyarray_from_vector(points);

    auto locals = py::dict("points"_a = py_points,
                           "true_result"_a = py_result,
                           "numb_pts"_a = numb_pts);
    py::exec(R"(
import numpy as np
points = np.reshape(points, (int(numb_pts), 3), order="F")
norm_cpu = np.linalg.norm(points, axis=1)
error = np.abs(norm_cpu - true_result)
print(f"The Max error: {np.max(error)},   Mean error: {np.mean(error)},   STD error: {np.std(error)}")
assert np.all(error < 1e-10), "Norm of the vector does not match CPU implementation."
    )", py::globals(), locals);
  } // Need this so that the python object doesn't outline the interpretor when we close it up.
}


//TEST_CASE( "Test reduced density gradient", "[compute_reduced_density_gradient]" ) {
//  {  // Need this so that the python object doesn't outline the interpretor.
//    // Get the IOdata object from the fchk file.
//    std::string fchk_file = GENERATE(
//        "./tests/data/atom_01_H_N01_M2_ub3lyp_ccpvtz_g09.fchk",
//        "./tests/data/atom_he.fchk",
//        "./tests/data/atom_be.fchk",
//        "./tests/data/atom_be_f_pure_orbital.fchk",
//        "./tests/data/atom_be_f_cartesian_orbital.fchk",
//        "./tests/data/atom_kr.fchk",
//        "./tests/data/atom_o.fchk",
//        "./tests/data/atom_c_g_pure_orbital.fchk",
//        "./tests/data/atom_mg.fchk",
//        "./tests/data/E948_rwB97XD_def2SVP.fchk",
//        "./tests/data/test.fchk",
//        "./tests/data/test2.fchk",
//        "./tests/data/atom_08_O_N08_M3_ub3lyp_ccpvtz_g09.fchk",
//        "./tests/data/atom_08_O_N09_M2_ub3lyp_ccpvtz_g09.fchk",
//        "./tests/data/4141_q000_m01_k00_force_uhf_ccpvtz.fchk",
//        "./tests/data/h2o.fchk",
//        "./tests/data/ch4.fchk",
//        "./tests/data/qm9_000092_HF_cc-pVDZ.fchk",
//        "./tests/data/qm9_000104_PBE1PBE_pcS-3.fchk"
//    );
//    std::cout << "FCHK FILE %s \n" << fchk_file << std::endl;
//    gbasis::IOData iodata = gbasis::get_molecular_basis_from_fchk(fchk_file);
//
//    // Generate random grid.
//    int numb_pts = 10000;
//    std::vector<double> points(3 * numb_pts);
//    std::random_device rnd_device;
//    std::mt19937  merseene_engine {rnd_device()};
//    std::uniform_real_distribution<double> dist {-5, 5};
//    auto gen = [&dist, &merseene_engine](){return dist(merseene_engine);};
//    std::generate(points.begin(), points.end(), gen);
//
//    // Calculate Gradient
//    gbasis::add_mol_basis_to_constant_memory_array(iodata.GetOrbitalBasis(), false, false);
//    std::vector<double> reduced_dens = gbasis::compute_reduced_density_gradient(iodata, points.data(), numb_pts);
//
//    // COnvert them (with copy) to python objects so that they can be transfered.
//    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
//        py_result = gbasis::as_pyarray_from_vector(reduced_dens);
//    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
//        py_points = gbasis::as_pyarray_from_vector(points);
//
//    auto locals = py::dict("points"_a = py_points,
//                           "true_result"_a = py_result,
//                           "fchk_path"_a = fchk_file,
//                           "numb_pts"_a = numb_pts);
//    py::exec(R"(
//import numpy as np
//from gbasis.evals.density import evaluate_density_gradient, evaluate_density
//from iodata import load_one
//from gbasis.wrappers import from_iodata
//
//iodata = load_one(fchk_path)
//basis, type = from_iodata(iodata)
//rdm = (iodata.mo.coeffs * iodata.mo.occs).dot(iodata.mo.coeffs.T)
//points = points.reshape((numb_pts, 3), order="F")
//points = np.array(points, dtype=np.float64)
//
//# Calculate reduced density gradient
//gradient = evaluate_density_gradient(rdm, basis, points, coord_type=type)
//norm_grad = np.linalg.norm(gradient, axis=1)
//density = evaluate_density(rdm, basis, points, coord_type=type)
//mdens = np.ma.masked_less(density, 1e-12)
//prefactor = 0.5 / (3.0 * np.pi**2)**(1.0 / 3.0)
//reduced_density = prefactor * norm_grad / mdens**(4.0 / 3.0)
//
//error = np.abs(reduced_density - true_result)
//print("Max, Mean, STD , Min error ", np.max(error), np.mean(error), np.std(error), np.min(error))
//assert np.all(error < 1e-6), "Reduced Density Gradient on GPU doesn't match gbasis."
//    )", py::globals(), locals);
//  } // Need this so that the python object doesn't outline the interpretor when we close it up.
//}


//TEST_CASE( "Test Weizsacker Kinetic Energy Density", "[compute_weizsacker_ked]" ) {
//  {  // Need this so that the python object doesn't outline the interpretor.
//    // Get the IOdata object from the fchk file.
//    std::string fchk_file = GENERATE(
//        "./tests/data/atom_01_H_N01_M2_ub3lyp_ccpvtz_g09.fchk",
//        "./tests/data/atom_he.fchk",
//        "./tests/data/atom_be.fchk",
//        "./tests/data/atom_be_f_pure_orbital.fchk",
//        "./tests/data/atom_be_f_cartesian_orbital.fchk",
//        "./tests/data/atom_kr.fchk",
//        "./tests/data/atom_o.fchk",
//        "./tests/data/atom_c_g_pure_orbital.fchk",
//        "./tests/data/atom_mg.fchk",
//        "./tests/data/E948_rwB97XD_def2SVP.fchk",
//        "./tests/data/test.fchk",
//        "./tests/data/test2.fchk",
//        "./tests/data/atom_08_O_N08_M3_ub3lyp_ccpvtz_g09.fchk",
//        "./tests/data/atom_08_O_N09_M2_ub3lyp_ccpvtz_g09.fchk",
//        "./tests/data/4141_q000_m01_k00_force_uhf_ccpvtz.fchk",
//        "./tests/data/h2o.fchk",
//        "./tests/data/ch4.fchk",
//        "./tests/data/qm9_000092_HF_cc-pVDZ.fchk",
//        "./tests/data/qm9_000104_PBE1PBE_pcS-3.fchk"
//    );
//    std::cout << "FCHK FILE %s \n" << fchk_file << std::endl;
//    gbasis::IOData iodata = gbasis::get_molecular_basis_from_fchk(fchk_file);
//
//    // Generate random grid.
//    int numb_pts = 10000;
//    std::vector<double> points(3 * numb_pts);
//    std::random_device rnd_device;
//    std::mt19937  merseene_engine {rnd_device()};
//    std::uniform_real_distribution<double> dist {-5, 5};
//    auto gen = [&dist, &merseene_engine](){return dist(merseene_engine);};
//    std::generate(points.begin(), points.end(), gen);
//
//    // Calculate Gradient
//    gbasis::add_mol_basis_to_constant_memory_array(iodata.GetOrbitalBasis(), false, false);
//    std::vector<double> reduced_dens = gbasis::compute_weizsacker_ked(iodata, points.data(), numb_pts);
//
//    // COnvert them (with copy) to python objects so that they can be transfered.
//    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
//        py_result = gbasis::as_pyarray_from_vector(reduced_dens);
//    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
//        py_points = gbasis::as_pyarray_from_vector(points);
//
//    auto locals = py::dict("points"_a = py_points,
//                           "true_result"_a = py_result,
//                           "fchk_path"_a = fchk_file,
//                           "numb_pts"_a = numb_pts);
//    py::exec(R"(
//import numpy as np
//from gbasis.evals.density import evaluate_density_gradient, evaluate_density
//from iodata import load_one
//from gbasis.wrappers import from_iodata
//
//iodata = load_one(fchk_path)
//basis, type = from_iodata(iodata)
//rdm = (iodata.mo.coeffs * iodata.mo.occs).dot(iodata.mo.coeffs.T)
//points = points.reshape((numb_pts, 3), order="F")
//points = np.array(points, dtype=np.float64)
//
//# Calculate Weizsacker
//gradient = evaluate_density_gradient(rdm, basis, points, coord_type=type)
//density = evaluate_density(rdm, basis, points, coord_type=type)
//mdens = np.ma.masked_less(density, 1e-12)
//weizsacker = np.sum(gradient * gradient, axis=1) / (mdens * 8.0)
//
//error = np.abs(weizsacker - true_result)
//print("Max, Mean, STD , Min error ", np.max(error), np.mean(error), np.std(error), np.min(error))
//assert np.all(error < 1e-10), "Weizsacker on GPU  doesn't match gbasis."
//    )", py::globals(), locals);
//  } // Need this so that the python object doesn't outline the interpretor when we close it up.
//}

TEST_CASE( "Test General Gradient Expansion", "[compute_general_gradient_expansion_ked]" ) {
  {  // Need this so that the python object doesn't outline the interpretor.
    // Get the IOdata object from the fchk file.
    std::string fchk_file = GENERATE(
        "./tests/data/atom_01_H_N01_M2_ub3lyp_ccpvtz_g09.fchk",
        "./tests/data/atom_he.fchk",
        "./tests/data/atom_be.fchk",
        "./tests/data/atom_be_f_pure_orbital.fchk",
        "./tests/data/atom_be_f_cartesian_orbital.fchk",
        "./tests/data/atom_kr.fchk",
        "./tests/data/atom_o.fchk",
        "./tests/data/atom_c_g_pure_orbital.fchk",
        "./tests/data/atom_mg.fchk",
        "./tests/data/E948_rwB97XD_def2SVP.fchk",
        "./tests/data/test.fchk",
        "./tests/data/test2.fchk",
        "./tests/data/atom_08_O_N08_M3_ub3lyp_ccpvtz_g09.fchk",
        "./tests/data/atom_08_O_N09_M2_ub3lyp_ccpvtz_g09.fchk",
        "./tests/data/4141_q000_m01_k00_force_uhf_ccpvtz.fchk",
        "./tests/data/h2o.fchk",
        "./tests/data/ch4.fchk",
        "./tests/data/qm9_000092_HF_cc-pVDZ.fchk",
        "./tests/data/qm9_000104_PBE1PBE_pcS-3.fchk"
    );
    std::cout << "FCHK FILE %s \n" << fchk_file << std::endl;
    gbasis::IOData iodata = gbasis::get_molecular_basis_from_fchk(fchk_file);

    // Generate random grid.
    int numb_pts = 10000;
    std::vector<double> points(3 * numb_pts);
    std::random_device rnd_device;
    std::mt19937  merseene_engine {rnd_device()};
    std::uniform_real_distribution<double> dist {-5, 5};
    auto gen = [&dist, &merseene_engine](){return dist(merseene_engine);};
    std::generate(points.begin(), points.end(), gen);

    // Calculate Gradient
    gbasis::add_mol_basis_to_constant_memory_array(iodata.GetOrbitalBasis(), false, false);
    std::vector<double> reduced_dens = gbasis::compute_ked_gradient_expansion_general(
        iodata, points.data(), numb_pts, 1.0, 2.0
    );

    // COnvert them (with copy) to python objects so that they can be transfered.
    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
        py_result = gbasis::as_pyarray_from_vector(reduced_dens);
    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
        py_points = gbasis::as_pyarray_from_vector(points);

    auto locals = py::dict("points"_a = py_points,
                           "true_result"_a = py_result,
                           "fchk_path"_a = fchk_file,
                           "numb_pts"_a = numb_pts);
    py::exec(R"(
import numpy as np
from gbasis.evals.density import evaluate_density_gradient, evaluate_density, evaluate_density_laplacian
from iodata import load_one
from gbasis.wrappers import from_iodata

iodata = load_one(fchk_path)
basis, type = from_iodata(iodata)
rdm = (iodata.mo.coeffs * iodata.mo.occs).dot(iodata.mo.coeffs.T)
points = points.reshape((numb_pts, 3), order="F")
points = np.array(points, dtype=np.float64)

# Calculate Thomas-Fermi
density = evaluate_density(rdm, basis, points, coord_type=type)
thomas = (0.3 * (3.0 * np.pi**2.0)**(2.0 / 3.0)) * density**(5.0 / 3.0)

# Calculate Weizsacker
gradient = evaluate_density_gradient(rdm, basis, points, coord_type=type)
mdens = np.ma.masked_less(density, 1e-12)
weizsacker = np.sum(gradient * gradient, axis=1) / (mdens * 8.0)

# Calculate Laplacian
# Derivative in X-coordinate
laplacian = evaluate_density_laplacian(rdm, basis, points, coord_type=type)

# Calculate general gradient expansion
output = thomas + 1.0 * weizsacker + 2.0 * laplacian

error = np.abs(output - true_result)
print("Max, Mean, STD , Min error ", np.max(error), np.mean(error), np.std(error), np.min(error))
assert np.all(error < 1e-10), "General Gradient Expansion on GPU doesn't match gbasis."
    )", py::globals(), locals);
  } // Need this so that the python object doesn't outline the interpretor when we close it up.
}

TEST_CASE( "Test Thomas Fermi Energy Density", "[compute_thomas_fermi_ked]" ) {
  {  // Need this so that the python object doesn't outline the interpretor.
    // Get the IOdata object from the fchk file.
    std::string fchk_file = GENERATE(
        "./tests/data/atom_01_H_N01_M2_ub3lyp_ccpvtz_g09.fchk",
        "./tests/data/atom_he.fchk",
        "./tests/data/atom_be.fchk",
        "./tests/data/atom_be_f_pure_orbital.fchk",
        "./tests/data/atom_be_f_cartesian_orbital.fchk",
        "./tests/data/atom_kr.fchk",
        "./tests/data/atom_o.fchk",
        "./tests/data/atom_c_g_pure_orbital.fchk",
        "./tests/data/atom_mg.fchk",
        "./tests/data/E948_rwB97XD_def2SVP.fchk",
        "./tests/data/test.fchk",
        "./tests/data/test2.fchk",
        "./tests/data/atom_08_O_N08_M3_ub3lyp_ccpvtz_g09.fchk",
        "./tests/data/atom_08_O_N09_M2_ub3lyp_ccpvtz_g09.fchk",
        "./tests/data/4141_q000_m01_k00_force_uhf_ccpvtz.fchk",
        "./tests/data/h2o.fchk",
        "./tests/data/ch4.fchk",
        "./tests/data/qm9_000092_HF_cc-pVDZ.fchk",
        "./tests/data/qm9_000104_PBE1PBE_pcS-3.fchk"
    );
    std::cout << "FCHK FILE %s \n" << fchk_file << std::endl;
    gbasis::IOData iodata = gbasis::get_molecular_basis_from_fchk(fchk_file);

    // Generate random grid.
    int numb_pts = 10000;
    std::vector<double> points(3 * numb_pts);
    std::random_device rnd_device;
    std::mt19937  merseene_engine {rnd_device()};
    std::uniform_real_distribution<double> dist {-5, 5};
    auto gen = [&dist, &merseene_engine](){return dist(merseene_engine);};
    std::generate(points.begin(), points.end(), gen);

    // Calculate Gradient
    gbasis::add_mol_basis_to_constant_memory_array(iodata.GetOrbitalBasis(), false, false);
    std::vector<double> reduced_dens = gbasis::compute_thomas_fermi_energy_density(iodata, points.data(), numb_pts);

    // COnvert them (with copy) to python objects so that they can be transfered.
    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
        py_result = gbasis::as_pyarray_from_vector(reduced_dens);
    pybind11::array_t<double, pybind11::array::c_style | pybind11::array::forcecast>
        py_points = gbasis::as_pyarray_from_vector(points);

    auto locals = py::dict("points"_a = py_points,
                           "true_result"_a = py_result,
                           "fchk_path"_a = fchk_file,
                           "numb_pts"_a = numb_pts);
    py::exec(R"(
import numpy as np
from gbasis.evals.density import evaluate_density_gradient, evaluate_density
from iodata import load_one
from gbasis.wrappers import from_iodata

iodata = load_one(fchk_path)
basis, type = from_iodata(iodata)
rdm = (iodata.mo.coeffs * iodata.mo.occs).dot(iodata.mo.coeffs.T)
points = points.reshape((numb_pts, 3), order="F")
points = np.array(points, dtype=np.float64)

# Calculate Thomas-Fermi
density = evaluate_density(rdm, basis, points, coord_type=type)
thomas = (0.3 * (3.0 * np.pi**2.0)**(2.0 / 3.0)) * density**(5.0 / 3.0)

error = np.abs(thomas - true_result)
print("Max, Mean, STD , Min error ", np.max(error), np.mean(error), np.std(error), np.min(error))
assert np.all(error < 1e-10), "Thomas-Fermi on GPU doesn't match gbasis."
    )", py::globals(), locals);
  } // Need this so that the python object doesn't outline the interpretor when we close it up.
}