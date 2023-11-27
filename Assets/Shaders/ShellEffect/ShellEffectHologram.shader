// This shader fills the mesh shape with a color predefined in the code.
Shader"Custom/ShellEffect/OIT"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _MinHeight("Minimum Height", Range(0,10)) = 0
        _Height("Height", Range(0.01,10)) = 1
        _GridScale("Grid Scale", Range(1,1000)) = 50
        _HeightTex ("Height Texture", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Geometry" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            ZTest LEqual
			ZWrite Off
			ColorMask 0
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 5.0

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
            
            #include "Assets/Shaders/Common.hlsl"
            #include "Assets/Shaders/ShellEffect/ShellCommon.hlsl"
            #include "Assets/Shaders/OIT/OITCommon.hlsl"
            #include "Assets/Shaders/OIT/OITLinkedListCommon.hlsl"
            
            #define NUM_LAYERS 14
            
            RWStructuredBuffer<FragmentAndLinkBuffer_STRUCT> fragmentLLBuffer : register(u1);
            RWByteAddressBuffer startOffsetBuffer : register(u2);
            
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _MinHeight;
                half _Height;
                half _GridScale;
                sampler2D _HeightTex;
                sampler2D _NoiseTex;
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
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
            };

            struct Vert2Geom
            {
                float4 positionOS  : SV_POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
            };
            
            struct Geom2Frac
            {
                float4 positionHCS  : SV_POSITION;
                float3 normalWS     : NORMAL; 
                float2 uv           : TEXCOORD0;
                uint layerNum       : TEXCOORD1; 
            };            

            
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
            
            [earlydepthstencil]
            half4 frag(Geom2Frac IN, uint uCoverage : SV_Coverage) : SV_Target
            {
                // Defining the color variable and returning it.
                half4 customColor = half4(0.,0.,0.,0.);
                
                // distortion effect calculation along the x axis
                float distort = IN.uv.x * 3.14 - _Time.x * 4. ;
                float distortAmp = hash21( uint( distort ) ) - 0.5;
                float2 distortUV = float2( IN.uv.x, IN.uv.y + cubicPulse( 0.5, 0.03, frac( distort ) ) * distortAmp * 0.05 );
                
                // sample Height texture with distorted UV
                half cellHeight = tex2D(_HeightTex, distortUV).x * _Height;
              
                half layerHeight = IN.layerNum * getHeightBetweenLayers();
                half normHeight = normalizedHeight(layerHeight);
                
                if(cellHeight > layerHeight)
                {
                    float noiseOffset = hash21(IN.layerNum ^ uint(_Time.w*2.) ) ;
                    float noise = 0.6 + tex2D( _NoiseTex , IN.uv + noiseOffset).x * 0.4;
                    
                    float stripeAlpha = smoothstep( 0., 0.04, abs( frac(_Time.x + hash21(IN.layerNum % 2) ) - (IN.uv.x*0.8 +0.1) )) ; 
                    customColor = half4( _BaseColor.xyz * (normHeight+0.4), _BaseColor.w * noise * stripeAlpha);
                }
                
                 // vertex is already in window space, shift by 0.5 to make sure we are in bounds
                float2 screenPos = (IN.positionHCS.xy-0.5);
                
                // get the address of the buffer from screen pos
                uint offsetAddress = SIZEOF_UINT * (screenPos.y * _ScreenParams.x + screenPos.x);
                uint oldOffsetAddress;
                
                // increment to the last address of the linked list
                uint counter = fragmentLLBuffer.IncrementCounter();
                // exchange the value with the current counter value
                startOffsetBuffer.InterlockedExchange(offsetAddress, counter, oldOffsetAddress);
                
                // now need to add the value to the linked list
                FragmentAndLinkBuffer_STRUCT frag;
                frag.color = PackRGBA(customColor);
                frag.depth = PackDepthSampleIdx( Linear01Depth( IN.positionHCS.z, _ZBufferParams), uCoverage );
                frag.next = oldOffsetAddress;
                fragmentLLBuffer[counter] = frag;
                
                return customColor;
            }
            ENDHLSL
        }
    }
}