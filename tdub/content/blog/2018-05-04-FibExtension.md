---
layout: post
title: Fibbonacci Sequence Calculator.
date: 2018-05-04
---

# FibExtensionModule
Writing C++ extension modules with SWIG for Python has never been so easy...

For this module, the C++ code was compiled with Mingw64 (i686-w64-mingw32-g++)

The first step is installing Mingw64 and SWIG after doing so the Mingw /bin/ files (.exe) and the SWIG (.exe) files should be set to your environment variables so they can be called from the command line.

First step is to actually write and debug the C++ function you want to interface with Python.

Because I am using approximation and not recursion I did the calculation in C++
```c++
// fib.cpp
#include <iostream>
#include <cmath>

double Fibonacci(int n) {
	static const double phi = (1 + sqrt(5))*0.5;
	double fib = (pow(phi, n) - pow(1 - phi, n)) / sqrt(5);
	return round(fib);
}
```
Next we build our SWIG template file.
```
/* File: fib.i */
%module fib
%{
extern double Fibonacci(int n);
%}
extern double Fibonacci(int n);
```
Using Swig we prep our Module.
```
cmd$> swig -c++ -python fib.i
```
This generates a fib.py file as well as a fib_wrapper.cxx (C++ file).
Next we need to compile our C++ code (Mingw64) and then generate the phython DLL file so we can load our module.
We have to be sure to include the python Include header files!
```
cmd$> i686-w64-mingw32-g++ -c fib.cpp -I C:\Python27\include
```
Then Compile the wrapper code.
```
cmd$> i686-w64-mingw32-g++ -c fib_wrap.cxx -I C:\Python27\include
```
This leaves us with two compiled O files.
```
fib.o & fib_wrap.o
```
Lastly, we need to create a python DLL linker to our Compiled files in order to load the Module in python.
```
cmd$> i686-w64-mingw32-g++ -shared -I C:\Python27\include -L C:\Python27\libs fib.o fib_wrap.o -o _fib.pyd -lpython27
```
Note: If you get an error with a definition you need to browse to the location to rename the string since some of the modules get renamed to "_module" during the compilation.
```
Example:
/include/c++/cmath:1136:11: error: '::hypot' has not been declared
using ::hypot;
           ^~~~~
i686-w64-mingw32-g++ -c fib.cpp
fib.cpp:4:10: fatal error: Python.h: No such file or directory
 #include <Python.h>
          ^~~~~~~~~~
compilation terminated.

i686-w64-mingw32-g++ -c fib.cpp -I C:\Python27\include
In file included from C:\Python27\include/Python.h:8:0,
                 from fib.cpp:4:
C:\Python27\include/pyconfig.h:285:15: error: 'std::_hypot' has not been declared
 #define hypot _hypot
```
This can be fixed by modifying the included file so that when the module is loaded it calls the correct name.
In the example above, browsing to cmath and changing the below parameters fixes the compilation error.
```
#define hypot to #define _hypot
```
After we have successfully compiled the code and created the python "pyd" DLL we are all set for loading and running our C++
extension module.

Example:
```python
# file: runme.py

import fib

arr = []
for i in range(0,100):
	arr.append('{:0.3e}'.format(fib.Fibonacci(i)))
print arr
```
Results from Calculation:
```
C:\Examples\python\fib>python2 runme.py
['0.000e+00', '1.000e+00', '1.000e+00', '2.000e+00', '3.000e+00', '5.000e+00', '8.000e+00', '1.300e+01', '2.100e+01', '3.400e+01', '5.500e+01', '8.900e+01', '1.440e+02', '2.330e+02', '3.770e+02', '6.100e+02', '9.870e+02', '1.597e+03', '2.584e+03', '4.181e+03', '6.765e+03', '1.095e+04', '1.771e+04', '2.866e+04', '4.637e+04', '7.502e+04', '1.214e+05', '1.964e+05', '3.178e+05', '5.142e+05', '8.320e+05', '1.346e+06', '2.178e+06', '3.525e+06', '5.703e+06', '9.227e+06', '1.493e+07', '2.416e+07', '3.909e+07', '6.325e+07', '1.023e+08', '1.656e+08', '2.679e+08', '4.335e+08', '7.014e+08', '1.135e+09', '1.836e+09', '2.971e+09', '4.808e+09', '7.779e+09', '1.259e+10', '2.037e+10', '3.295e+10', '5.332e+10', '8.627e+10', '1.396e+11', '2.259e+11', '3.654e+11', '5.913e+11', '9.567e+11', '1.548e+12', '2.505e+12', '4.053e+12', '6.557e+12', '1.061e+13', '1.717e+13', '2.778e+13', '4.495e+13', '7.272e+13', '1.177e+14', '1.904e+14', '3.081e+14', '4.985e+14', '8.065e+14', '1.305e+15', '2.111e+15', '3.416e+15', '5.528e+15', '8.944e+15', '1.447e+16', '2.342e+16', '3.789e+16', '6.131e+16', '9.919e+16', '1.605e+17', '2.597e+17', '4.202e+17', '6.799e+17', '1.100e+18', '1.780e+18', '2.880e+18', '4.660e+18', '7.540e+18', '1.220e+19', '1.974e+19', '3.194e+19', '5.168e+19', '8.362e+19', '1.353e+20', '2.189e+20']
```
