#ifndef COMMON_INCLUDED
#define COMMON_INCLUDED

// HASH FUNCTIONS ////////////////////////////////////////////
// from : https://www.shadertoy.com/view/WttXWX
float hash21(uint x)
{
    x ^= x >> 16;
    x *= 0x7feb352dU;
    x ^= x >> 15;
    x *= 0x846ca68bU;
    x ^= x >> 16;
    return x / float( 0xffffffffU );
}


// IMPULSE FUNCTIONS ////////////////////////////////////////// 
float cubicPulse( float c, float width, float x )
{
    x = abs(x - c);
    if( x>width ) return 0.0;
    x /= width;
    return 1.0 - x*x*(3.0-2.0*x);
}

#endif // COMMON_INCLUDED
