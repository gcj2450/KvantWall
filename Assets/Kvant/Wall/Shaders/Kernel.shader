﻿//
// GPGPU kernels for Wall
//
// Texture format in position kernels:
// .xyz = object position
// .w   = color parameter
//
Shader "Hidden/Kvant/Wall/Kernel"
{
    Properties
    {
        _MainTex("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"
    #include "ClassicNoise3D.cginc"

    #define PI2 6.28318530718

    #pragma multi_compile POSITION_Z POSITION_XYZ POSITION_RANDOM
    #pragma multi_compile ROTATION_AXIS ROTATION_RANDOM
    #pragma multi_compile SCALE_UNIFORM SCALE_XYZ

    sampler2D _MainTex;
    float2 _Extent;
    float3 _BaseScale;
    float2 _RandomScale;    // (min, max)
    float4 _PositionNoise;  // (offset x, y, z, freq)
    float4 _RotationNoise;
    float4 _ScaleNoise;
    float3 _NoiseInfluence; // (position, rotation, scale)
    float3 _RotationAxis;
    float2 _Config;         // (random seed, time)
    float4 _RandomParams;

    // PRNG function.
    float nrand(float2 uv, float salt)
    {
        uv += float2(salt, _Config.x);
        return frac(sin(dot(floor((uv + _RandomParams.xy) * _RandomParams.zw) / _RandomParams.zw, float2(12.9898, 78.233))) * 43758.5453);
    }

    // Quaternion multiplication.
    // http://mathworld.wolfram.com/Quaternion.html
    float4 qmul(float4 q1, float4 q2)
    {
        return float4(
            q2.xyz * q1.w + q1.xyz * q2.w + cross(q1.xyz, q2.xyz),
            q1.w * q2.w - dot(q1.xyz, q2.xyz)
        );
    }

    // Get a random rotation axis in a deterministic fashion.
    float3 get_rotation_axis(float2 uv)
    {
        // Uniformaly distributed points.
        // http://mathworld.wolfram.com/SpherePointPicking.html
        float u = nrand(uv, 0) * 2 - 1;
        float theta = nrand(uv, 1) * PI2;
        float u2 = sqrt(1 - u * u);
        return float3(u2 * cos(theta), u2 * sin(theta), u);
    }

    float3 position_init(float2 uv)
    {
        return float3((uv - 0.5) * _Extent, 0);
    }

    float3 position_delta(float2 uv)
    {
        float3 p = (_PositionNoise.xyz + float3(uv, 0)) * _PositionNoise.w;
    #if POSITION_Z
        float3 v = float3(0, 0, cnoise(p));
    #elif POSITION_XYZ
        float nx = cnoise(p + float3(0, 0, 0));
        float ny = cnoise(p + float3(138.2, 0, 0));
        float nz = cnoise(p + float3(0, 138.2, 0));
        float3 v = float3(nx, ny, nz);
    #else // POSITION_RANDOM
        float3 v = get_rotation_axis(uv) * cnoise(p);
    #endif
        return v * _NoiseInfluence.x;
    }

    // Pass 0: Position
    float4 frag_position(v2f_img i) : SV_Target 
    {
        return float4(position_init(i.uv) + position_delta(i.uv), nrand(i.uv, 2));
    }

    // Pass 1: Rotation
    float4 frag_rotation(v2f_img i) : SV_Target 
    {
        float3 p = (_RotationNoise.xyz + float3(i.uv, 0)) * _RotationNoise.w;
        float r = cnoise(p) * _NoiseInfluence.y;
    #if ROTATION_AXIS
        float3 v = _RotationAxis;
    #else // ROTATION_RANDOM
        float3 v = get_rotation_axis(i.uv);
    #endif
        return float4(v * sin(r), cos(r));
    }

    // Pass 2: Scale
    float4 frag_scale(v2f_img i) : SV_Target 
    {
        float init = lerp(_RandomScale.x, _RandomScale.y, nrand(i.uv, 3));
        float3 p = (_ScaleNoise.xyz + float3(i.uv, 0)) * _ScaleNoise.w;
    #if SCALE_UNIFORM
        float3 s = (float3)cnoise(p + float3(417.1, 471.2, 0));
    #else // SCALE_XYZ
        float sx = cnoise(p + float3(417.1, 471.2, 0));
        float sy = cnoise(p + float3(917.1, 471.2, 0));
        float sz = cnoise(p + float3(417.1, 971.2, 0));
        float3 s = float3(sx, sy, sz);
    #endif
        s = 1.0 - _NoiseInfluence.z * (s + 0.7) / 1.4;
        return float4(init * s * _BaseScale, 0);
    }

    ENDCG

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_position
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_rotation
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_scale
            ENDCG
        }
    }
}
