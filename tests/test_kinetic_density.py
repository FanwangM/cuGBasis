import numpy as np
import gbasis_cuda
from chemtools.wrappers import Molecule
import pytest


@pytest.mark.parametrize("fchk",
                         [
                             "E948_rwB97XD_def2SVP.fchk",
                             "h2o.fchk",
                             "ch4.fchk",
                             "qm9_000092_HF_cc-pVDZ.fchk"
                         ]
                         )
def test_positive_definite_of_electron_density_against_horton(fchk):
    fchk = "./tests/data/" + fchk
    mol = gbasis_cuda.Molecule(fchk)
    mol.basis_set_to_constant_memory(False)

    grid_pts = np.random.uniform(-2, 2, size=(1000, 3))
    grid_pts = np.array(grid_pts, dtype=np.float64, order="C")
    gpu_kinetic = mol.compute_positive_definite_kinetic_energy_density(grid_pts)

    mol2 = Molecule.from_file(fchk)
    cpu_kinetic = mol2.compute_ked(grid_pts)

    assert np.all(np.abs(cpu_kinetic - gpu_kinetic) < 1e-8)
