/* 
 * make_perlin_mex.c - Complete MEX implementation for Perlin noise generation
 * 
 * Compiled MEX version of the _perlin.c Python extension for MATLAB
 * 
 * To compile this MEX function:
 * mex make_perlin_mex.c
 * 
 * Usage in MATLAB:
 * arr = make_perlin_mex(x_coords, y_coords, t_coords, ...
 *                      'octaves', levels, 'persistence', xyscale, ...
 *                      'repeatx', ratio, 'repeaty', XYSCALEBASE, ...
 *                      'repeatz', tunits, 'base', seed);
 *
 * Copyright (c) 2008, Casey Duncan (casey dot duncan at gmail dot com)
 * Copyright (c) 2022, Max Shinn
 * MATLAB MEX port 2025
 */

#include "mex.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _MSC_VER
#define inline __inline
#endif

#define lerp(t, a, b) ((a) + (t) * ((b) - (a)))

// Gradient table from original _perlin.c
const float GRAD3[][3] = {
	{1,1,0},{-1,1,0},{1,-1,0},{-1,-1,0}, 
	{1,0,1},{-1,0,1},{1,0,-1},{-1,0,-1}, 
	{0,1,1},{0,-1,1},{0,1,-1},{0,-1,-1},
	{1,0,-1},{-1,0,-1},{0,-1,1},{0,1,1}};

#define PERM_SIZE 4096
#define PERM_MASK (PERM_SIZE-1)
static unsigned short PERM[PERM_SIZE * 2];

static void init_perm(unsigned int seed)
{
    for (unsigned int i = 0; i < PERM_SIZE; ++i) PERM[i] = i;
    // Fisher-Yates shuffle
    srand(seed);
    for (unsigned int i = PERM_SIZE-1; i; --i) {
        unsigned int j = rand() & PERM_MASK;
        unsigned short t = PERM[i];
        PERM[i] = PERM[j];
        PERM[j] = t;
    }
    // duplicate so PERM[i + PERM_SIZE] is always valid
    for (unsigned int i = 0; i < PERM_SIZE; ++i)
        PERM[PERM_SIZE + i] = PERM[i];
}

static inline float grad3(const int hash, const float x, const float y, const float z)
{
	const int h = hash & 15;
	return x * GRAD3[h][0] + y * GRAD3[h][1] + z * GRAD3[h][2];
}

float noise3(float x, float y, float z, const int repeatx, const int repeaty, const int repeatz, const int base)
{
	float fx, fy, fz;
	int A, AA, AB, B, BA, BB;
	int i = (int)x;
    int j = (int)y;
    int k = (int)z;
	int ii = (i + 1) %  repeatx;
	int jj = (j + 1) % repeaty;
	int kk = (k + 1) % repeatz;
	i = ((i + base) & PERM_MASK);
	j = ((j + base) & PERM_MASK);
	k = ((k + base) & PERM_MASK);
	ii = ((ii + base) & PERM_MASK);
	jj = ((jj + base) & PERM_MASK);
	kk = ((kk + base) & PERM_MASK);

	x -= (float)(int)x; y -= (float)(int)y; z -= (float)(int)z;
	fx = x*x*x * (x * (x * 6 - 15) + 10);
	fy = y*y*y * (y * (y * 6 - 15) + 10);
	fz = z*z*z * (z * (z * 6 - 15) + 10);

	A = PERM[i];
	AA = PERM[(A + j) & PERM_MASK];
	AB = PERM[(A + jj) & PERM_MASK];
	B = PERM[ii];
	BA = PERM[(B + j) & PERM_MASK];
	BB = PERM[(B + jj) & PERM_MASK];

	return lerp(fz, lerp(fy, lerp(fx, grad3(PERM[AA + k], x, y, z),
									  grad3(PERM[BA + k], x - 1, y, z)),
							 lerp(fx, grad3(PERM[AB + k], x, y - 1, z),
									  grad3(PERM[BB + k], x - 1, y - 1, z))),
					lerp(fy, lerp(fx, grad3(PERM[AA + kk], x, y, z - 1),
									  grad3(PERM[BA + kk], x - 1, y, z - 1)),
							 lerp(fx, grad3(PERM[AB + kk], x, y - 1, z - 1),
									  grad3(PERM[BB + kk], x - 1, y - 1, z - 1))));
}

// Helper function to parse optional parameters
int parseOptionalParams(int nrhs, const mxArray *prhs[], int *octaves, float *persistence, 
                       float *lacunarity, int *repeatx, int *repeaty, int *repeatz, int *base)
{
    // Set defaults
    *octaves = 1;
    *persistence = 0.5f;
    *lacunarity = 2.0f;
    *repeatx = 1024;
    *repeaty = 1024;
    *repeatz = 1024;
    *base = 0;
    
    // Parse optional name-value pairs
    for (int i = 3; i < nrhs; i += 2) {
        if (i + 1 >= nrhs) {
            mexErrMsgTxt("Optional parameters must be name-value pairs");
            return 0;
        }
        
        if (!mxIsChar(prhs[i])) {
            mexErrMsgTxt("Parameter names must be strings");
            return 0;
        }
        
        char *paramName = mxArrayToString(prhs[i]);
        if (paramName == NULL) {
            mexErrMsgTxt("Failed to convert parameter name");
            return 0;
        }
        
        if (strcmp(paramName, "octaves") == 0) {
            *octaves = (int)mxGetScalar(prhs[i+1]);
        } else if (strcmp(paramName, "persistence") == 0) {
            *persistence = (float)mxGetScalar(prhs[i+1]);
        } else if (strcmp(paramName, "lacunarity") == 0) {
            *lacunarity = (float)mxGetScalar(prhs[i+1]);
        } else if (strcmp(paramName, "repeatx") == 0) {
            *repeatx = (int)mxGetScalar(prhs[i+1]);
        } else if (strcmp(paramName, "repeaty") == 0) {
            *repeaty = (int)mxGetScalar(prhs[i+1]);
        } else if (strcmp(paramName, "repeatz") == 0) {
            *repeatz = (int)mxGetScalar(prhs[i+1]);
        } else if (strcmp(paramName, "base") == 0) {
            *base = (int)mxGetScalar(prhs[i+1]);
        } else {
            char errMsg[256];
            sprintf(errMsg, "Unknown parameter: %s", paramName);
            mxFree(paramName);
            mexErrMsgTxt(errMsg);
            return 0;
        }
        
        mxFree(paramName);
    }
    
    return 1;
}

/* MEX function entry point */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // Check input arguments
    if (nrhs < 3) {
        mexErrMsgTxt("Usage: make_perlin_mex(x, y, z, 'param1', value1, ...)");
    }
    
    if (nlhs > 1) {
        mexErrMsgTxt("Too many output arguments");
    }
    
    // Get input arrays
    if (!mxIsSingle(prhs[0]) || !mxIsSingle(prhs[1]) || !mxIsSingle(prhs[2])) {
        mexErrMsgTxt("Input arrays must be single precision (float32)");
    }
    
    float *x = (float*)mxGetData(prhs[0]);
    float *y = (float*)mxGetData(prhs[1]);
    float *z = (float*)mxGetData(prhs[2]);
    
    int len_x = (int)mxGetNumberOfElements(prhs[0]);
    int len_y = (int)mxGetNumberOfElements(prhs[1]);
    int len_z = (int)mxGetNumberOfElements(prhs[2]);
    
    // Parse optional parameters
    int octaves, repeatx, repeaty, repeatz, base;
    float persistence, lacunarity;
    
    if (!parseOptionalParams(nrhs, prhs, &octaves, &persistence, &lacunarity, 
                            &repeatx, &repeaty, &repeatz, &base)) {
        return;
    }
    
    // Validate parameters
    if (base < 0 || base >= PERM_SIZE) {
        mexErrMsgTxt("Base must be between 0 and 4095");
    }
    
    if (octaves <= 0) {
        mexErrMsgTxt("Expected octaves value > 0");
    }
    
    // Check coordinate bounds
    if (len_x > 0 && x[len_x-1] >= repeatx) {
        mexErrMsgTxt("Cannot pass x values greater than repeatx");
    }
    if (len_y > 0 && y[len_y-1] >= repeaty) {
        mexErrMsgTxt("Cannot pass y values greater than repeaty");
    }
    if (len_z > 0 && z[len_z-1] >= repeatz) {
        mexErrMsgTxt("Cannot pass z values greater than repeatz");
    }
    
    // Initialize permutation table
    init_perm((unsigned int)base);
    
    // Create output array - swap dimensions to match MATLAB's (height, width) convention
    mwSize dims[3] = {len_y, len_x, len_z};
    plhs[0] = mxCreateNumericArray(3, dims, mxSINGLE_CLASS, mxREAL);
    float *ret = (float*)mxGetData(plhs[0]);
    
    // Generate noise
    if (octaves == 1) {
        // Single octave, return simple noise
        for (int i = 0; i < len_x; i++) {
            for (int j = 0; j < len_y; j++) {
                for (int k = 0; k < len_z; k++) {
                    // Use MATLAB column-major indexing: ret[j + i*len_y + k*len_y*len_x]
                    ret[j + i*len_y + k*len_y*len_x] = noise3(x[i], y[j], z[k],
                                                            repeatx, repeaty, repeatz, base);
                }
            }
        }
    } else {
        // Multi-octave fractal noise
        for (int i = 0; i < len_x; i++) {
            for (int j = 0; j < len_y; j++) {
                for (int k = 0; k < len_z; k++) {
                    float freq = 1.0f;
                    float amp = 1.0f;
                    float max_val = 0.0f;
                    float total = 0.0f;
                    
                    for (int l = 0; l < octaves; l++) {
                        total += noise3(x[i] * freq, y[j] * freq, z[k] * freq,
                                      (int)(repeatx * freq), (int)(repeaty * freq), 
                                      (int)(repeatz * freq), base) * amp;
                        max_val += amp;
                        freq *= lacunarity;
                        amp *= persistence;
                        if (amp < 0.004f) break; // No significant influence beyond ~1/256
                    }
                    
                    // Use MATLAB column-major indexing: ret[j + i*len_y + k*len_y*len_x]
                    ret[j + i*len_y + k*len_y*len_x] = total / max_val;
                }
            }
        }
    }
}
