r"""
Responsible for creating a C++ source file that generates
all of the nuclear-attraction integrals coefficients between all sub-shells.
The point of this is to avoid doing it by hand and saving time.

These coefficients E, R can be found in Helgeker's book and from the
Hermite expansion and Boys function recursion, respectively.

"""

# The shells are in Gaussian order.
shells = ["s",
          "px", "py", "pz",
          "dxx", "dyy", "dzz", "dxy", "dxz", "dyz",
          'fxxx', 'fyyy', 'fzzz', 'fxyy', 'fxxy', 'fxxz', 'fxzz', 'fyzz', 'fyyz', 'fxyz',
          # COmmented this out to reduce compilation time.
          # 'gzzzz', 'gyzzz', 'gyyzz', 'gyyyz', 'gyyyy', 'gxzzz', 'gxyzz', 'gxyyz', 'gxyyy', 'gxxzz', 'gxxyz',
          #   'gxxyy', 'gxxxz', 'gxxxy', 'gxxxx'
          ]
# The angular momentum component, same order as above.
angmom = [(0, 0, 0),
          (1, 0, 0), (0, 1, 0), (0, 0, 1),
          (2, 0, 0), (0, 2, 0), (0, 0, 2), (1, 1, 0), (1, 0, 1), (0, 1, 1),
          (3, 0, 0), (0, 3, 0),  (0, 0, 3),  (1, 2, 0), (2, 1, 0), (2, 0, 1), (1, 0, 2), (0, 1, 2), (0, 2, 1), (1, 1, 1),
          # (0, 0, 4), (0, 1, 3), (0, 2, 2), (0, 3, 1), (0, 4, 0), (1, 0, 3), (1, 1, 2), (1, 2, 1), (1, 3, 0), (2, 0, 2), (2, 1, 1),
          #       (2, 2, 0), (3, 0, 1), (3, 1, 0), (4, 0, 0),
          ]

function_header = lambda shell1, shell2: "__device__ double gbasis::compute_"+ shell1 + "_" + shell2 + "_nuclear_attraction_integral(const double& alpha, const double3& A_coord, const double& beta, const double3& B_coord, const double3& pt, const double3& P)"
function_header_header = lambda shell1, shell2: "__device__ double compute_"+ shell1 + "_" + shell2 + "_nuclear_attraction_integral(const double& alpha, const double3& A_coord, const double& beta, const double3& B_coord, const double3& pt, const double3& P)"



file1 = open("integral_coeffs_delete.cu", "w+")
header_files = []
for ia, shell1 in enumerate(shells):
    la = angmom[ia]
    for ib, shell2 in enumerate(shells[ia:]):
        lb = angmom[ib + ia]
        # Write the function header 
        file1.write(function_header(shell1, shell2))
        header_files.append(function_header_header(shell1, shell2))
        file1.write("\n{\n")
        
        # Write out the output variable
        count = 0
        for t in range(0, la[0] + lb[0] + 1):
            for u in range(0, la[1] + lb[1] + 1):
                for v in range(0, la[2] + lb[2] + 1):
                    # If it is the first, then initialize output
                    if count == 0:
                        file1.write("    double output = ")
                    else:
                        file1.write("    output += ")
                    file1.write("gbasis::E<" + str(t) + ", " + str(la[0]) + ", " + str(lb[0]) + ">(alpha, A_coord.x, beta, B_coord.x) * ")
                    file1.write(" gbasis::E<" + str(u) + ", " + str(la[1]) + ", " + str(lb[1]) + ">(alpha, A_coord.y, beta, B_coord.y) * ")
                    file1.write(" gbasis::E<" + str(v) + ", " + str(la[2]) + ", " + str(lb[2]) + ">(alpha, A_coord.z, beta, B_coord.z) * ")
                    file1.write(" gbasis::R<0, " + str(t) + ", " + str(u) + ", " + str(v) + ">(alpha, P, beta, pt);")
                    file1.write("\n")
                    count += 1

        # Return output variable and close it.
        file1.write("    return output * (2.0 * CUDART_PI_D) / (alpha + beta);")
        file1.write("\n}\n")

# At the end of the file write out the header functions for the HEADER file.
for x in header_files:
    file1.write(x)
    file1.write(";\n")

file1.close()


