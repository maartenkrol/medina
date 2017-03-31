
####
#### Testing driver for the f2c script.
####
##########################################


echo "=============================================================="
echo "=================> STEP 1: Copying files. <==================="

(
set -x
cp raw/* ./messy/smcl/
cp ../f2c_alpha.py  ./messy/util/
cp ../kpp_integrate_cuda_prototype.cu  ./messy/util/
)

echo "=================> STEP 2: Running script. <=================="

(
set -x
cd messy/util
python ./f2c_alpha.py -r 1 -g 1 > /dev/null
)

status=$?
if [ $status == 1 ]; then
       echo "Python parser - Unsuccessful"
       exit -1
fi

echo "==========> STEP 3: Compiling the output files. <============="

(
set -x
cd messy/smcl
nvcc -O0 -c messy_mecca_kpp_acc.cu  2>&1  | grep error
)

status=$?
if [ $status == 0 ]; then
       echo "NVCC - Unsuccessful"
       exit -1
fi

echo "============> STEP 4: Running the application. <=============="


(
set -x
cat ./raw/main.c >> ./messy/smcl/messy_mecca_kpp_acc.cu
cd messy/smcl
nvcc -O1  messy_mecca_kpp_acc.cu  2>&1  | grep error
./a.out | grep -v "Results"
exit;
cuda-memcheck ./a.out | grep -v "Results"
./a.out | grep "Results" | sed -e "s/Results://g" > res_gpu.txt
)

status=$?
if [ $status == 1 ]; then
       echo "NVCC - Unsuccessful"
       exit -1
fi



echo "======> STEP 5: Compiling original version in FORTRAN. <======"


(
set -x
cp raw/*f90 ./messy/fortran
cp raw/main_fortran.c ./messy/fortran
cd messy/fortran
gfortran -c messy_cmn_photol_mem.f90  2>&1  | grep error
gfortran -c messy_main_constants_mem.f90  2>&1  | grep error
gfortran -c messy_mecca_kpp.f90  2>&1  | grep error
gcc      -c main_fortran.c  2>&1  | grep error
gfortran -g *o  -lm
./a.out | grep -v "Results"
./a.out | grep "Results" | sed -e "s/Results://g" > res_fortran.txt
)


echo "==========> STEP 6: Comparing the output results. <==========="

(
set -x
python compare.py ./messy/fortran/res_fortran.txt messy/smcl/res_gpu.txt | grep "Element\|<<<<<<===== WARNING"
)

echo "===========> STEP 7: Cleaning up the directories. <==========="


(
set -x
cd messy/smcl/
rm ./*
cd ../fortran/
rm ./*
cd ../util/
rm ./*
)



echo "====> Testing Finished"


