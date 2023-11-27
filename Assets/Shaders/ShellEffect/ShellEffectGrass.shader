// This shader fills the mesh shape with a color predefined in the code.
Shader"Custom/ShellEffect/Grass"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        _MinHeight("Minimum Height", Range(0,4)) = 0
        _Height("Height", Range(0.01,4)) = 1
        _GridScale("Grid Scale", Range(1,10000)) = 50
        _WindTex ("Wind Texture", 2D) = "white" {}
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            #include "Assets/Shaders/Common.hlsl"
            #include "Assets/Shaders/ShellEffect/ShellCommon.hlsl"
            
            //#define CONE
            #define SQUARE
            
            #define NUM_LAYERS 32
            
            CBUFFER_START(UnityPerMaterial)
                half _MinHeight;
                half _Height;
                half _GridScale;
                sampler2D _WindTex;
            CBUFFER_END
    
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
                float2 uv           : TEXCOORD0;
                uint layerNum       : TEXCOORD1; 
                float3 positionWS   : TEXCOORD2;
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
                float height = getHeightBetweenLayers();
                
                for(int layer = NUM_LAYERS - 1; layer >= 0; --layer)
                {
                    for(int i = 0; i < 3; i++)
                    {
                        Geom2Frac vert;
                        float3 normal = normalize(IN[i].normalOS);
                        float3 pos = IN[i].positionOS.xyz + normal * layer * height;
                        vert.positionHCS = TransformObjectToHClip(pos);
                        vert.positionWS = TransformObjectToWorld(pos);
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
                
                // gather layer info
                half layerHeight = IN.layerNum * getHeightBetweenLayers();
                half normHeight = normalizedHeight(layerHeight);
                
                // get grass color directly from windtex to save on number of textures 
                float2 windUV = (IN.positionWS.xz/256.);
                float3 windCol = tex2D(_WindTex, windUV).rgb;
                
                float2 grassUV = _GridScale*IN.uv;
                uint2 grid = uint2(grassUV + (cos(tex2D(_WindTex, windUV + _Time.y * 0.006).xy*10.)) * normHeight *4.0 );
                
                half cellHeight = max(hash21(grid.x + (grid.y<<16)) * _Height, _MinHeight);
                
                cellHeight = cellHeight * (windCol.g*2.0+ 0.1);
                
                if(IN.layerNum == 0)
                {
                    return half4( windCol.xy * (normHeight+0.4),0.,1.);
                }
                
                if(cellHeight > layerHeight)
                {
                    half2 gridUV = frac(grassUV);
                    gridUV = (gridUV-0.5)*2. ;
                    half cellradius = 1. - layerHeight / cellHeight;
                    
                    # if defined(CONE)
                    half alpha = dot(gridUV, gridUV) < cellradius*cellradius;
                    #elif defined(SQUARE)
                    half alpha = 1.;
                    #endif
                    
                    customColor = half4( clamp( windCol.xy * (normHeight+0.4),0.,0.6),0., alpha);
                }
                
                clip(customColor.a - 0.1);
                return customColor;
            }
            ENDHLSL
        }
    }
}