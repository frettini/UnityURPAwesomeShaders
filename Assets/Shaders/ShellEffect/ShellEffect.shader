// This shader fills the mesh shape with a color predefined in the code.
Shader"Custom/ShellEffect/Texture"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _MinHeight("Minimum Height", Range(0,4)) = 0
        _Height("Height", Range(0.01,4)) = 1
        _GridScale("Grid Scale", Range(1,1000)) = 50
        _HeightTex ("Height Texture", 2D) = "white" {}
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            // To make the triangle two faced
            Cull Off
            
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // This line defines the name of the vertex shader. 
            #pragma vertex vert
            
            #pragma geometry geom
            // This line defines the name of the fragment shader. 
            #pragma fragment frag

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
            
            //#define CONE
            #define SQUARE
            
            #define NUM_LAYERS 32
            #define NUM_VERTICES_GEOM( num ) ( num * NUM_LAYERS ) 
            
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _MinHeight;
                half _Height;
                half _GridScale;
                sampler2D _HeightTex;
            CBUFFER_END
    
            // from : https://www.shadertoy.com/view/WttXWX
            float hash(uint x)
            {
                x ^= x >> 16;
                x *= 0x7feb352dU;
                x ^= x >> 15;
                x *= 0x846ca68bU;
                x ^= x >> 16;
                return x / float( 0xffffffffU );
            }

            // returns a value between 0 and 1 representing the height of the layer normalized to the max height
            half normalizedHeight(half layerHeight)
            {
                return layerHeight / (_Height);
            }
            
            half getHeightBetweenLayers()
            {
                return _Height / NUM_LAYERS;
            }
            
            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
            };

            struct Vert2Geom
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionOS  : SV_POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
            };
            
            struct Geom2Frac
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
                float3 normalWS     : NORMAL; 
                float2 uv           : TEXCOORD0;
                uint layerNum       : TEXCOORD1; 
                
                // to know whether we have a reversed triangle or not
                //fixed facing : VFACE;
            };            

            
            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Vert2Geom vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Vert2Geom OUT;
                // Will be transforming the position and normals in the geometry shader
                OUT.positionOS = IN.positionOS;
                OUT.normalOS = IN.normalOS;
                OUT.uv = IN.uv;
                // Returning the output.
                return OUT;
            }

            [maxvertexcount(NUM_VERTICES_GEOM(3))]
            void geom(triangle Vert2Geom IN[3], inout TriangleStream<Geom2Frac> triStream)
            {
            
                //for(int layer = 0; layer < NUM_LAYERS; layer++)
                for(int layer = NUM_LAYERS - 1; layer >= 0; --layer)
                {
                    for(int i = 0; i < 3; i++)
                    {
                        Geom2Frac vert;
                        float3 pos = IN[i].positionOS.xyz + IN[i].normalOS * layer *  getHeightBetweenLayers();
                        vert.positionHCS = TransformObjectToHClip(pos);
                        vert.normalWS = TransformObjectToWorldNormal(IN[i].normalOS);
                        vert.uv = IN[i].uv;
                        vert.layerNum = uint(layer);
                        triStream.Append(vert);
                    }
                    triStream.RestartStrip();
                }
            }
            
            // The fragment shader definition.            
            half4 frag(Geom2Frac IN) : SV_Target
            {
                // Defining the color variable and returning it.
                half4 customColor = half4(0.,0.,0.,0.);
                uint2 grid = uint2(_GridScale*IN.uv);
                
                #if 1 
                half cellHeight = tex2D(_HeightTex, IN.uv).x * _Height;
                #else
                half cellHeight = max(hash(grid.x + (grid.y<<16)) * _Height, _MinHeight);
                #endif
                half layerHeight = IN.layerNum * getHeightBetweenLayers();
                half normHeight = normalizedHeight(layerHeight);
                
                if(IN.layerNum == 0)
                {
                    return half4( _BaseColor.xyz * (normHeight+0.1),1.);
                }
                
                //return half4(frac(scale*IN.uv).x, frac(scale*IN.uv).y, 0., 1.);
                if(cellHeight > layerHeight)
                {
                    half2 gridUV = frac(_GridScale*IN.uv);
                    gridUV = (gridUV-0.5)*2.;
                    half cellradius = 1. - layerHeight / cellHeight;
                    
                    # if defined(CONE)
                    half alpha = dot(gridUV, gridUV) < cellradius*cellradius;
                    #elif defined(SQUARE)
                    half alpha = 1.;
                    #endif
                    
                    customColor = half4( _BaseColor.xyz * (normHeight+0.4), alpha);
                }
                
                clip(customColor.a - 0.1);
                return customColor;
            }
            ENDHLSL
        }
    }
}